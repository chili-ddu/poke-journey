from pathlib import Path
import json
from PIL import Image,ImageDraw
from package_ember_hit_variants import gif
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/material_hit_fx'
KINDS=['electric','ice','poison','psychic'];DIRS=['right','left']

def crop_at(image,center,size=(88,72)):
 cx,cy=center;w,h=size
 return image.crop((round(cx-w/2),round(cy-h/2),round(cx+w/2),round(cy+h/2)))

def main():
 rows=json.loads((OUT/'native/checks.json').read_text());assert len(rows)==16
 metadata={};captures={}
 for kind in KINDS:
  for direction in DIRS:
   case=kind+'-'+direction;pair=[r for r in rows if r['case']==case];assert len(pair)==2
   assert pair[0]['trace']==pair[1]['trace'] and pair[0]['hit_frame']==pair[1]['hit_frame']
   assert all(r['measured_direction']==direction for r in pair)
   metadata[case]={r['variant']:r for r in pair}
   captures[case]={v:[Image.open(OUT/f'native/{case}/{v}/{i:03d}.png').convert('RGB') for i in range(60)] for v in ['current','sample']}
   frames=[]
   for i in range(60):
    b=Image.new('RGB',(512,296),(28,33,30));d=ImageDraw.Draw(b)
    for col,v in enumerate(['current','sample']):
     d.text((col*256+6,6),kind.upper()+' / '+v.upper(),fill=(238,233,218))
     crop=crop_at(captures[case][v][i],metadata[case]['current']['centers'][i],(96,80))
     b.paste(crop,(col*256+80,27));b.paste(crop.resize((192,160),Image.Resampling.NEAREST),(col*256+32,136))
    frames.append(b)
   gif(OUT/f'{case}-comparison.gif',frames,[30 if i%3<2 else 40 for i in range(60)])
 frames=[];native=[];pairs=[]
 for offset in range(-3,35):
  b=Image.new('RGB',(704,378),(28,33,30));d=ImageDraw.Draw(b)
  small=Image.new('RGB',(352,214),(28,33,30));sd=ImageDraw.Draw(small)
  pairboard=Image.new('RGB',(704,348),(28,33,30));pd=ImageDraw.Draw(pairboard)
  for col,kind in enumerate(KINDS):
   d.text((col*176+5,6),kind.upper(),fill=(238,233,218));sd.text((col*88+2,5),kind.upper(),fill=(238,233,218))
   for row,direction in enumerate(DIRS):
    case=kind+'-'+direction;i=int(metadata[case]['current']['hit_frame'])+offset
    crop=crop_at(captures[case]['sample'][i],metadata[case]['current']['centers'][i])
    d.text((col*176+5,29+row*174),'L > R' if row==0 else 'R > L',fill=(238,233,218))
    b.paste(crop.resize((176,144),Image.Resampling.NEAREST),(col*176,49+row*174))
    sd.text((col*88+2,24+row*96),'L > R' if row==0 else 'R > L',fill=(238,233,218));small.paste(crop,(col*88,40+row*96))
   case=kind+'-right';i=int(metadata[case]['current']['hit_frame'])+offset
   for row,v in enumerate(['current','sample']):
    pd.text((col*176+5,row*174+6),kind.upper()+' / '+v.upper(),fill=(238,233,218))
    pairboard.paste(crop_at(captures[case][v][i],metadata[case]['current']['centers'][i]).resize((176,144),Image.Resampling.NEAREST),(col*176,row*174+30))
  frames.append(b);native.append(small);pairs.append(pairboard)
 timing=[30 if i%3<2 else 40 for i in range(len(frames))]
 gif(OUT/'four-materials.gif',frames,timing);gif(OUT/'four-materials-native.gif',native,timing);gif(OUT/'current-vs-samples.gif',pairs,timing)
 for delta,name in [(2,'early'),(7,'middle'),(15,'late')]:frames[delta+3].save(OUT/f'contact-{name}.png')
 print('Packaged four materials in both directions, 8 baseline/sample clips and 1x/2x comparisons')

if __name__=='__main__':main()
