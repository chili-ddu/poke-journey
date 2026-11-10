"""Package the native 384×216 captures without resizing any gameplay pixels."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

folder=Path(__file__).resolve().parents[2]/"docs/contact_moves_live"
font=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",13)

def export(filename, scenes, fps, shape=False):
    traces=[json.loads((folder/id/"trace.json").read_text()) for id,_ in scenes]
    frames=[]
    for i in range(len(traces[0])):
        frame=Image.new("RGB",(220*len(scenes),151),"#25352d")
        d=ImageDraw.Draw(frame)
        for j,(id,label) in enumerate(scenes):
            x=j*220
            d.text((x+5,1),label,font=font,fill="#fff1d0")
            with Image.open(folder/id/f"{i:03d}.png") as shot:
                assert shot.size==(384,216)
                frame.paste(shot.crop((122,42,342,150)),(x,21))
            row=traces[j][i]
            if shape:
                losses=[a-b for a,b in zip(traces[j][0],row)]
                msg="상대가 잃은 HP   "+"  /  ".join(map(str,losses))
            else:
                msg=f"파이리 {row[0]} HP"+(f"     럭키 {row[1]} HP" if row[1]>=0 else "")
            d.text((x+5,131),msg,font=font,fill="#e7eee7")
        frames.append(frame)
    samples=frames[::5]
    atlas=Image.new("RGB",(frames[0].width,151*len(samples)))
    for i,s in enumerate(samples): atlas.paste(s,(0,i*151))
    palette=atlas.quantize(256,dither=Image.Dither.NONE)
    indexed=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    time=[10*(round((i+1)*100/fps)-round(i*100/fps)) for i in range(len(indexed))]
    indexed[0].save(folder/(filename+".gif"),save_all=True,append_images=indexed[1:],duration=time,loop=0,disposal=1,optimize=False)

if __name__=="__main__":
    export("recoil",[("dash_hit","플레어드라이브 · 명중"),("dash_miss","플레어드라이브 · 빗나감")],30)
    export("fire-spin",[("spin_hit","회오리불꽃 · 첫 상대 위치"),("spin_miss","회오리불꽃 · 최대 사거리")],16)
    export("contact-family",[("take_down","돌진 · 반동 ¼"),("double_edge","이판사판태클 · 반동 ⅓")],30)
    export("next-shapes",[("water_gun","꼬부기 · 물대포  |  정면"),("icy_wind","글레이시아 · 얼다바람  |  부채꼴"),("bulldoze","꼬마돌 · 땅고르기  |  주변")],30,True)
