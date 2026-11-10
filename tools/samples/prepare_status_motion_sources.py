"""Audit existing art and fetch native missing wake poses into the study only."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import hashlib,json,urllib.request,xml.etree.ElementTree as ET
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/status_motion_followup'

def main():
    OUT.mkdir(parents=True,exist_ok=True)
    revision=json.load(urllib.request.urlopen('https://api.github.com/repos/PMDCollab/SpriteCollab/commits/master'))['sha']
    rows=json.loads((OUT/'source-inventory.json').read_text())
    def fetch(row):
        if 'Wake' not in row['actions']:return []
        dex=row['dex'];base=f'sprite/{dex:04d}/';files=['AnimData.xml','credits.txt','Wake-Anim.png','Wake-Offsets.png']
        records=[]
        for name in files:
            url=f'https://raw.githubusercontent.com/PMDCollab/SpriteCollab/{revision}/{base}{name}'
            dest=OUT/f'source-extra/{dex:04d}/{name}';dest.parent.mkdir(parents=True,exist_ok=True)
            try:
                data=urllib.request.urlopen(url,timeout=20).read();dest.write_bytes(data)
                records.append({'dex':dex,'file':str(dest.relative_to(ROOT)),'url':url,'sha256':hashlib.sha256(data).hexdigest()})
            except Exception as e:records.append({'dex':dex,'file':name,'error':str(e)})
        return records
    with ThreadPoolExecutor(max_workers=6) as pool:downloads=[r for group in pool.map(fetch,rows) for r in group]
    profiles=[]
    for row in rows:
        dex=row['dex'];profiles.append({'dex':dex,'sleep':'Sleep','status_react':'Hurt','wake':'Wake' if (OUT/f'source-extra/{dex:04d}/Wake-Anim.png').exists() else 'Idle',
            'wake_fallback':'native idle, no reverse or morph' if not (OUT/f'source-extra/{dex:04d}/Wake-Anim.png').exists() else None})
    (OUT/'species-profiles.json').write_text(json.dumps(profiles,indent=2)+'\n')
    (OUT/'source-downloads.json').write_text(json.dumps({'repository':'PMDCollab/SpriteCollab','revision':revision,'files':downloads},indent=2)+'\n')
    for page in range((len(rows)+19)//20):
        batch=rows[page*20:(page+1)*20];board=Image.new('RGB',(1000,125*len(batch)),(28,33,30));d=ImageDraw.Draw(board)
        for r,row in enumerate(batch):
            folder=ROOT/Path(row['path']).parent;meta={a.findtext('Name'):a for a in ET.parse(folder/'AnimData.xml').getroot().findall('.//Anim')}
            for col,(action,direction) in enumerate([('Idle',0),('Sleep',0),('Sleep',2),('Sleep',4),('Hurt',0)]):
                a=meta[action];name=a.findtext('CopyOf') or action;a=meta[name];fw=int(a.findtext('FrameWidth'));fh=int(a.findtext('FrameHeight'))
                im=Image.open(folder/(name+'-Anim.png')).convert('RGBA');direction=min(direction,im.height//fh-1)
                im=im.crop((0,direction*fh,fw,(direction+1)*fh));im=im.resize((fw*2,fh*2),Image.Resampling.NEAREST)
                # Fixed cell center, source grid preserved, no per-frame enlargement.
                board.paste(im,(col*200+100-im.width//2,r*125+110-im.height//2),im)
                d.text((col*200+4,r*125+4),f'{row["dex"]:04d} {action} dir{direction}',fill='white')
        board.save(OUT/f'source-poses-{page+1}.png')
    print(json.dumps({'species':len(rows),'wake_downloaded':sum(p['wake']=='Wake' for p in profiles),'download_errors':[x for x in downloads if 'error' in x]}))

if __name__=='__main__':main()
