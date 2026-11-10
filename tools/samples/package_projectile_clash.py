"""Synchronized game captures, cropped at native scale with live contact counters."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

base=Path(__file__).resolve().parents[2]/"docs/projectile_clash"
cases=[("through","기존 · 서로 통과"),("clash","시안 · 정면 충돌"),("offset","시안 · 엇갈려 발사")]
font=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",14)
small=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",12)
logs={k:json.loads((base/k/"frames.json").read_text()) for k,_ in cases}
frames=[]
for i in range(len(logs["through"])):
    canvas=Image.new("RGB",(540,147),"#24332d")
    draw=ImageDraw.Draw(canvas)
    for j,(key,label) in enumerate(cases):
        x=180*j
        draw.text((x+5,1),label,font=font,fill="#fff5d9")
        with Image.open(base/key/f"{i:02d}.png") as shot:
            assert shot.size==(384,216)
            canvas.paste(shot.crop((145,53,325,154)),(x,21))
        pairs,hp1,hp2=logs[key][i]
        draw.text((x+5,127),f"상쇄 {pairs}쌍   HP {hp1} / {hp2}",font=small,fill="#ddebdf")
    frames.append(canvas)
sample=next(i for i,(pairs,*_) in enumerate(logs["clash"]) if pairs)
frames[min(sample+2,len(frames)-1)].save(base/"contact.png")
atlas=Image.new("RGB",(540,147*len(frames[::3])))
for i,f in enumerate(frames[::3]):atlas.paste(f,(0,i*147))
palette=atlas.quantize(256,dither=Image.Dither.NONE)
packed=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
times=[10*(round((i+1)*100/30)-round(i*100/30)) for i in range(len(packed))]
times[-1]+=350
packed[0].save(base/"comparison.gif",save_all=True,append_images=packed[1:],duration=times,loop=0,disposal=1,optimize=False)

# Close view of the collision window, identical pixel data at 2×.
close=[]
first=max(0,sample-6)
last=min(len(frames),sample+19)
for i in range(first,last):
    panel=frames[i].crop((180,0,360,147))
    close.append(panel.resize((360,294),Image.Resampling.NEAREST).quantize(palette=palette,dither=Image.Dither.NONE))
close[0].save(base/"clash-close.gif",save_all=True,append_images=close[1:],duration=[60]*(len(close)-1)+[370],loop=0,disposal=1,optimize=False)
