"""Play three captures of each attack with the same camera crop and contact timing."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2] / "docs/projectile_clash"
out = root / "flecks"
panels = [(root/"rebound", "지난 시안"), (out/"skim", "A  짧게 스침"), (out/"settle", "B  맺혔다 흩어짐")]
font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 14)
scenes = [("weak_recipient", 235), ("even_melee", 205)]
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--momentum", action="store_true")
parser.add_argument("--caster-cuts", action="store_true")
parser.add_argument("--residual-knock", action="store_true")
parser.add_argument("--shimmer", action="store_true")
parser.add_argument("--broken-only", action="store_true")
parser.add_argument("--element-colors", action="store_true")
parser.add_argument("--scaled-cuts", action="store_true")
args = parser.parse_args()
momentum = args.momentum
if momentum:
    out = root / "momentum"
    panels = [(out,"할퀴기 ↔ 할퀴기"),(out,"베어가르기 ↔ 할퀴기"),(out,"불꽃세례 →  ← 물대포")]
    scenes = [("even_melee",205),("strong_melee",205),("weak_recipient",239)]
if args.caster_cuts:
    out = root / "caster_cuts"
    panels = [(root/"momentum", "지난 상쇄 샘플"),(out,"앞발 기준으로 복원")]
    scenes = [("even_melee",205),("strong_melee",205)]
if args.residual_knock:
    out = root / "residual_knock"
    panels = [(root/"caster_cuts","이전 · 파편 6개"),(out,"수정 · 파편 16개")]
    scenes = [("strong_melee",231),("even_melee",205),("weak_recipient",239)]

if args.shimmer:
    out = root / "shimmer"
    panels = [(root/"residual_knock","이전 · 16개"),(out,"32개 · 파편 반짝임")]
    scenes = [("strong_melee",231),("even_melee",205),("weak_recipient",239)]

if args.broken_only:
    out = root / "broken_only"
    panels = [(root/"shimmer","이전 · 양쪽 파편"),(out,"수정 · 깨진 기술의 파편")]
    scenes = [("strong_melee",231),("even_melee",205),("weak_recipient",239)]

if args.element_colors:
    out = root / "element_colors"
    panels = [(root/"broken_only","이전 색상"),(out,"수정 · 불씨와 물방울")]
    scenes = [("weak_recipient",236),("water_mirror",236)]

if args.scaled_cuts:
    out = root / "scaled_cuts"
    panels = [(root/"broken_only","이전 · 궤적 크기"),(out,"수정 · 남은 위력만큼")]
    scenes = [("strong_melee",231),("even_melee",205)]

def capture(folder, scene):
    if args.element_colors and folder == root/"broken_only" and scene == "water_mirror":
        return out/"before"/scene
    if args.residual_knock and folder == root/"caster_cuts" and scene == "weak_recipient":
        return root/"momentum"/scene
    return folder/scene

timings = {}
for scene, _ in scenes:
    control = json.loads((capture(panels[0][0],scene)/"frames.json").read_text())
    if scene != "water_mirror":
        baseline = json.loads((root/"rebound"/scene/"frames.json").read_text())
        assert baseline == control
    for folder, _ in panels[1:]:
        assert json.loads((capture(folder,scene)/"frames.json").read_text()) == control
    timings[scene] = next(i for i, row in enumerate(control) if row[0])

def export(scale):
    half_width = 83 if args.residual_knock or args.shimmer or args.broken_only or args.element_colors or args.scaled_cuts else (73 if momentum else 64)
    w, h = half_width*2*scale, 61*scale
    frames = []
    for age in range(-9, 23):
        frame = Image.new("RGB", ((w+2)*len(panels)-2, 28+h if momentum else 28+(h+2)*len(scenes)-2), "#27332f")
        draw = ImageDraw.Draw(frame)
        for col, (folder,label) in enumerate(panels):
            x = (w+2)*col
            draw.text((x+6,4), label, font=font, fill="#f7ecd1")
            for row,(scene,center) in enumerate([scenes[col]] if momentum else scenes):
                index = timings[scene]+age
                with Image.open(capture(folder,scene)/f"{index:02d}.png") as raw:
                    assert raw.size==(384,216)
                    crop = raw.crop((center-half_width,74,center+half_width,135))
                    frame.paste(crop.resize((w,h),Image.Resampling.NEAREST),(x,28+(h+2)*row))
        frames.append(frame)
    contact = Image.new("RGB",(frames[0].width,frames[0].height*len(frames)))
    for i,frame in enumerate(frames):
        contact.paste(frame,(0,i*frame.height))
    palette = contact.quantize(256)
    seq = [f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    times = [10*(round((i+1)*100/30)-round(i*100/30)) for i in range(len(seq))]
    times[-1] += 450
    seq[0].save(out/f"compare-{scale}x.gif",save_all=True,append_images=seq[1:],duration=times,loop=0,disposal=1)
for scale in (1,2):
    export(scale)
