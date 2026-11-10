"""Compare the two renderings at the same simulation time and at native scale."""
from pathlib import Path
import argparse
import json
from PIL import Image,ImageDraw,ImageFont

base=Path(__file__).resolve().parents[2]/"docs/projectile_clash"
out=base/"fragments"
versions=[(base/"weak_recipient","기존 · 수증기"),(out/"weak_recipient","시안 · 불티와 물방울")]
parser=argparse.ArgumentParser()
parser.add_argument("--glint",action="store_true")
if parser.parse_args().glint:
    out=out/"glint"
    versions=[(out.parent/"weak_recipient","기존 파편"),(out/"weak_recipient","시안 · 은은한 빛")]
a,b=[json.loads((p/"frames.json").read_text()) for p,_ in versions]
assert a==b and a[-1][0]==1
for key in ["radius_ratio","landed"]:
    assert len({json.dumps(json.loads((p/"result.json").read_text())[key],sort_keys=True) for p,_ in versions})==1
font=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",14)
frames=[]
for i in range(len(a)):
    canvas=Image.new("RGB",(392,126),"#27352d")
    pen=ImageDraw.Draw(canvas)
    for j,(folder,title) in enumerate(versions):
        pen.text((j*196+6,2),title,font=font,fill="#fff2d8")
        with Image.open(folder/f"{i:02d}.png") as shot:
            assert shot.size==(384,216)
            canvas.paste(shot.crop((140,50,336,152)),(196*j,23))
    frames.append(canvas)
hit=next(i for i,row in enumerate(a) if row[0])
def encode(seq,times,name):
    atlas=Image.new("RGB",(seq[0].width,seq[0].height*len(seq[::2])))
    for i,frame in enumerate(seq[::2]):atlas.paste(frame,(0,i*frame.height))
    pal=atlas.quantize(256)
    g=[f.quantize(palette=pal,dither=Image.Dither.NONE) for f in seq]
    g[0].save(out/name,save_all=True,append_images=g[1:],duration=times,loop=0,disposal=1)
times=[10*(round((i+1)*100/30)-round(i*100/30)) for i in range(len(frames))]
times[-1]+=420
encode(frames,times,"compare.gif")
close=[f.crop((196,23,392,125)).resize((392,204),Image.Resampling.NEAREST) for f in frames[hit-4:hit+17]]
encode(close,[65]*(len(close)-1)+[340],"detail.gif")
frames[hit+4].save(out/"contact.png")
