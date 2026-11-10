"""Build a comparison GIF from combat_pose_review.gd render selections."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/combat_pose_timing'
rows=json.loads((OUT/'selections.json').read_text())
font=lambda s:ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',s)
cache={}
frames=[]
for entries in rows:
    im=Image.new('RGB',(800,600),(22,27,37));d=ImageDraw.Draw(im)
    d.text((24,18),'COMBAT POSES / TIMING & TRANSITIONS',font=font(24),fill='white')
    d.text((24,54),'Normal speed / same action and damage timing',font=font(17),fill=(163,178,196))
    d.text((110,100),'BEFORE',font=font(21),fill=(230,236,245))
    d.text((505,100),'AFTER',font=font(21),fill=(91,220,223))
    d.line((400,94,400,558),fill=(53,65,80))
    for k,entry in enumerate(entries):
        row=k//2;col=k%2
        origin=(col*400,row*220+130)
        d.text((origin[0]+24,origin[1]+8),'SCRATCH' if row==0 else 'HURT',font=font(17),fill=(163,178,196))
        p=ROOT/entry['path'].removeprefix('res://')
        if p not in cache:cache[p]=Image.open(p).convert('RGBA')
        x,y,w,h=map(int,entry['rect'])
        pose=cache[p].crop((x,y,x+w,y+h)).resize((w*4,h*4),Image.Resampling.NEAREST)
        ax,ay=entry['anchor']
        im.paste(pose,(round(origin[0]+200-ax*4),round(origin[1]+155-ay*4)),pose)
        d.line((origin[0]+80,origin[1]+200,origin[0]+320,origin[1]+200),fill=(53,65,80))
    d.text((24,572),'C interpolation / no new input lock or damage delay',font=font(17),fill=(163,178,196))
    frames.append(im)
frames[0].save(OUT/'before-after.gif',save_all=True,append_images=frames[1:],duration=20,loop=0,disposal=2,optimize=False)
frames[6].save(OUT/'comparison-still.png')
print(OUT/'before-after.gif')
