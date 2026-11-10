"""Preview-only edits of a copied existing pose; no model or game integration."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'docs/charmander_resolution_sample/source/idle-0.png'
OUT = ROOT / 'docs/charmander_copy_refinement'


def scale2x(im):
    w, h = im.size
    result = Image.new('RGBA', (w*2, h*2))
    for y in range(h):
        for x in range(w):
            e = im.getpixel((x,y))
            b = im.getpixel((x,max(0,y-1)))
            d = im.getpixel((max(0,x-1),y))
            f = im.getpixel((min(w-1,x+1),y))
            h0 = im.getpixel((x,min(h-1,y+1)))
            edge = b != h0 and d != f
            for dx,dy,c in [(0,0,d if edge and d==b else e),
                            (1,0,f if edge and b==f else e),
                            (0,1,d if edge and d==h0 else e),
                            (1,1,f if edge and h0==f else e)]:
                result.putpixel((x*2+dx,y*2+dy),c)
    return result


def main():
    OUT.mkdir(exist_ok=True)
    before_hash = hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    source = Image.open(SOURCE).convert('RGBA')
    source.save(OUT/'source-copy-32x40.png')
    base = scale2x(source)
    base.save(OUT/'edge-base-64x80.png')
    refined = base.copy()
    # Deliberate half-source-pixel edits to existing shade clusters only.
    # Eye (x32..37/y22..27), tail and flame are intentionally untouched.
    orange = (248,160,96,255)
    copper = (217,104,53,255)
    shadow = (147,67,56,255)
    cream = (228,190,115,255)
    patches = [
        (30,16,orange,'forehead shade step'),
        (37,16,orange,'forehead shade step'),
        (40,18,copper,'upper muzzle ink transition'),
        (41,19,copper,'upper muzzle ink transition'),
        (37,20,orange,'small brow shade cluster'),
        (36,21,orange,'small brow shade cluster'),
        (36,30,orange,'lower cheek shade step'),
        (38,31,orange,'lower cheek shade step'),
        (32,33,orange,'arm shade step'),
        (31,34,orange,'arm shade step'),
        (30,39,copper,'arm to body shade transition'),
        (31,40,copper,'arm to body shade transition'),
        (33,41,cream,'belly shade boundary'),
        (32,42,cream,'belly shade boundary'),
        (31,43,shadow,'belly to lower body boundary'),
        (30,47,orange,'lower body shade step'),
        (30,49,copper,'lower body shade step'),
    ]
    changes = []
    for x,y,color,reason in patches:
        old = refined.getpixel((x,y))
        assert old[3] == color[3] == 255
        assert old != color
        refined.putpixel((x,y),color)
        changes.append(dict(x=x,y=y,before=old,after=color,reason=reason))
    refined.save(OUT/'refined-64x80.png')
    assert refined.getchannel('A').tobytes() == base.getchannel('A').tobytes()
    palette = set(source.get_flattened_data())
    assert set(refined.get_flattened_data()).issubset(palette)
    assert before_hash == hashlib.sha256(SOURCE.read_bytes()).hexdigest()
    board = Image.new('RGB',(768,468),(46,56,51))
    draw = ImageDraw.Draw(board)
    for i,(label,im) in enumerate([('SOURCE / 32x40',source),
                                  ('EDGE BASE / 64x80',base),
                                  ('COPY EDIT / 64x80',refined)]):
        draw.text((i*256+10,12),label,fill=(238,233,218))
        # Same physical size: original 8x; 2x textures 4x.
        big = im.resize((256,320),Image.Resampling.NEAREST)
        board.paste(big,(i*256,42),big)
        small = im.resize((32,40),Image.Resampling.NEAREST)
        board.paste(small,(i*256+50,405),small)
        medium = im.resize((64,80),Image.Resampling.NEAREST)
        board.paste(medium,(i*256+128,378),medium)
    board.save(OUT/'comparison.png')
    frames = []
    for im in (base,refined):
        canvas=Image.new('RGB',(256,320),(46,56,51))
        big=im.resize((256,320),Image.Resampling.NEAREST)
        canvas.paste(big,(0,0),big)
        frames.append(canvas)
    frames[0].save(OUT/'edge-vs-copy.gif',save_all=True,append_images=frames[1:],duration=850,loop=0)
    report = dict(art_source='existing',route='copied source + deterministic Scale2x + explicit pixel edits; no image model',
                  source_sha256=before_hash,source_unchanged=True,production_changes=False,
                  source_canvas=[32,40],target_canvas=[64,80],
                  edited_pixels_vs_edge_base=len(changes),new_colors=0,
                  alpha_changes_vs_edge_base=0,patches=changes)
    (OUT/'edits.json').write_text(json.dumps(report,indent=2))
    (OUT/'README.md').write_text('''# Copied-pose pixel refinement — preview only

Existing polished Charmander Idle key 0, facing row 2, copied to this folder.
Source 32×40; preview 64×80. Scale2x base followed by 17 explicit pixel edits
to existing shade boundaries. No image generation or new palette colors.
Eye and tail/flame are unchanged relative to the edge base. Transparency is
identical to the edge base; the edge base itself changes silhouette corners.
Original source hash verified unchanged. Full edit coordinates in edits.json.

comparison.png: source, edge base, edited copy. Large images have the same
256×320 footprint, with nearest sampling (source 8×; 2× art 4×). Below are
32×40 and 64×80 display footprints, direct sprite previews, not in-game
camera captures. edge-vs-copy.gif alternates the two 2× variants.

One still only; changes are deliberately small. No animation/temporal QA and
no camera rendering claims. No production integration. Source contains
invisible RGB under fully transparent pixels; alpha compositing is retained.
''')
    print(json.dumps({k:v for k,v in report.items() if k!='patches'}))


if __name__ == '__main__':
    main()
