"""Export no-target reviews using the same 30 Hz native captures in every panel."""
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2] / "docs"
study = root / "charmander_ember_family"
current = study / "native"
left = study / "left/native"
previous = root / "charmander_sv_forward/native"
ember = root / "charmander_move_audit/no-target"
font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 13)
cuts = [(source, move, title + "  ·  " + direction)
        for move, title in [("scratch","할퀴기"),("slash","베어가르기")]
        for source, direction in [(previous,"이전 →"),(current,"수정 →"),(left,"수정 ←")]]
fire = [(ember,"ember","불꽃세례  ·  기준"),(current,"flamethrower","화염방사"),
        (current,"fire_fang","불꽃엄니"),(current,"fire_spin","회오리불꽃"),
        (current,"inferno","연옥"),(current,"flare_blitz","플레어드라이브")]
flame = [(previous,"flamethrower","이전 화염방사"),(current,"flamethrower","수정 화염방사")]
fire_pairs = [(src,id_,label) for _,id_,name in fire[1:]
              for src,label in [(previous,"이전  ·  "+name),(current,"수정  ·  "+name)]]

def export(file, panels, columns, count):
    frames = []
    tile_width, tile_height = 192, 116
    for i in range(count):
        frame = Image.new("RGB",(tile_width*columns,tile_height*((len(panels)+columns-1)//columns)),"#293630")
        draw = ImageDraw.Draw(frame)
        for j,(src,move,label) in enumerate(panels):
            x,y = j%columns*tile_width,j//columns*tile_height
            # The mirrored cast extends to the left of the caster.
            start = 66 if src.parent.name=="left" else 143
            with Image.open(src/move/f"{i:03}.png") as im:
                assert im.size==(384,216)
                frame.paste(im.crop((start,49,start+192,145)),(x,y+20))
            draw.text((x+6,y+1),label,font=font,fill="#faf6ec")
        frames.append(frame)
    w,h=frames[0].size
    palette_image=Image.new("RGB",(w,h*((count+2)//3)))
    for i,frame in enumerate(frames[::3]):
        palette_image.paste(frame,(0,h*i))
    palette=palette_image.quantize(256,dither=Image.Dither.NONE)
    indexed=[frame.quantize(palette=palette,dither=Image.Dither.NONE) for frame in frames]
    # 0.75x playback, with GIF's 10 ms duration units distributed across each clip.
    durations=[10*(round((i+1)*40/9)-round(i*40/9)) for i in range(count)]
    out = study/file
    indexed[0].save(out,save_all=True,append_images=indexed[1:],duration=durations,loop=0,disposal=1,optimize=False)
    with Image.open(out) as gif:
        actual = 0
        for i in range(gif.n_frames):
            gif.seek(i)
            actual+=gif.info["duration"]
        assert actual==sum(durations)
    print(file, actual, flush=True)

if __name__=="__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--downstroke",action="store_true")
    parser.add_argument("--raised-finish",action="store_true")
    parser.add_argument("--lift-stroke",action="store_true")
    args=parser.parse_args()
    if args.raised_finish or args.lift_stroke:
        down=root/"charmander_downstroke"
        raised=down/("lifted" if args.lift_stroke else "raised")
        panels=[(src,move,name+"  ·  "+label)
                for move,name in [("scratch","할퀴기"),("slash","베어가르기")]
                for src,label in [(down/"native","기존 높이"),(raised/"native","높인 시안")]]
        export(raised/"comparison.gif",panels,2,34)
        raise SystemExit(0)
    if args.downstroke:
        down=root/"charmander_downstroke"
        panels=[(src,move,name+"  ·  "+label)
                for move,name in [("scratch","할퀴기"),("slash","베어가르기")]
                for src,label in [(current,"이전 ↗"),(down/"native","수정 ↘"),(down/"left/native","수정 ↙")]]
        export(down/"cuts.gif",panels,3,34)
        raise SystemExit(0)
    export("cuts.gif", cuts, 3, 34)
    export("fire-family.gif", fire, 3, 54)
    export("flamethrower.gif", flame, 2, 54)
    export("fire-comparison.gif", fire_pairs, 2, 54)
