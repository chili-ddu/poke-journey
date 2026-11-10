"""Intentional pixel edits of one supplied pose, with official art reference."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charmander_reference_study'
SOURCE=ROOT/'docs/charmander_resolution_sample/source/idle-0.png'


def main():
    source=Image.open(SOURCE).convert('RGBA')
    original=source.resize((64,80),Image.Resampling.NEAREST)
    result=original.copy()
    light=(248,160,96,255);mid=(217,104,53,255);dark=(147,67,56,255)
    cream=(239,215,168,255);cream_shadow=(207,178,133,255);cream_deep=(173,139,100,255)
    edits=[]

    def pixel(x,y,color,reason):
        old=result.getpixel((x,y))
        assert old[3]==255
        if old==color:return
        result.putpixel((x,y),color)
        edits.append(dict(x=x,y=y,before=old,after=color,reason=reason))

    def row(y,x0,x1,color,reason):
        for x in range(x0,x1+1):pixel(x,y,color,reason)

    # Keep one broad elbow crease; round the colored flesh side rather than
    # producing individual holes in the dark patch with a generic filter.
    for x,y in [(27,34),(26,35)]:pixel(x,y,mid,'round shoulder shade entry')
    row(36,28,29,light,'continuous rounded upper arm face')
    row(37,28,29,light,'continuous rounded upper arm face')
    row(38,28,29,mid,'elbow transition above uninterrupted crease')
    pixel(29,39,mid,'one half-pixel elbow curve')
    row(40,30,31,dark,'retain connected underside of elbow')
    # Official reference: pale belly material. Preserve its original narrow
    # side-facing footprint; adjust interior ramps, not the body's anatomy.
    for y in range(34,39):row(y,34,35,cream,'belly material, light plane')
    row(39,33,35,cream,'belly material, light plane')
    row(40,32,34,cream_shadow,'belly turning away from light')
    pixel(35,40,cream_deep,'belly edge shadow')
    row(41,32,33,cream_shadow,'belly lower turn')
    pixel(34,41,cream_deep,'belly lower turn')
    row(42,32,33,cream_deep,'belly lower edge')
    # Individually chosen half-source-pixel transitions on cheek/forehead.
    for x,y,c in [(30,16,light),(37,16,light),(40,18,mid),(41,19,mid),
                  (36,30,light),(39,31,light),(40,31,mid)]:
        pixel(x,y,c,'rounded head plane transition')
    assert result.getchannel('A').tobytes()==original.getchannel('A').tobytes()
    assert result.crop((28,20,40,30)).tobytes()==original.crop((28,20,40,30)).tobytes()
    assert result.crop((0,0,24,80)).tobytes()==original.crop((0,0,24,80)).tobytes()
    # Keep raw copies for review; no atlas or runtime references these files.
    source.save(OUT/'source-copy-32x40.png')
    original.save(OUT/'original-nearest-2x.png')
    result.save(OUT/'reference-study-64x80.png')
    board=Image.new('RGB',(512,440),(46,56,51));d=ImageDraw.Draw(board)
    for i,(name,im) in enumerate([('ORIGINAL / NEAREST 2x',original),('REFERENCE-GUIDED EDIT',result)]):
        d.text((i*256+8,12),name,fill=(238,233,218))
        big=im.resize((256,320),Image.Resampling.NEAREST)
        board.paste(big,(i*256,38),big)
        board.paste(im,(i*256+140,356),im)
        tiny=im.resize((32,40),Image.Resampling.NEAREST)
        board.paste(tiny,(i*256+50,392),tiny)
    board.save(OUT/'comparison.png')
    blink=[]
    for im in [original,result]:
        canvas=Image.new('RGB',(256,320),(46,56,51))
        big=im.resize((256,320),Image.Resampling.NEAREST)
        canvas.paste(big,(0,0),big);blink.append(canvas)
    blink[0].save(OUT/'edit-toggle.gif',save_all=True,append_images=blink[1:],duration=900,loop=0)
    counts=sum(a!=b for a,b in zip(original.get_flattened_data(),result.get_flattened_data()))
    (OUT/'edits.json').write_text(json.dumps(dict(art_source='existing',
        route='copied original + intentional pixel edits; no image model',
        source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
        official_reference='https://sg.portal-pokemon.com/pokedex/0004/',
        production_changes=False,canvas=[64,80],changed_pixels=counts,
        new_colors=3,alpha_changes=0,eye_unchanged=True,tail_unchanged=True,
        edits=edits),indent=2))
    (OUT/'README.md').write_text('''# Reference-guided one-pose study — not applied

Reference: official Charmander Pokédex art, https://sg.portal-pokemon.com/pokedex/0004/.
official-reference.png is downloaded reference material only, not a game asset.
Source: same existing polished right-facing Idle key 0 used in prior previews.
Nearest 2× 32×40 → 64×80, then intentionally selected pixel edits, no image model.

Design decisions: preserve original gesture, eye, tail, canvas, alpha and
outer silhouette; keep a continuous arm crease instead of applying the earlier
generic corner filter; round the flesh-side transition. Introduce three restrained
cream tones for the existing narrow side-facing belly, based on the official
character's material. Round a few head shading transitions. This is a study
of arm/cheek/torso planes, not a claim of pixel-identical color preservation.

comparison.png uses equal 256×320 enlarged footprints; below are 32×40 and
64×80 direct previews. edit-toggle.gif is one still alternating original/edit,
NOT a character animation. No animation or game-camera approval is claimed.
Only this pose has been edited. Other poses need separately chosen anatomical
edits and temporal review before any integration. All game files unchanged.
Alpha, eye and tail protected regions verified byte-identical; detailed colors,
coordinates and source hash in edits.json.
''')
    print(f'One pose: {counts} pixels changed; 3 new restrained belly shades; eye/tail/alpha unchanged')


if __name__=='__main__':main()
