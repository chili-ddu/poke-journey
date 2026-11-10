"""Pair native 1x frames and encode the four early moves at simulation speed."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

root = Path(__file__).resolve().parents[2] / 'docs/charmander_target_review'
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument('--crowd', action='store_true')
crowd = parser.parse_args().crowd
if crowd:
    root = root / 'crowd'
moves = {'scratch':'할퀴기', 'growl':'울음소리', 'ember':'불꽃세례', 'smoke_screen':'연막'}
if crowd:
    moves = {key: moves[key] for key in ('scratch', 'ember')}
original = json.loads((root / 'headless.json').read_text())
native = json.loads((root / 'native.json').read_text())
assert original == native
expected = {'scratch': (2, 1), 'growl': (2, 2), 'ember': (1, 1), 'smoke_screen': (2, 1)}
font = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 12)
frames = []
for move, name in moves.items():
    for col, variant in enumerate(['existing', 'sample']):
        row = next(r for r in native if r['move'] == move and r['variant'] == variant)
        if crowd:
            assert row['damage_frames'] == ([1, 0, 0] if col == 0 else [1, 1, 0])
        else:
            assert sum(any(values) for values in row['victims']) == expected[move][col]
    for index in range(51):
        out = Image.new('RGB', (384, 216))
        draw = ImageDraw.Draw(out)
        for col, variant in enumerate(['existing', 'sample']):
            with Image.open(root / move / variant / f'{index:03}.png') as scene:
                assert scene.size == (384, 216)
                out.paste(scene.convert('RGB').crop((120, 0, 312, 216)), (192*col, 0))
            draw.rectangle((192*col, 0, 192*col+191, 19), fill='#232b29')
            label = '기존' if col == 0 else '수정안'
            if crowd:
                label = '이전 단일 판정' if col == 0 else '범위 내 다수'
            draw.text((192*col+6, 2), f'{name}  ·  {label}', font=font, fill='#f3ead8')
        draw.line((191, 0, 191, 215), fill='#616956')
        frames.append(out)
atlas = Image.new('RGB', (384*6, 216*((len(frames)+5)//6)))
for i, frame in enumerate(frames):
    atlas.paste(frame, (384*(i%6), 216*(i//6)))
palette = atlas.quantize(colors=256, dither=Image.Dither.NONE)
gif = [frame.quantize(palette=palette, dither=Image.Dither.NONE) for frame in frames]
gif[0].save(root/'early-moves.gif', save_all=True, append_images=gif[1:], loop=0,
            duration=[30,30,40]*(len(gif)//3), disposal=1, optimize=False)
with Image.open(root/'early-moves.gif') as animation:
    duration = 0
    for i in range(animation.n_frames):
        animation.seek(i)
        duration += animation.info['duration']
    assert duration == len(frames)*1000//30
