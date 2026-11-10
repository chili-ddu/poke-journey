from pathlib import Path
import json
from PIL import Image,ImageDraw
from package_ember_hit_variants import gif
from package_skill_fx_batch1 import body_crop
ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'docs/skill_fx_bases/category_samples'
OUT=ROOT/'docs/skill_fx_bases/category_fill'
# (row,type-column): old batch1 sample or new actual cast capture.
GRID={
 (0,0):('new','fang','FIRE FANG'),(0,1):('old','fire','EMBER'),(0,2):('new','wisp','WILL O WISP [VFX]'),
 (1,0):('new','tail','AQUA TAIL'),(1,1):('old','water','WATER GUN'),(1,2):('new','shell','WITHDRAW'),
 (2,0):('new','punch','THUNDER PUNCH'),(2,1):('old','electric','THUNDER SHOCK'),(2,2):('new','paralyze','THUNDER WAVE'),
 (3,0):('old','grass','RAZOR LEAF'),(3,1):('new','petal','PETAL DANCE'),(3,2):('new','sleep','SLEEP POWDER')}

def native_crop(image,center,size=(96,80)):
 cx,cy=center;w,h=size
 return image.crop((round(cx-w/2),round(cy-h/2),round(cx+w/2),round(cy+h/2)))

def main():
 checks=json.loads((BASE/'native/checks.json').read_text())+json.loads((OUT/'native/checks.json').read_text());assert len(checks)==16
 oldroot=ROOT/'docs/skill_fx_bases/batch1'
 oldchecks=json.loads((oldroot/'native/checks.json').read_text())
 metadata={};captures={};oldcaptures={}
 for k in ['fang','tail','shell','paralyze','petal','sleep','wisp','punch']:
  rows=[r for r in checks if r['style']==k];assert len(rows)==2
  assert rows[0]['trace']==rows[1]['trace'] and rows[0]['event_frame']==rows[1]['event_frame']
  metadata[k]={r['variant']:r for r in rows}
  folder=OUT if k in ['wisp','punch'] else BASE
  captures[k]={v:[Image.open(folder/f'native/{k}/{v}/{f:03d}.png').convert('RGB') for f in range(int(metadata[k][v]['frames']))] for v in ['current','sample']}
  if k not in ['wisp','punch']:continue
  full=[]
  for f in range(len(captures[k]['sample'])):
   b=Image.new('RGB',(576,330),(28,33,30));d=ImageDraw.Draw(b)
   size=(128,96) if k in ['petal','wisp'] else (96,80)
   for col,v in enumerate(['current','sample']):
    d.text((col*288+8,7),(('CURRENT / NO BURN LOGIC' if v=='current' else 'VFX STUDY / NO BURN') if k=='wisp' else k.upper()+' / '+v.upper()),fill=(237,233,218))
    center=metadata[k]['current']['centers'][f]
    crop=native_crop(captures[k][v][f],center,size)
    # Actual size inset plus 2x nearest detail.
    b.paste(crop,(col*288+(288-size[0])//2,29))
    zoom=crop.resize((size[0]*2,size[1]*2),Image.Resampling.NEAREST)
    b.paste(zoom,(col*288+(288-zoom.width)//2,330-zoom.height))
   full.append(b)
  gif(OUT/f'{k}-current-vs-sample.gif',full,[30 if f%3<2 else 40 for f in range(len(full))])
 for k in ['fire','water','electric','grass']:
  oldcaptures[k]={v:[Image.open(oldroot/f'native/{k}/{v}/{f:03d}.png').convert('RGB') for f in range(66)] for v in ['current','sample']}
 frames=[];native_frames=[]
 # 1.2s common window, aligned to actual hit/status/zone/buff event, no time scaling.
 for n,offset in enumerate(range(-3,33)):
  b=Image.new('RGB',(648,806),(28,33,30));d=ImageDraw.Draw(b)
  small=Image.new('RGB',(324,446),(28,33,30));sd=ImageDraw.Draw(small)
  for col,label in enumerate(['PHYSICAL','SPECIAL','STATUS']):
   d.text((col*216+8,8),label,fill=(237,233,218));sd.text((col*108+3,5),label,fill=(237,233,218))
  for row,kind in enumerate(['FIRE','WATER','ELECTRIC','GRASS']):
   for col in range(3):
    x=col*216;y=30+row*194
    if (row,col) not in GRID:
     d.text((x+8,y+8),kind+' / RESERVED',fill=(160,168,157));d.text((x+8,y+44),'No shaped move sampled',fill=(160,168,157));continue
    source,k,label=GRID[(row,col)]
    d.text((x+7,y+5),kind+' / '+label,fill=(237,233,218))
    if source=='new':
     meta=metadata[k]['sample'];f=max(0,min(int(meta['frames'])-1,int(meta['event_frame'])+offset))
     crop=body_crop(captures[k]['sample'][f],captures[k]['current'][f]).crop((0,5,90,85)) if k=='wisp' else native_crop(captures[k]['sample'][f],metadata[k]['current']['centers'][f])
    else:
     hit=int(next(r['hit_frame'] for r in oldchecks if r['type']==k));f=hit+offset
     crop=body_crop(oldcaptures[k]['sample'][f],oldcaptures[k]['current'][f]).crop((0,5,90,85))
    # A separate 1x board avoids overlapping the enlarged preview.
    sd.text((col*108+3,25+row*104),label[:17],fill=(237,233,218))
    small.paste(crop,(col*108+(108-crop.width)//2,43+row*104))
    zoom=crop.resize((crop.width*2,crop.height*2),Image.Resampling.NEAREST)
    b.paste(zoom,(x+216-zoom.width,y+194-zoom.height))
   d.line((0,y+193,648,y+193),fill=(58,66,58))
  frames.append(b);native_frames.append(small)
 gif(OUT/'category-grid.gif',frames,[30 if n%3<2 else 40 for n in range(len(frames))])
 gif(OUT/'category-grid-native.gif',native_frames,[30 if n%3<2 else 40 for n in range(len(frames))])
 # One still for frame QA; the shared animated sample itself remains normal speed.
 frames[10].save(OUT/'grid-still.png')
 pair=[]
 for offset in range(-3,33):
  board=Image.new('RGB',(540,408),(28,33,30));d=ImageDraw.Draw(board)
  for col,k in enumerate(['wisp','punch']):
   f=int(metadata[k]['sample']['event_frame'])+offset
   if k=='wisp':crop=body_crop(captures[k]['sample'][f],captures[k]['current'][f])
   else:crop=native_crop(captures[k]['sample'][f],metadata[k]['current']['centers'][f],(90,90))
   d.text((col*270+6,7),'WILL O WISP / VFX ONLY' if k=='wisp' else 'THUNDER PUNCH / PHYSICAL',fill=(237,233,218))
   board.paste(crop,(col*270+90,28))
   board.paste(crop.resize((270,270),Image.Resampling.NEAREST),(col*270,138))
  pair.append(board)
 gif(OUT/'new-two-samples.gif',pair,[30 if n%3<2 else 40 for n in range(len(pair))])
 pair[8].save(OUT/'new-two-still.png')
 print('Packaged all 12 cells, including Wisp visual-only label, and 2 new full-cast comparisons')

if __name__=='__main__':main()
