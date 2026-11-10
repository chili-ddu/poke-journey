"""Compare the isolated battle captures on the same 30 fps clock."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2] / "docs/projectile_clash"
out = root / "rebound"
font = ImageFont.truetype("/System/Library/Fonts/AppleSDGothicNeo.ttc", 15)
def compare(name, panels):
    frames = []
    logs = [json.loads((path / "frames.json").read_text()) for path, _ in panels]
    assert len(logs[0]) == len(logs[1])
    for frame in range(len(logs[0])):
        image = Image.new("RGB", (562, 182), "#26362e")
        draw = ImageDraw.Draw(image)
        for index, (path, label) in enumerate(panels):
            left = 282 * index
            draw.text((left + 8, 4), label, font=font, fill="#fff5dc")
            with Image.open(path / f"{frame:02d}.png") as shot:
                assert shot.size == (384,216)
                center = 238 if name == "fragments.gif" else 203
                region = shot.crop((center-70, 64, center+70, 142))
                image.paste(region.resize((280,156), Image.Resampling.NEAREST), (left,26))
        frames.append(image)
    samples = Image.new("RGB",(562,182*len(frames[::2])))
    for i, f in enumerate(frames[::2]):
        samples.paste(f,(0,182*i))
    palette = samples.quantize(256)
    seq = [f.quantize(palette=palette,dither=Image.Dither.NONE) for f in frames]
    times = [10*(round((i+1)*100/30)-round(i*100/30)) for i in range(len(seq))]
    times[-1] += 440
    seq[0].save(out / name, save_all=True, append_images=seq[1:], duration=times, loop=0, disposal=1)

compare("melee.gif", [(out/"even_melee","할퀴기 ↔ 할퀴기     40 · 40"), (out/"strong_melee","베어가르기 ↔ 할퀴기     70 · 40")])
compare("fragments.gif", [(root/"hitstop/weak_recipient","기존 파편"), (out/"weak_recipient","새 파편")])
