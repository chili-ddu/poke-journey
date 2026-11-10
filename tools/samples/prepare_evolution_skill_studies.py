"""Prepare raw supplied sheets and temporary pixelfx CLI adapters."""
from pathlib import Path
from PIL import Image
import xml.etree.ElementTree as ET
import json,hashlib,sys

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charmeleon_charizard_skill_review'
NAMES={5:'charmeleon',6:'charizard'}


def prepare():
    OUT.mkdir(exist_ok=True)
    data={}
    for dex,name in NAMES.items():
        asset=ROOT/f'assets/sprites/{dex:04d}'
        anims={a.findtext('Name'):a for a in ET.parse(asset/'AnimData.xml').findall('./Anims/Anim')}
        width=max(int(anims[a].findtext('FrameWidth')) for a in ['Idle','Walk'])
        height=max(int(anims[a].findtext('FrameHeight')) for a in ['Idle','Walk'])
        dest=OUT/name;(dest/'source').mkdir(parents=True,exist_ok=True)
        actions={};hashes={}
        for action in ['Idle','Walk']:
            meta=anims[action];w=int(meta.findtext('FrameWidth'));h=int(meta.findtext('FrameHeight'))
            ticks=[int(d.text) for d in meta.findall('./Durations/Duration')]
            file=asset/f'{action}-Anim.png';hashes[str(file.relative_to(ROOT))]=hashlib.sha256(file.read_bytes()).hexdigest()
            sheet=Image.open(file).convert('RGBA');frames=[]
            for k in range(len(ticks)):
                cell=sheet.crop((k*w,h*2,(k+1)*w,h*3))
                canvas=Image.new('RGBA',(width,height));canvas.paste(cell,((width-w)//2,(height-h)//2))
                canvas.save(dest/f'source/{action.lower()}-{k}.png')
                colors=list(dict.fromkeys(c for c in canvas.get_flattened_data() if c[3]))
                chars='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
                ids={c:chars[i] for i,c in enumerate(colors)}
                flame=[(x,y) for y in range(height) for x in range(width) if canvas.getpixel((x,y))==(255,247,0,255)]
                # The source marker yellow also occurs on the belly. Protect
                # only the leftmost connected flame cluster, not their union.
                if flame:
                    remaining=set(flame);seed=min(flame);cluster={seed};todo=[seed]
                    while todo:
                        x,y=todo.pop()
                        for dx in [-1,0,1]:
                            for dy in [-1,0,1]:
                                q=(x+dx,y+dy)
                                if q in remaining and q not in cluster:cluster.add(q);todo.append(q)
                    flame=list(cluster)
                flame_box=([max(0,min(x for x,y in flame)-3),max(0,min(y for x,y in flame)-4),
                            min(width,max(x for x,y in flame)+4),min(height,max(y for x,y in flame)+4)] if flame else [0,0,0,0])
                used=canvas.getbbox();eyes=[(x,y) for y in range(used[1],used[1]+(used[3]-used[1])//2+1)
                                          for x in range(width//2,width)
                                          if canvas.getpixel((x,y)) in [(255,255,255,255),(191,207,247,255),(0,103,183,255)]]
                eye_bottom=max((y for x,y in eyes),default=used[1]+int((used[3]-used[1])*.4))
                frames.append(dict(rows=[''.join(ids[canvas.getpixel((x,y))] if canvas.getpixel((x,y))[3] else '.' for x in range(width)) for y in range(height)],
                                   palette={ids[c]:'#%02x%02x%02x'%c[:3] for c in colors},
                                   flame_box=flame_box,eye_bottom=eye_bottom))
            actions[action.lower()]=dict(ticks=ticks,frames=frames)
        data[name]=dict(dex=dex,width=width,height=height,actions=actions,hashes=hashes)
        (dest/'source-provenance.json').write_text(json.dumps(dict(art_source='existing',route='raw project PNG extraction',
            width=width,height=height,actions={a:v['ticks'] for a,v in actions.items()},hashes=hashes,
            previous_sample_inputs=False,production_changes=False),indent=2))
    (OUT/'source-data.mjs').write_text('export default '+json.dumps(data)+';\n')
    print('Raw source keys extracted for both species; original dimensions/durations retained')


def wrappers(stage):
    folder=ROOT.parent/'pixelfx/src/fx/local-review';folder.mkdir(exist_ok=True)
    for name in NAMES.values():
        actions=['idle','walk'] if stage==3 else ['idle']
        for action in actions:
            variants=['edited','original'] if stage==3 else ['edited']
            for v in variants:
                id=f'{name}-fresh-r{stage}-{action}-{v}'
                text=(f'// Temporary supplied-art review adapter.\n'
                      f"import {{makeStudy}} from '{(ROOT/'tools/samples/evolution_skill_study.mjs').as_uri()}';\n"
                      f"const s=makeStudy('{name}',{stage},'{action}','{v}');\n"
                      'export const meta=s.meta; export const draw=s.draw;\n')
                (folder/f'{id}.js').write_text(text)
                print('local-review/'+id)


if __name__=='__main__':
    if sys.argv[1]=='prepare':prepare()
    else:wrappers(int(sys.argv[1]))
