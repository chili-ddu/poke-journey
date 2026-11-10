"""Create synchronized gameplay comparisons from native captures and actual HP."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

folder = Path(__file__).resolve().parents[2]/"docs/charmander_contact_review"
font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",14)
small = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",12)

def export(name, panels, capture_rate, speed):
    records = [json.loads((folder/id_/"trace.json").read_text()) for id_,_ in panels]
    assert len(set(map(len,records)))==1
    frames=[]
    for i in range(len(records[0])):
        frame=Image.new("RGB",(192*len(panels),148),"#28352f")
        draw=ImageDraw.Draw(frame)
        for j,(id_,label) in enumerate(panels):
            x=j*192
            with Image.open(folder/id_/f"{i:03}.png") as image:
                assert image.size==(384,216)
                frame.paste(image.crop((147,41,339,144)),(x,21))
            draw.text((x+6,1),label,font=font,fill="#fff6dd")
            hp, enemy_hp, _=records[j][i]
            text=f"파이리 {hp} HP"
            if enemy_hp>=0: text+=f"   럭키 {enemy_hp} HP"
            draw.text((x+6,126),text,font=small,fill="#f0f1e7")
        frames.append(frame)
    samples=frames[::4]
    colors=Image.new("RGB",(frames[0].width,frames[0].height*len(samples)))
    for i,im in enumerate(samples): colors.paste(im,(0,i*im.height))
    palette=colors.quantize(256,dither=Image.Dither.NONE)
    packed=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    step=100/(capture_rate*speed)
    times=[10*(round((i+1)*step)-round(i*step)) for i in range(len(frames))]
    out=folder/(name+".gif")
    packed[0].save(out,save_all=True,append_images=packed[1:],duration=times,disposal=1,loop=0,optimize=False)
    with Image.open(out) as gif:
        total=0
        for i in range(gif.n_frames):
            gif.seek(i)
            total+=gif.info["duration"]
        assert total==sum(times)
    print(out.name, total)

if __name__=="__main__":
    export("flare-blitz",[("dash_before","이전 시안"),("dash_hit","수정 · 명중"),("dash_miss","수정 · 빗나감")],30,.75)
    export("fire-spin",[("spin_hit","첫 상대에게 명중"),("spin_miss","빈 방향으로 시전")],16,1)
