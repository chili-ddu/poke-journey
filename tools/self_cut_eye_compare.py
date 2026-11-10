"""Compare current and eye-glint samples at equal speed and native pixel size."""
import json
import argparse
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
from self_cut_preview import ROOT, CROP

OUT = ROOT / 'docs/direct_field_hms/self_cut_eye_sample'


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, default=OUT)
    parser.add_argument('--before', type=Path, default=OUT.parent / 'self_cut_preview')
    args = parser.parse_args()
    output = args.output
    before = json.loads((args.before / 'capture.json').read_text())
    after = json.loads((output / 'capture.json').read_text())
    font = ImageFont.truetype(str(ROOT / 'assets/fonts/Galmuri11.ttf'), 16)
    labels = ['기존 파이리', '기존 이상해씨', '눈빛 파이리', '눈빛 이상해씨']
    captures = before['captures'] + after['captures']
    frames = []
    for i in range(after['captures'][0]['frames']):
        frame = Image.new('RGB', (324, 336), '#172427')
        for slot, capture in enumerate(captures):
            at = (slot % 2 * 164, slot // 2 * 168)
            path = Path(capture['frames_dir']) / f"{min(i, capture['frames'] - 1):03d}.png"
            with Image.open(path) as raw:
                crop = raw.convert('RGB').crop(CROP)
            frame.paste(crop, (at[0], at[1] + 24))
            ImageDraw.Draw(frame).text((at[0] + 3, at[1] + 1), labels[slot], font=font, fill='#f0f5e7')
        frames.append(frame)
    sample = Image.new('RGB', (324 * 6, 336))
    for slot, i in enumerate([0, 30, 33, 38, 55, 62]):
        sample.paste(frames[i], (324 * slot, 0))
    palette = sample.quantize(colors=256, method=Image.Quantize.MEDIANCUT)
    encoded = [f.quantize(palette=palette, dither=Image.Dither.NONE) for f in frames]
    encoded[0].save(output / 'before-after-native.gif', save_all=True, append_images=encoded[1:],
                    duration=20, loop=0, disposal=2, optimize=False)
    with Image.open(output / 'before-after-native.gif') as gif:
        assert sum(gif.seek(i) or gif.info['duration'] for i in range(gif.n_frames)) == 4400
    contact = Image.new('RGB', (648, 336 * 3))
    for slot, i in enumerate([27, 30, 33, 38, 55, 62]):
        contact.paste(frames[i], (slot % 2 * 324, slot // 2 * 336))
    contact.save(output / 'eye-timing-contact.png')
    hold = max(0.0, after['captures'][0]['duration_seconds'] - before['captures'][0]['duration_seconds'])
    print(f'Equal-speed before/after GIF: 324x336, 4.4s. Earlier clip final hold: {hold:.1f}s.')


if __name__ == '__main__':
    main()
