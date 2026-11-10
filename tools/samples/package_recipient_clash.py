"""Two real recipients, with the shot's power and target multiplier shown separately."""
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

base=Path(__file__).resolve().parents[2]/"docs/projectile_clash"
cases=[("weak_recipient","파이리 · 불꽃"),("neutral_recipient","캐스퐁 · 노말")]
logs={k:json.loads((base/k/"frames.json").read_text()) for k,_ in cases}
info={k:json.loads((base/k/"result.json").read_text()) for k,_ in cases}
font=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",14)
images=[]
for i in range(len(logs["weak_recipient"])):
    frame=Image.new("RGB",(420,174),"#24352f")
    pen=ImageDraw.Draw(frame)
    for j,(key,name) in enumerate(cases):
        x=j*210
        contact,hp,_=logs[key][i]
        pen.text((x+6,1),f"받는 쪽   {name}",font=font,fill="#fff1d5")
        with Image.open(base/key/f"{i:02d}.png") as shot:
            frame.paste(shot.crop((133,48,343,148)),(x,23))
        result=info[key]
        size=result["radius_ratio"] if contact else 1
        power=result["landed"][0]["power"] if contact else 40
        pen.text((x+6,126),f"물줄기 굵기 {size:.0%}   ·   위력 {power:.0f}",font=font,fill="#a5dfef")
        pen.text((x+6,148),f"대상 상성 ×{result['landed'][0]['type_mult']:.0f}   ·   잃은 HP {logs[key][0][1]-hp}",font=font,fill="#fff1d5")
    images.append(frame)
atlas=Image.new("RGB",(420,174*len(images[::3])))
for i,f in enumerate(images[::3]):atlas.paste(f,(0,i*174))
pal=atlas.quantize(256)
packed=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in images]
dur=[10*(round((i+1)*100/30)-round(i*100/30)) for i in range(len(images))]
dur[-1]+=550
packed[0].save(base/"recipient-clash.gif",save_all=True,append_images=packed[1:],duration=dur,loop=0,disposal=1)
