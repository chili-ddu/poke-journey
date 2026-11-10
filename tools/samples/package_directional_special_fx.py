from pathlib import Path
import json
from PIL import Image,ImageDraw
from package_ember_hit_variants import gif
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/directional_special_fx'
DIRS=['right','left','front','back'];LABELS=['LEFT > RIGHT','RIGHT > LEFT','FRONT > BACK','BACK > FRONT']

def crop_at(image,center,size=(88,72)):
 cx,cy=center;w,h=size
 return image.crop((round(cx-w/2),round(cy-h/2),round(cx+w/2),round(cy+h/2)))

def main():
 rows=json.loads((OUT/'native/checks.json').read_text());assert len(rows)==16
 metadata={};captures={}
 for kind in ['fire','water']:
  for direction in DIRS:
   case=kind+'-'+direction;pair=[r for r in rows if r['case']==case];assert len(pair)==2
   assert pair[0]['trace']==pair[1]['trace'] and pair[0]['hit_frame']==pair[1]['hit_frame']
   assert all(r['measured_direction']==direction and r['projectile_candidates']==1 for r in pair)
   metadata[case]={r['variant']:r for r in pair}
   captures[case]={v:[Image.open(OUT/f'native/{case}/{v}/{i:03d}.png').convert('RGB') for i in range(60)] for v in ['current','sample']}
   frames=[]
   for i in range(60):
    b=Image.new('RGB',(512,296),(28,33,30));d=ImageDraw.Draw(b)
    for col,v in enumerate(['current','sample']):
     d.text((col*256+8,6),case.upper()+' / '+v.upper(),fill=(238,233,218))
     crop=crop_at(captures[case][v][i],metadata[case]['current']['centers'][i],(96,80))
     b.paste(crop,(col*256+80,27))
     b.paste(crop.resize((192,160),Image.Resampling.NEAREST),(col*256+32,136))
    frames.append(b)
   gif(OUT/f'{case}-comparison.gif',frames,[30 if i%3<2 else 40 for i in range(60)])
 frames=[];native=[]
 for offset in range(-3,35):
  b=Image.new('RGB',(704,378),(28,33,30));d=ImageDraw.Draw(b)
  small=Image.new('RGB',(352,214),(28,33,30));sd=ImageDraw.Draw(small)
  for col,label in enumerate(LABELS):
   d.text((col*176+6,7),label,fill=(238,233,218));sd.text((col*88+2,5),['L > R','R > L','FRONT > BACK','BACK > FRONT'][col],fill=(238,233,218))
  for row,kind in enumerate(['fire','water']):
   for col,direction in enumerate(DIRS):
    case=kind+'-'+direction;i=int(metadata[case]['current']['hit_frame'])+offset
    crop=crop_at(captures[case]['sample'][i],metadata[case]['current']['centers'][i])
    d.text((col*176+6,29+row*174),kind.upper()+f' / impact {offset:+d}f',fill=(238,233,218))
    b.paste(crop.resize((176,144),Image.Resampling.NEAREST),(col*176,49+row*174))
    sd.text((col*88+3,24+row*96),kind.upper(),fill=(238,233,218));small.paste(crop,(col*88,40+row*96))
  frames.append(b);native.append(small)
 durations=[30 if i%3<2 else 40 for i in range(len(frames))]
 gif(OUT/'four-directions.gif',frames,durations);gif(OUT/'four-directions-native.gif',native,durations)
 sheet=Image.new('RGB',(704,174*6),(28,33,30));d=ImageDraw.Draw(sheet)
 for r,(kind,delta) in enumerate((k,t) for k in ['fire','water'] for t in [2,7,15]):
  for col,direction in enumerate(DIRS):
   case=kind+'-'+direction;i=int(metadata[case]['current']['hit_frame'])+delta
   crop=crop_at(captures[case]['sample'][i],metadata[case]['current']['centers'][i])
   d.text((col*176+5,r*174+5),kind+' / '+direction+f' +{delta}',fill=(238,233,218))
   sheet.paste(crop.resize((176,144),Image.Resampling.NEAREST),(col*176,r*174+26))
 sheet.save(OUT/'native-contact.png');frames[9].save(OUT/'overview-still.png')
 print('Packed actual direction-aware fire/water, 8 original/sample clips and 1x/2x four-direction grids')

if __name__=='__main__':main()
