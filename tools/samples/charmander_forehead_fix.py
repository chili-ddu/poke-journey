"""Restore two partial outline blocks in the separate reference study."""
from pathlib import Path
import json
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charmander_reference_study'


def main():
    original=Image.open(OUT/'original-nearest-2x.png').convert('RGBA')
    previous=Image.open(OUT/'reference-study-64x80.png').convert('RGBA')
    fixed=previous.copy()
    coords=[(40,18),(41,19)]
    for xy in coords:fixed.putpixel(xy,original.getpixel(xy))
    assert fixed.crop((0,0,64,30)).tobytes()==original.crop((0,0,64,30)).tobytes()
    assert fixed.crop((0,30,64,80)).tobytes()==previous.crop((0,30,64,80)).tobytes()
    assert fixed.getchannel('A').tobytes()==previous.getchannel('A').tobytes()
    fixed.save(OUT/'reference-study-v2-64x80.png')
    board=Image.new('RGB',(512,440),(46,56,51));d=ImageDraw.Draw(board)
    for i,(label,im) in enumerate([('PREVIOUS STUDY',previous),('FOREHEAD RESTORED',fixed)]):
        d.text((i*256+8,12),label,fill=(238,233,218))
        large=im.resize((256,320),Image.Resampling.NEAREST)
        board.paste(large,(i*256,38),large)
        board.paste(im,(i*256+140,356),im)
        tiny=im.resize((32,40),Image.Resampling.NEAREST)
        board.paste(tiny,(i*256+50,392),tiny)
    board.save(OUT/'forehead-fix-comparison.png')
    (OUT/'forehead-fix.json').write_text(json.dumps(dict(
        restored_pixels=coords,reason='partial removal of two 2x2 dark outline blocks left detached dark pixels',
        upper_head_matches_original=True,other_edits_unchanged=True,
        production_changes=False),indent=2))
    with (OUT/'README.md').open('a') as f:f.write('\n## Forehead fix v2\nTwo edited pixels at (40,18), (41,19) partially recolored existing 2×2 dark forehead blocks, leaving conspicuous dark pixels. Restored both to source; the entire upper head (y<30) now equals nearest-scaled original. Arm/belly/lower-cheek edits remain. Files: reference-study-v2-64x80.png and forehead-fix-comparison.png. Prior draft preserved. Preview only.\n')
    print('Two pixels restored; upper head equals original; all other edits unchanged.')


if __name__=='__main__':main()
