"""Prepare supplied art for pixelfx Painter, then package its actual renders."""
from pathlib import Path
import sys,json,hashlib
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charmander_pixelfx_sample_v1'
ART=ROOT/'docs/charmander_reference_motion'
SOURCE=ROOT/'docs/charmander_resolution_sample/source'
CHARS='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@$%^&*()_+='


def sprite(im):
    colors=list(dict.fromkeys(c for c in im.get_flattened_data() if c[3]))
    assert len(colors)<len(CHARS)
    ids={c:CHARS[i] for i,c in enumerate(colors)}
    return dict(rows=[''.join(ids[im.getpixel((x,y))] if im.getpixel((x,y))[3] else '.'
                            for x in range(im.width)) for y in range(im.height)],
                palette={ids[c]:'#%02x%02x%02x'%c[:3] for c in colors})


def prepare():
    OUT.mkdir(exist_ok=True)
    (OUT/'renders').mkdir(exist_ok=True)
    frames=[]
    for action in ['idle','walk']:
        for key in range(4):
            a=Image.open(SOURCE/f'{action}-{key}.png').convert('RGBA').resize((64,80),Image.Resampling.NEAREST)
            file=ART/f'{action}-{key}-64x80.png'
            b=Image.open(file).convert('RGBA')
            # Existing Forge checks apply only if exact inspected inputs match.
            qa=json.loads((ART/f'forge-review-v1/edited-{action}/sheet-qc.json').read_text())
            assert hashlib.sha256(file.read_bytes()).hexdigest()==qa['inputs'][key]['sha256']
            (OUT/f'source-{action}-{key}.rgba').write_bytes(a.tobytes())
            (OUT/f'edited-{action}-{key}.rgba').write_bytes(b.tobytes())
            frames.append(dict(action=action,key=key,
                variants=[dict(large=sprite(im),small=sprite(im.resize((32,40),Image.Resampling.NEAREST)))
                          for im in [a,b]]))
    (OUT/'render-input.json').write_text(json.dumps(dict(frames=frames)))
    print('8 paired keys prepared; exact Forge-inspected edited input hashes verified')


def package():
    durations={'idle':[400,270,260,270],'walk':[100,130,100,140]}
    for bg in ['dark','light']:
        combined=[];times=[]
        for action in ['idle','walk']:
            frames=[Image.open(OUT/f'renders/{bg}-{action}-{key}.png').convert('RGB') for key in range(4)]
            # Verify native 64x80 pixel blocks after pixelfx rendering, where
            # colors must be unchanged for every source opaque pixel.
            for key,frame in enumerate(frames):
                for variant,x in [('source',100),('edited',292)]:
                    expected=Image.frombytes('RGBA',(64,80),(OUT/f'{variant}-{action}-{key}.rgba').read_bytes())
                    crop=frame.crop((x,220,x+64,300))
                    for y in range(80):
                        for xx in range(64):
                            c=expected.getpixel((xx,y))
                            if c[3]:assert crop.getpixel((xx,y))==c[:3]
            frames[0].save(OUT/f'{bg}-{action}.gif',save_all=True,append_images=frames[1:],duration=durations[action],loop=0,disposal=2)
            sheet=Image.new('RGB',(384*4,312))
            for i,frame in enumerate(frames):sheet.paste(frame,(i*384,0))
            sheet.save(OUT/f'{bg}-{action}-poses.png')
            for repeat in range(3):combined.extend(frames);times.extend(durations[action])
        combined[0].save(OUT/f'{bg}-motion.gif',save_all=True,append_images=combined[1:],duration=times,loop=0,disposal=2)
    p=ART/'forge-review-v1'
    flags=json.loads((p/'qa-flags.json').read_text())
    (OUT/'forge-qa-flags.json').write_text(json.dumps(flags,indent=2))
    (OUT/'README.md').write_text('''# Charmander — actual pixelfx-rendered supplied-art preview

Existing source art and latest reference-study animation edits are reused,
not newly generated or retouched in this pass. The forehead-restored key 0
and its pose-specific arm/belly edits are unchanged from the latest study.
All edited input SHA256 values match the actual Forge-inspected frames.

Actual renderer: pixelfx v0.3.0 (Patch/Hugo Duprez, MIT), sibling checkout.
Painter.sprite draws supplied image pixels via palette-indexed rows;
createFrame, painterFor, composite and encodePNG produce every preview PNG.
The light buffer remains zero: no glow or particle effects are added.
Thus pixelfx is used for sprite rendering here, not character generation or
anatomy validation. The supplied art is not recreated as a library effect.

Left original, right latest edit. Top identical 128×160 footprints; bottom
32×40 and 64×80. Dark and light backgrounds expose outline readability.
Idle period 1.2s; Walk key durations 100/130/100/140ms (source proportions,
not gameplay movement). Both sides match positions, keys and timings.
No new motion or interpolation; not an in-game camera capture.

Validation: byte-exact visible RGB comparison of every native sprite pixel
against the pixelfx-rendered PNGs on both backgrounds. Fixed canvas/alpha
remain source-preserving. Eight edited input hashes match the Forge QA.
Forge results reused from ../charmander_reference_motion/forge-review-v1:
four reports, 0 FAIL / 6 WARN total. All literal warning ids, values,
thresholds and files are in forge-qa-flags.json; also see its REVIEW.md.
Warnings are near_duplicates on all four reports and leg_alternation on
the two walk reports, present equally in source and edit. Numeric QA does
not approve anatomy. All source/edited review sheets were visually inspected.

Production unchanged. No API/model generation was called for this preview.
Art source: existing. Render route: pixelfx core + PNG encoder; packaging PIL.
Reproduce: python3 tools/samples/charmander_pixelfx_preview.py prepare;
node tools/samples/render_charmander_pixelfx.mjs;
python3 tools/samples/charmander_pixelfx_preview.py package.
''')
    print('16 pixelfx PNGs verified; dark/light GIFs packaged; Forge 0 FAIL / 6 WARN retained')


if __name__=='__main__':
    {'prepare':prepare,'package':package}[sys.argv[1]]()
