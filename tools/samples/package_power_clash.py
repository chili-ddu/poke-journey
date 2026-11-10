"""Arrange three simultaneous casts, with each exchange labelled from its HP trace."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root=Path(__file__).resolve().parents[2]/"docs/projectile_clash"
cases=[("water_wins",30,50),("equal",50,50),("fire_wins",50,30)]
font=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",14)
small=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",12)
logs={k:json.loads((root/k/"frames.json").read_text()) for k,_,_ in cases}
frames=[]
for i in range(len(logs["equal"])):
    canvas=Image.new("RGB",(570,162),"#26342e")
    d=ImageDraw.Draw(canvas)
    for col,(k,fire,water) in enumerate(cases):
        x=190*col
        d.text((x+6,1),f"불꽃 {fire}   ×   물 {water}",font=font,fill="#fff3d4")
        with Image.open(root/k/f"{i:02d}.png") as im:
            assert im.size==(384,216)
            canvas.paste(im.crop((138,50,328,150)),(x,22))
        clashes,hp,enemy_hp=logs[k][i]
        outcome="두 기술 발사" if i>=9 else "준비"
        if clashes:
            outcome=(f"물 {water-fire} 통과  ←" if water>fire else f"불꽃 {fire-water} 통과  →") if water!=fire else "완전 상쇄"
        d.text((x+6,123),outcome,font=small,fill="#b5e5f1" if water>fire else "#ffd1aa" if fire>water else "#dfe5df")
        d.text((x+6,142),f"파이리 {hp} HP   ·   꼬부기 {enemy_hp} HP",font=small,fill="#f1f2e4")
    frames.append(canvas)
atlas=Image.new("RGB",(570,162*len(frames[::3])))
for i,f in enumerate(frames[::3]):atlas.paste(f,(0,162*i))
pal=atlas.quantize(256,dither=Image.Dither.NONE)
indexed=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in frames]
times=[10*(round((i+1)*100/30)-round(i*100/30)) for i in range(len(indexed))]
times[-1]+=550
indexed[0].save(root/"power.gif",save_all=True,append_images=indexed[1:],duration=times,loop=0,disposal=1,optimize=False)
