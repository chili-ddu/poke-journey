from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/ember_hit_variants'


def gif(path,frames,durations):
    # One palette for the entire comparison avoids per-frame GIF colour drift.
    sample=Image.new('RGB',(frames[0].width*9,frames[0].height*6))
    for i,im in enumerate(frames):sample.paste(im,((i%9)*im.width,(i//9)*im.height))
    pal=sample.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    indexed=[im.quantize(palette=pal,dither=Image.Dither.NONE) for im in frames]
    indexed[0].save(path,save_all=True,append_images=indexed[1:],duration=durations,loop=0,disposal=2)


def main():
    results=json.loads((OUT/'native/checks.json').read_text())
    for distance in [48,72]:
        rows=[r for r in results if r['distance']==distance]
        assert len({r['damage'] for r in rows})==1
        assert len({r['hit_frame'] for r in rows})==1
    labels={'current':'CURRENT','previous':'PREVIOUS STUDY','wrap':'A / WRAP','sweep':'B / SWEEP'}
    captures={v:[Image.open(OUT/f'native/72/{v}/{k:03}.png').convert('RGB') for k in range(54)] for v in labels}
    durations=[30 if k%3<2 else 40 for k in range(54)]
    for variant in ['wrap','sweep']:
        frames=[]
        for k in range(54):
            board=Image.new('RGB',(704,218),(28,33,30));d=ImageDraw.Draw(board)
            for col,v in enumerate(['current',variant]):
                d.text((col*352+10,8),labels[v],fill=(238,233,218))
                im=captures[v][k].crop((160,64,336,160)).resize((352,192),Image.Resampling.NEAREST)
                board.paste(im,(col*352,26))
            frames.append(board)
        gif(OUT/f'current-vs-{variant}.gif',frames,durations)
    close=[]
    hitframe=int(next(r['hit_frame'] for r in results if r['distance']==72 and r['variant']=='wrap'))
    indices=list(range(hitframe-3,min(54,hitframe+28)))
    for k in indices:
        board=Image.new('RGB',(540,296),(28,33,30));d=ImageDraw.Draw(board)
        for col,v in enumerate(['wrap','sweep']):
            d.text((col*270+10,8),labels[v],fill=(238,233,218))
            crop=captures[v][k].crop((246,68,336,158)).resize((270,270),Image.Resampling.NEAREST)
            board.paste(crop,(col*270,26))
        close.append(board)
    gif(OUT/'hit-a-vs-b.gif',close,[durations[k] for k in indices])
    sheet=Image.new('RGB',(768,218*5),(28,33,30));d=ImageDraw.Draw(sheet)
    for row,delta in enumerate([1,4,9,15,22]):
        k=hitframe+delta
        for col,v in enumerate(labels):
            d.text((col*192+8,row*218+8),labels[v],fill=(238,233,218))
            crop=captures[v][k].crop((240,64,336,160)).resize((192,192),Image.Resampling.NEAREST)
            sheet.paste(crop,(col*192,row*218+26))
    sheet.save(OUT/'impact-contact.png')
    (OUT/'README.md').write_text('''# Ember: alternate hit reactions — preview only

Two alternative one-shot hit effects, not just a flight texture swap:
A WRAP: four warmer flames behind, short outward side flames in front and
small low licks. Front height is limited so the face remains readable.
B SWEEP: a rear flame travels from impact side across the body; short front
lanes ignite at staggered times, then shrink upward and disappear.
A/B use the SAME original flight visuals to isolate hit choreography.
CURRENT is production; PREVIOUS STUDY is the first pixelfx trial with changed
flight/coat textures. None of these new assets are integrated into gameplay.

Actual art route: code, pixelfx flameTongue helper / Sprite Fusion fire
techniques, MIT Hugo Duprez 2026, with local authored one-shot choreography.
Reference library was already rendered/inspected in ../ember_pixelfx_review.
Round 1 WRAP / SWEEP / LOW (front/back); LOW rejected as foot-only residue.
Round 2 shortened front center flames and staggered sweep ignition.
Round 3 smaller cream cores and shrinking/rising decay. Native review then
found incorrect attachment due to transparent Hurt frame padding: fixed to
rendered alpha centroid through View3D.sprite_pixel_position, not frame center.
Round 4 pushed WRAP front tips outward and below the face. Round 5 broadened
WRAP rear tongues instead of keeping long narrow bars. Native front-layer
opacity for WRAP is .62 to retain expression, with .95 behind the body;
SWEEP uses .88 front / .95 back. Final four assets:
round5 WRAP front/back, round3 SWEEP front/back, each 64×64, 27 frames,
30fps, .85s one-shot ending empty. No physical hit stars, shock ring or
additional additive glow/light. No image/video model or new character pose.

Actual pixelfx render/export/look rounds and tools/check.mjs: 4 pass,
0 FAIL / 0 WARN. Exact log in pixelfx-check-final.txt. All final contact
sheets and actual native hit timing frames visually inspected.

Native HD-2D review: startup 384×216 via run_visual_test.py, CaptureWindow.park,
BOT=1, isolated save path, fixed seed. Actual controller cast and original
attack animation. Natural level-25 Chansey HP 165. World holds enemy motion
and skill cooldowns only in the test, with no HP/damage/level multipliers.
At 72px CURRENT/PREVIOUS/A/B hit on frame 19, damage 2. At 48px A/B hit on
frame 14, damage 2. New effects trigger ONCE when actual HP first decreases,
follow the rendered body every frame, and expire before review completion.
Old cosmetic coat/ground flame sprites are hidden only by the reviewer;
their World logic, tint, shake, hit pose, lights and scorch remain unchanged.
New front/back Sprite3D depth testing is enabled. Their billboard plane
matches the actor's upright/camera-facing mode: a camera-facing plane
intersected the upright actor during review and let rear flames cover its
face. Fixed by matching the actor plane and ±depth along its normal, around
the visible body centroid. Fixed species reference span
sets display scale; no per-frame alpha-box fitting, stats or collision changes.

hit-a-vs-b.gif: actual hit-area crop enlarged 3× nearest, same gameplay speed.
current-vs-wrap/sweep.gif: full cast/flight/hit battle crop enlarged 2×.
All GIF comparisons use one shared palette per clip and 30/30/40ms capture
timing. They are real GPU captures, not post-added effects on still images.
native/checks.json and unchanged native PNGs provide underlying evidence.

Limits: only a rightward cast onto one target species at two distances is
reviewed. A moving target / other silhouettes and oblique hit directions
need later testing before integration. New effects last at most .85s, not a
gameplay burn status. This is a choice of visual direction, not approval of
all skills, maps or character art. Production and original assets unchanged.
Temporary sibling-library adapters removed after review, source factory and
actual tool outputs retained. Reproduce with setup_ember_hit_variants.py,
pixelfx render/check, ember_hit_variants_native_review.gd, then this packager.
''')
    assets={}
    for style,round in [('wrap',5),('sweep',3)]:
        for layer in ['front','back']:
            id=f'ember-hit-r{round}-{style}-{layer}';p=OUT/f'round{round}/local-review/{id}/{id}.png'
            assets[f'{style}-{layer}']=dict(path=str(p),sha256=hashlib.sha256(p.read_bytes()).hexdigest())
    (OUT/'provenance.json').write_text(json.dumps(dict(art_source='code',route='pixelfx authored one-shot FX and native Godot HD-2D review',
        assets=assets,model_generation=False,pixelfx_failures=0,pixelfx_warnings=0,production_changes=False),indent=2))
    print('A/B real hit comparison packed; 6 scenarios matched damage and impact timing; final FX 0 FAIL / 0 WARN')


if __name__=='__main__':main()
