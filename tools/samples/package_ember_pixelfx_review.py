"""Paired real native captures, at unchanged simulation speed."""
from pathlib import Path
from PIL import Image,ImageDraw
import json

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/ember_pixelfx_review'


def main():
    results=json.loads((OUT/'native/checks.json').read_text())
    for distance in [48,72]:
        pair=[r for r in results if r['distance']==distance]
        assert len(pair)==2 and len({r['damage'] for r in pair})==1
        full=[];close=[]
        for k in range(54):
            board=Image.new('RGB',(768,242),(28,33,30));d=ImageDraw.Draw(board)
            cropboard=Image.new('RGB',(704,218),(28,33,30));dc=ImageDraw.Draw(cropboard)
            for col,(variant,label) in enumerate([('current','CURRENT'),('pixelfx','PIXELFX STUDY')]):
                im=Image.open(OUT/f'native/{distance}/{variant}/{k:03}.png').convert('RGB')
                assert im.size==(384,216)
                d.text((col*384+10,8),label,fill=(238,233,218));board.paste(im,(col*384,26))
                dc.text((col*352+10,8),label,fill=(238,233,218))
                crop=im.crop((160,64,336,160)).resize((352,192),Image.Resampling.NEAREST)
                cropboard.paste(crop,(col*352,26))
            full.append(board);close.append(cropboard)
        durations=[30 if k%3<2 else 40 for k in range(54)]
        full[0].save(OUT/f'{distance}-full-comparison.gif',save_all=True,append_images=full[1:],duration=durations,loop=0,disposal=2)
        close[0].save(OUT/f'{distance}-comparison.gif',save_all=True,append_images=close[1:],duration=durations,loop=0,disposal=2)
        sheet=Image.new('RGB',(704,218*4))
        for row,k in enumerate([7,10,18,26]):sheet.paste(close[k],(0,row*218))
        sheet.save(OUT/f'{distance}-contact.png')
    (OUT/'README.md').write_text('''# Ember pixelfx study — separate native preview, not applied

Art source code: new generic fire FX authored with pixelfx flameBlade /
flameTongue helpers (pixelfx v0.3.0, Patch / Hugo Duprez, MIT; Sprite Fusion
fire techniques credited in tools/samples/ember_pixelfx_studies.mjs).
No AI image/video generation, no character sprite or pose changes.

Library references rendered/inspected first: fire/fire-breath, fire/fireball,
status/burning. Stock effects were too large/bright for this game's scale.
Round 1 three drafts: A compact comet, B short directed jet, C split licks;
flight and coat shapes rendered and inspected. Choose B. Round 2 merged
parallel bright rails into one core with cooler curling edges, avoiding a
laser appearance. Round 3 reduced cream core and quantized flicker at 20Hz.
Three actual render/look rounds and real tools/check.mjs on both final FX.
Final assets are 32×32 cells, 36 frames, 30fps, 1.2s deterministic loops.
Checker: 2 pass / 0 FAIL / 0 WARN; exact log in pixelfx-check.txt.
No physical impact star, spark spray or additive glow buffer in new assets.

Native Godot HD-2D preview at 384×216 from startup, CaptureWindow.park,
isolated SaveData path, BOT=1, fixed seed. Controller input triggers the
actual cast plus original attack pose. Same natural-stat level-25 Chansey,
frozen movement and disabled skill cooldowns. 48px and 72px scenarios;
original and preview both damage 2, HP 163/165. No stat/damage overrides.
Effect depth tests and original front/back target-follow positions preserved.
No changes to production code, skill physics, actor poses, saves or rendering
settings. Only the review script replaces visible textures/materials after
the production View3D sync. Native review exposed an overly thin horizontal
mask, so the preview doubles flight display thickness and scales coat/ground
art by 1.25/1.10 respectively; collision radii and positions stay original.
Both distances were rerun after this visual-only adjustment and damage still
matches. Existing muzzle flash, lights and feedback remain.
Thus this trial changes flight/coating/ground flame artwork, not the entire
skill choreography or continuous beam mechanics. Early art direction study.

Native captures in native/. 48/72-comparison.gif: fixed battle crop, exact
nearest 2× enlargement of captured screen pixels, not source-art enlargement.
Full-comparison.gif: two native 384×216 views with labels. Captured at 30fps;
GIF 30/30/40ms timing maintains 1.8s per loop. No slowed animation, GIF-only
overlays or static pose substitutions. All art-frame contact sheets and
four-state native comparisons inspected. results in native/checks.json.
Flat renderer is not previewed; this is specifically native HD-2D.

Reproduce: setup_ember_pixelfx_studies.py, pixelfx render/check, then
python3 tools/run_visual_test.py tools/ember_pixelfx_native_review.gd and
package_ember_pixelfx_review.py. Temporary review wrappers in the sibling
library are removed after checking; source adapter remains in this project.
''')
    print('Native paired GIFs packaged; both distances damage-match; 384×216 source captures retained')


if __name__=='__main__':main()
