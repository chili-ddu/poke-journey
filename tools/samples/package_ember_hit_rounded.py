from pathlib import Path
import json
from PIL import Image,ImageDraw
from package_ember_hit_variants import gif
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/ember_hit_rounded'

def main():
    old=ROOT/'docs/ember_hit_variants/native/72/wrap'
    new=OUT/'native/72/wrap'
    images=[[Image.open(folder/f'{k:03}.png').convert('RGB') for k in range(54)] for folder in [old,new]]
    rows=json.loads((OUT/'native/checks.json').read_text())
    baseline=json.loads((ROOT/'docs/ember_hit_variants/native/checks.json').read_text())
    fresh=[r for r in rows if r['variant']=='wrap']
    assert len(fresh)==2
    for r in fresh:
        prev=next(v for v in baseline if v['distance']==r['distance'] and v['variant']=='wrap')
        assert (r['damage'],r['hit_frame'])==(prev['damage'],prev['hit_frame'])
    hit=next(r['hit_frame'] for r in fresh if r['distance']==72)
    timing=[30 if k%3<2 else 40 for k in range(54)]
    # Native size above the enlarged detail, both at exactly the same speed.
    frames=[]
    for k in range(hit-3,min(54,hit+27)):
        b=Image.new('RGB',(540,404),(28,33,30));d=ImageDraw.Draw(b)
        for col,label in enumerate(['PREVIOUS / POINTED','NEW / ROLLING']):
            d.text((col*270+9,8),label,fill=(238,233,218))
            small=images[col][k].crop((246,68,336,158))
            b.paste(small,(col*270+90,28))
            b.paste(small.resize((270,270),Image.Resampling.NEAREST),(col*270,134))
        frames.append(b)
    gif(OUT/'pointed-vs-rolling.gif',frames,[timing[k] for k in range(hit-3,min(54,hit+27))])
    contact=Image.new('RGB',(576,218*4),(28,33,30));d=ImageDraw.Draw(contact)
    for row,delta in enumerate([2,6,11,18]):
        for col in range(2):
            d.text((col*288+8,row*218+6),['PREVIOUS','NEW'][col]+f' +{delta}f',fill=(238,233,218))
            im=images[col][hit+delta].crop((240,64,336,128)).resize((288,192),Image.Resampling.NEAREST)
            contact.paste(im,(col*288,row*218+26))
    contact.save(OUT/'contact.png')
    (OUT/'README.md').write_text('''# Rounded Ember hit sample — not integrated

The prior wrap used tapered flameTongue triangles. This revision replaces
those tongues with overlapping, offset round lobes using pixelfx solid and
noiseFor helpers (MIT, Hugo Duprez / Sprite Fusion fire). Palette, original
projectile, attack pose, hit pose, damage, and original tint/shake are retained.
No new character art, image generation, video generation, glow or impact star.

Actual pixelfx render / visual inspection: round6 clustered lobes; round7
faster rising/curling secondary lobes; round8 smaller pale cores and smaller
secondary lobe. Front/back final sheets are 64x64, 27 frames, 30fps, .85s.
Actual tools/check.mjs: 2 pass, 0 fail, 0 warnings. Output in check.txt.

Actual native Godot captures via run_visual_test.py, startup 384x216,
CaptureWindow.park, BOT, private save. Two fresh rounded scenarios, 48/72px.
At 48px hit frame14; at72px frame19; damage2 on natural level25 Chansey
(max HP165), matching previous. Body plane/depth and expiry assertions held.
checks.json also retains four historical baseline rows for comparison;
only wrap rows are fresh this run. Original native captures stay untouched.
Native script draws custom front/back layers in the actor plane, follows its
visible alpha centroid and hides only old cosmetic coat/ground flame sprites.
The fixed enemy and rightward hit remain sample limitations.

pointed-vs-rolling.gif uses actual gameplay captures, original speed with
30/30/40ms intervals; top crop native1x, bottom3x nearest, one shared GIF
palette. No effect added during packaging. Samples only, no production link.
''')
    print('Packaged rounded sample: two fresh native captures; matching hit frame and damage')

if __name__=='__main__':main()
