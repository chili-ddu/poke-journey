"""Compare residual move power, relative diameter, and actual HP in the same arena."""
from pathlib import Path
import json
from PIL import Image,ImageDraw,ImageFont

root=Path(__file__).resolve().parents[2]/"docs/projectile_clash"
cases=[("full_water","① 물대포 단독"),("base_subtract","② 위력끼리 차감"),("type_subtract","③ 충돌에도 물 상성 적용")]
font=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",14)
small=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",13)
logs={k:json.loads((root/k/"frames.json").read_text()) for k,_ in cases}
results={k:json.loads((root/k/"result.json").read_text()) for k,_ in cases}
frames=[]
for i in range(len(logs["full_water"])):
    frame=Image.new("RGB",(600,180),"#26342e")
    draw=ImageDraw.Draw(frame)
    for j,(k,label) in enumerate(cases):
        x=200*j
        draw.text((x+6,2),label,font=font,fill="#fff2d4")
        draw.text((x+6,21),"물 50" if j==0 else "불 30   ×   물 50",font=small,fill="#dcebe6")
        with Image.open(root/k/f"{i:02d}.png") as im:
            frame.paste(im.crop((137,52,337,149)),(x,41))
        n,hp,_=logs[k][i]
        power=results[k]["remaining"] if n else 50
        size=results[k]["size_ratio"] if n else 1.0
        draw.text((x+6,139),f"물 위력 {power:.0f}   ·   굵기 {size:.0%}",font=small,fill="#a8daef")
        draw.text((x+6,158),f"파이리가 잃은 HP   {logs[k][0][1]-hp}",font=small,fill="#fff2d4")
    frames.append(frame)
atlas=Image.new("RGB",(600,180*len(frames[::4])))
for i,im in enumerate(frames[::4]):atlas.paste(im,(0,180*i))
pal=atlas.quantize(256,dither=Image.Dither.NONE)
gif=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in frames]
times=[10*(round((i+1)*100/30)-round(i*100/30)) for i in range(len(frames))]
times[-1]+=700
gif[0].save(root/"typed-clash.gif",save_all=True,append_images=gif[1:],duration=times,loop=0,disposal=1)
