from pathlib import Path
import json
from PIL import Image,ImageDraw
from package_ember_hit_variants import gif
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/other_types_fx_audit'
ORDER=['normal','electric','grass','ice','fighting','poison','ground','flying','psychic','bug','rock','ghost','dragon','dark','steel','fairy']

def crop_at(im,center):
 x,y=center
 return im.crop((round(x-44),round(y-36),round(x+44),round(y+36)))

def main():
 rows=json.loads((OUT/'native/checks.json').read_text());assert len(rows)==16 and {r['type'] for r in rows}==set(ORDER)
 meta={r['type']:r for r in rows};captures={}
 for k in ORDER:
  r=meta[k];assert r['source_attack'] and r['event_frame']>=0
  captures[k]=[Image.open(OUT/f'native/{k}/{i:03d}.png').convert('RGB') for i in range(54)]
  clip=[]
  for i,im in enumerate(captures[k]):
   b=Image.new('RGB',(384,410),(28,33,30));d=ImageDraw.Draw(b)
   d.text((6,6),k.upper()+' / '+r['move'].upper()+' / '+r['category'].upper(),fill=(238,233,218))
   b.paste(im,(0,25));d.text((6,250),'CURRENT / 2x detail below',fill=(238,233,218))
   b.paste(crop_at(im,r['centers'][i]).resize((176,144),Image.Resampling.NEAREST),(104,266))
   clip.append(b)
  gif(OUT/f'{k}-current.gif',clip,[30 if n%3<2 else 40 for n in range(54)])
 frames=[];native=[]
 for offset in range(-3,25):
  b=Image.new('RGB',(704,664),(28,33,30));d=ImageDraw.Draw(b)
  small=Image.new('RGB',(352,400),(28,33,30));sd=ImageDraw.Draw(small)
  for n,k in enumerate(ORDER):
   row=n//4;col=n%4;r=meta[k];i=int(r['event_frame'])+offset
   assert 0<=i<54
   crop=crop_at(captures[k][i],r['centers'][i])
   d.text((col*176+4,row*166+3),k.upper()+' / '+r['category'].upper(),fill=(238,233,218))
   d.text((col*176+4,row*166+13),r['move'].upper(),fill=(208,214,200))
   b.paste(crop.resize((176,144),Image.Resampling.NEAREST),(col*176,row*166+22))
   sd.text((col*88+2,row*100+3),k.upper(),fill=(238,233,218));small.paste(crop,(col*88,row*100+22))
  frames.append(b);native.append(small)
 timing=[30 if n%3<2 else 40 for n in range(len(frames))]
 gif(OUT/'sixteen-types-current.gif',frames,timing);gif(OUT/'sixteen-types-native.gif',native,timing)
 for delta,name in [(1,'early'),(4,'middle'),(10,'late')]:frames[delta+3].save(OUT/f'contact-{name}.png')
 # Two same-simulation-frame diagnostic views: no new effect artwork.
 probe_frames=[]
 for offset in range(-3,25):
  board=Image.new('RGB',(528,356),(28,33,30));draw=ImageDraw.Draw(board)
  for row,k in enumerate(['electric','ice']):
   r=meta[k];f=int(r['event_frame'])+offset;cx,cy=r['centers'][f]
   probe_path=OUT/f'native/{k}/probe/{f:03d}.png'
   if not probe_path.exists():continue
   for col,im in enumerate([captures[k][f],Image.open(probe_path).convert('RGB')]):
    crop=im.crop((round(cx-44),round(cy-25),round(cx+44),round(cy+25))).resize((264,150),Image.Resampling.NEAREST)
    draw.text((col*264+4,row*178+5),k.upper()+(' / CURRENT' if col==0 else ' / DEPTH DIAGNOSTIC'),fill=(238,233,218))
    board.paste(crop,(col*264,row*178+28))
  probe_frames.append(board)
 gif(OUT/'depth-diagnostic.gif',probe_frames,timing)
 print('Packed 16 current-technique clips and synchronized 1x/2x overview; no authored FX or gameplay changes')

if __name__=='__main__':main()
