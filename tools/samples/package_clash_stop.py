"""Play each pair on the same clock so the short local stop stays visible."""
from pathlib import Path
import json
from PIL import Image,ImageFont,ImageDraw

root=Path(__file__).resolve().parents[2]/"docs/projectile_clash"
out=root/"hitstop"
font=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",13)

def export(name,panels):
    logs=[json.loads((path/"frames.json").read_text()) for path,_ in panels]
    frames=[]
    for i in range(len(logs[0])):
        image=Image.new("RGB",(380,141),"#26342e")
        draw=ImageDraw.Draw(image)
        for j,(path,label) in enumerate(panels):
            x=j*190
            draw.text((x+5,2),label,font=font,fill="#fff4d8")
            with Image.open(path/f"{i:02d}.png") as shot:
                assert shot.size==(384,216)
                image.paste(shot.crop((145,55,335,153)),(x,21))
            _,hp,foe=logs[j][i]
            opponent="나옹" if name=="melee.gif" else "꼬부기"
            draw.text((x+5,120),f"파이리 {hp} HP    {opponent} {foe} HP",font=font,fill="#e0ece4")
        frames.append(image)
    colors=Image.new("RGB",(380,141*len(frames[::3])))
    for i,f in enumerate(frames[::3]):colors.paste(f,(0,i*141))
    palette=colors.quantize(256)
    seq=[f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    times=[10*(round((i+1)*100/30)-round(i*100/30)) for i in range(len(seq))]
    times[-1]+=400
    seq[0].save(out/name,save_all=True,append_images=seq[1:],duration=times,loop=0,disposal=1)
    first=next(i for i,row in enumerate(logs[-1]) if row[0])
    frames[first+1].save(out/(Path(name).stem+".png"))
export("ranged.gif",[(root/"fragments/glint/weak_recipient","물줄기 · 바로 진행"),(out/"weak_recipient","물줄기 · 충돌에서 2프레임")])
export("melee.gif",[(out/"even_melee","할퀴기 40 × 할퀴기 40"),(out/"strong_melee","베어가르기 70 × 할퀴기 40")])
