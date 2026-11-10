"""Record the live renderer at native size and package three synchronized clash examples."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "docs/projectile_clash/runtime/combat.gif"
PANELS = [
    ("ranged", "불꽃세례 · 물대포", 235),
    ("tie", "할퀴기 · 할퀴기", 205),
    ("residual", "베어가르기 · 할퀴기", 231),
]


def package(folder):
    report = json.loads((folder / "results.json").read_text())
    font = ImageFont.truetype(str(ROOT / "assets/fonts/Galmuri11.ttf"), 16)
    frames = []
    for age in range(-9, 23):
        frame = Image.new("RGB", (3 * 332 + 4, 152), "#26332e")
        draw = ImageDraw.Draw(frame)
        for index, (case, label, center) in enumerate(PANELS):
            number = max(0, min(43, report[case]["contact"] + age))
            with Image.open(folder / case / f"{number:02}.png") as raw:
                assert raw.size == (384, 216)
                crop = raw.crop((center - 83, 73, center + 83, 135))
                x = index * 334
                frame.paste(crop.resize((332, 124), Image.Resampling.NEAREST), (x, 28))
                draw.text((x + 8, 4), label, font=font, fill="#f5ebd6")
        frames.append(frame)
    sheet = Image.new("RGB", (frames[0].width, len(frames) * frames[0].height))
    for index, frame in enumerate(frames):
        sheet.paste(frame, (0, index * frame.height))
    palette = sheet.quantize(256)
    sequence = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
    durations = [10 * (round((i + 1) * 100/30) - round(i * 100/30)) for i in range(len(frames))]
    durations[-1] += 450
    DEST.parent.mkdir(parents=True, exist_ok=True)
    sequence[0].save(DEST, save_all=True, append_images=sequence[1:], duration=durations, loop=0, disposal=1)
    print(DEST)


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as tmp:
        subprocess.run([sys.executable, "tools/run_visual_test.py", "tools/battle_clash_runtime_review.gd"],
                       cwd=ROOT, env=dict(os.environ, CLASH_CAPTURE_DIR=tmp), check=True)
        package(Path(tmp))
