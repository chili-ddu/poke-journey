"""Isolated nearest-4x source copy with a restrained body shade-ramp edit."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/charmander_resolution_sample/source/idle-0.png'
OUT = ROOT / 'docs/charmander_4x_shading'
RAMP = {
    (248,160,96): (250,164,101),
    (217,104,53): (216,107,58),
    (147,67,56): (146,71,59),
}


def main():
    OUT.mkdir(exist_ok=True)
    source_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    source = Image.open(SOURCE).convert('RGBA')
    source.save(OUT/'source-copy-32x40.png')
    expanded = source.resize((128,160), Image.Resampling.NEAREST)
    expanded.save(OUT/'original-nearest-4x.png')
    shaded_source = source.copy()
    changes = []
    # Exclude the whole eye region and the complete tail/flame side.
    eye = (15,10,20,15)
    for y in range(source.height):
        for x in range(source.width):
            c = source.getpixel((x,y))
            if x < 12 or eye[0] <= x < eye[2] and eye[1] <= y < eye[3]:
                continue
            if c[3] == 255 and c[:3] in RAMP:
                after = (*RAMP[c[:3]],c[3])
                shaded_source.putpixel((x,y),after)
                changes.append(dict(x=x,y=y,before=c,after=after))
    shaded = shaded_source.resize((128,160),Image.Resampling.NEAREST)
    shaded.save(OUT/'shading-subtle-4x.png')
    assert shaded.getchannel('A').tobytes() == expanded.getchannel('A').tobytes()
    for y in range(40):
        for x in range(32):
            block = shaded.crop((x*4,y*4,x*4+4,y*4+4))
            assert len(set(block.get_flattened_data())) == 1
    assert hashlib.sha256(SOURCE.read_bytes()).hexdigest() == source_hash
    board=Image.new('RGB',(384,232),(46,56,51))
    draw=ImageDraw.Draw(board)
    for i,(label,im) in enumerate([('ORIGINAL / NEAREST 4x',expanded),('SUBTLE BODY SHADING',shaded)]):
        draw.text((i*192+9,12),label,fill=(238,233,218))
        board.paste(im,(i*192+32,38),im)
    draw.text((10,213),'128x160 each / no edge filter / preview only',fill=(200,207,199))
    board.save(OUT/'comparison.png')
    (OUT/'edits.json').write_text(json.dumps(dict(
        art_source='existing',route='nearest 4x copy + explicit shade-ramp adjustment; no image model',
        source_sha256=source_hash,source_canvas=[32,40],target_canvas=[128,160],
        changed_source_pixels=len(changes),changed_output_pixels=len(changes)*16,
        alpha_changes=0,source_unchanged=True,production_changes=False,
        patches=changes),indent=2))
    (OUT/'README.md').write_text('''# Original 4× copy, subtle shading — preview only

The original input is the project's existing polished Charmander Idle key 0,
facing row 2 (the same source used in previous comparisons). This is not the
raw pre-palette PMD sheet or the filtered/retouched sample.

32×40 → 128×160 with nearest sampling only. Every source pixel remains a
uniform 4×4 block. No edge filter, new geometry or subpixel details. Only
three existing body shade colors are slightly adjusted; eye region, outline,
tail/flame side and transparency are excluded. Exact coordinates/colors are
in edits.json. No actual lighting, glow or postprocessing is added.

comparison.png displays both PNGs at their actual 128×160 dimensions,
alpha-composited on the same background. This is a source-art comparison,
not an in-game screenshot. No production files or original assets changed.
''')
    print(f'128x160; {len(changes)} source pixels recolored; alpha/4x blocks/source hash verified')


if __name__ == '__main__':
    main()
