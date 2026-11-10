"""Encode actual native self-Cut captures without changing animation timing."""
import json
import argparse
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "docs/direct_field_hms/self_cut_preview"
CROP = (112, 20, 272, 164)
SCALE = 2
LABEL_HEIGHT = 40
GAP = 8


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUT)
    args = parser.parse_args()
    output = args.output
    report = json.loads((output / "capture.json").read_text())
    duration_ms = round(report['captures'][0]['duration_seconds'] * 1000)
    font = ImageFont.truetype(str(ROOT / "assets/fonts/Galmuri11.ttf"), 16)
    clips = []
    names = {"charmander": "파이리", "bulbasaur": "이상해씨"}
    for capture in report["captures"]:
        source = Path(capture["frames_dir"])
        frames = []
        for i in range(capture["frames"]):
            with Image.open(source / f"{i:03}.png") as image:
                crop = image.convert("RGB").crop(CROP)
            crop = crop.resize((crop.width * SCALE, crop.height * SCALE), Image.Resampling.NEAREST)
            frame = Image.new("RGB", (crop.width, crop.height + LABEL_HEIGHT), "#172427")
            frame.paste(crop, (0, LABEL_HEIGHT))
            label = Image.new("RGB", (crop.width // SCALE, LABEL_HEIGHT // SCALE), "#172427")
            ImageDraw.Draw(label).text((6, 1), names[capture["species"]], font=font, fill="#f0f5e7")
            frame.paste(label.resize((crop.width, LABEL_HEIGHT), Image.Resampling.NEAREST), (0, 0))
            frames.append(frame)
        clips.append(frames)
    combined = []
    for pair in zip(*clips):
        frame = Image.new("RGB", (pair[0].width * 2 + GAP, pair[0].height), "#172427")
        frame.paste(pair[0], (0, 0))
        frame.paste(pair[1], (pair[0].width + GAP, 0))
        combined.append(frame)
    sample = Image.new("RGB", (combined[0].width * 10, combined[0].height))
    impact = max(0, int(report["captures"][0]["impact_seconds"] * 50))
    indices = [0, 25, 30, 35, max(0, impact - 2), impact, impact + 3, impact + 8, 100, 150]
    for i, index in enumerate(indices):
        sample.paste(combined[min(index, len(combined) - 1)], (combined[0].width * i, 0))
    palette = sample.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    for name, frames in [(c["species"], f) for c, f in zip(report["captures"], clips)] + [("comparison", combined)]:
        encoded = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
        path = output / f"{name}.gif"
        encoded[0].save(path, save_all=True, append_images=encoded[1:], duration=20, loop=0, disposal=2, optimize=False)
        with Image.open(path) as gif:
            duration = sum(gif.seek(i) or gif.info["duration"] for i in range(gif.n_frames))
            assert duration == duration_ms, (name, duration)
        print(f"{name}.gif: {duration_ms / 1000:.1f} seconds, actual game speed, 2x nearest-neighbor crop")
    contact = Image.new("RGB", (combined[0].width, combined[0].height * 5))
    for row, i in enumerate([25, max(25, impact - 3), impact, impact + 4, min(199, impact + 15)]):
        contact.paste(combined[i], (0, row * combined[0].height))
    contact.save(output / "contact.png")
    report["preview"] = {"speed": 1.0, "duration_ms": duration_ms, "gif_frame_ms": 20,
                         "crop": list(CROP), "display_scale": SCALE, "filter": "nearest",
                         "palette": "shared 256 colors, no dithering", "runtime_modified": False}
    (output / "preview.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
