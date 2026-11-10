"""Assemble the preview-only jump comparison selected by Godot."""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw,ImageFont
ROOT=Path(__file__).resolve().parents[1]
OUT=ROOT/'docs/jump_feel_preview'
rows=json.loads((OUT/'selections.json').read_text())
font=lambda s:ImageFont.truetype('/System/Library/Fonts/Supplemental/Arial.ttf',s)
BG=(22,27,37);FG=(230,236,245);MUTED=(163,178,196);CYAN=(91,220,223)
cache={}

def render(index,slow=False):
    im=Image.new('RGB',(1024,460),BG);d=ImageDraw.Draw(im)
    d.text((28,22),'JUMP / FALL & LANDING STUDY',font=font(26),fill=FG)
    d.text((28,62),('HALF SPEED' if slow else 'NORMAL SPEED')+' / same 0.40 s flight and 48 px travel',font=font(18),fill=MUTED)
    d.line((512,100,512,410),fill=(53,65,80))
    for col,e in enumerate(rows[index]):
        x=col*512
        d.text((x+32,110),'BEFORE' if col==0 else 'APPLIED / SOFTER LANDING',font=font(21),fill=FG if col==0 else CYAN)
        d.text((x+32,145),'Original descent / current recoil' if col==0 else 'More time near ground / quicker compression',font=font(15),fill=MUTED)
        baseline=345
        d.line((x+30,baseline+3,x+480,baseline+3),fill=(66,80,94),width=2)
        cx=x+110+e['travel']*4
        # The contact shadow follows the source key in the existing version,
        # and the displayed C subframe in the proposed version.
        t=min(1,max(0,e['height']/24))
        width=62*(1-.45*t);alpha=.35-(.35-.12)*t
        shade=tuple(round(a*(1-alpha)) for a in BG)
        d.ellipse((cx-width/2,baseline-4,cx+width/2,baseline+6),fill=shade)
        path=e['path']
        if path not in cache:cache[path]=Image.open(ROOT/path.removeprefix('res://')).convert('RGBA')
        rx,ry,w,h=map(int,e['rect']);pose=cache[path].crop((rx,ry,rx+w,ry+h));box=pose.getbbox()
        if box:
            sx,sy=[v*4 for v in e['scale']]
            pose=pose.crop(box).resize((max(1,round((box[2]-box[0])*sx)),max(1,round((box[3]-box[1])*sy))),Image.Resampling.NEAREST)
            ax,ay=e['anchor']
            im.paste(pose,(round(cx+(box[0]-ax)*sx),round(baseline+(box[1]-ay-e['feet'])*sy)),pose)
        # Identical understated landing dust in both versions.
        time=index*.02-.7
        if 0<=time<.25:
            opacity=(1-time/.25)*.32
            color=tuple(round(a+(b-a)*opacity) for a,b in zip(BG,(178,160,125)))
            for direction in [-1,1]:
                dx=direction*(12+time*48)
                d.ellipse((cx+dx-6,baseline-2-time*12,cx+dx+6,baseline+4-time*12),fill=color)
    d.text((28,428),'Right: applied timing / flight time and distance preserved',font=font(17),fill=MUTED)
    return im

for slow in [False,True]:
    frames=[render(i,slow) for i in range(len(rows))]
    frames[0].save(OUT/('comparison-half.gif' if slow else 'comparison.gif'),save_all=True,append_images=frames[1:],duration=40 if slow else 20,loop=0,disposal=2,optimize=False)
render(34).save(OUT/'near-landing.png')
with Image.open(OUT/'comparison.gif') as gif:
    duration=0
    for i in range(gif.n_frames):gif.seek(i);duration+=gif.info['duration']
    assert duration==1600,duration
print(OUT/'comparison.gif')
