from pathlib import Path
from PIL import Image, ImageFont, ImageDraw

root=Path(__file__).resolve().parents[2]/"docs/all_move_targets"
labels=[("ember","파이리 · 불꽃세례 →"),("water_gun","꼬부기 · 물대포 ←"),("icy_wind","글레이시아 · 얼다바람 ↑"),("dragon_rage","리자몽 · 용의분노 ↓")]
font=ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc",13)
frames=[]
for i in range(22):
    frame=Image.new("RGB",(560,242),"#25352d")
    draw=ImageDraw.Draw(frame)
    for x,(id,label) in enumerate(labels):
        draw.text((x*140+4,0),label,font=font,fill="#fff1d0")
        for y,stage in enumerate(("before","after")):
            with Image.open(root/stage/id/f"{i:02d}.png") as shot:
                assert shot.size==(384,216)
                frame.paste(shot.crop((122,42,262,152)),(140*x,18+112*y))
    for y,label in [(18,"기존"),(130,"조정")]:
        draw.rectangle((0,y,29,y+16),fill="#25352d")
        draw.text((3,y),label,font=font,fill="#fff1d0")
    frames.append(frame)
frames[5].save(root/"release.png")
palette=Image.new("RGB",(560,242*len(frames[::4])))
for i,f in enumerate(frames[::4]):palette.paste(f,(0,i*242))
colors=palette.quantize(256)
indexed=[f.quantize(palette=colors,dither=Image.Dither.NONE) for f in frames]
indexed[0].save(root/"release.gif",save_all=True,append_images=indexed[1:],duration=[45]*21+[390],loop=0,disposal=1)

frames=[]
for i in range(56):
    frame=Image.new("RGB",(560,139),"#25352d")
    draw=ImageDraw.Draw(frame)
    for x,(id,label) in enumerate(labels):
        draw.text((x*140+4,0),label,font=font,fill="#fff1d0")
        with Image.open(root/"play"/id/f"{i:02d}.png") as shot:
            frame.paste(shot.crop((122,39,262,160)),(140*x,18))
    frames.append(frame.quantize(palette=colors,dither=Image.Dither.NONE))
frames[0].save(root/"battle.gif",save_all=True,append_images=frames[1:],duration=[30]*55+[280],loop=0,disposal=1)
