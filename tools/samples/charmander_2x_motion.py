"""Paired source-key animation previews; no runtime or source asset changes."""
from pathlib import Path
import hashlib
import json
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'docs/charmander_resolution_sample/source'
OUT=ROOT/'docs/charmander_2x_motion'
BODY={(248,160,96,255),(217,104,53,255),(147,67,56,255),
      (228,190,115,255),(173,129,74,255)}


def refine(im):
    result=im.resize((64,80),Image.Resampling.NEAREST)
    marks=[(x,y) for y in range(19) for x in range(12,25)
           if im.getpixel((x,y)) in [(255,255,255,255),(60,82,106,255)]]
    if marks:
        eye=(min(x for x,y in marks)-2,min(y for x,y in marks)-2,
             max(x for x,y in marks)+3,max(y for x,y in marks)+3)
    else:
        eye=(14,3,22,18)
    changed=[]
    for y in range(1,39):
        for x in range(12,25):
            if eye[0]<=x<eye[2] and eye[1]<=y<eye[3]: continue
            e=im.getpixel((x,y))
            if e not in BODY: continue
            b=im.getpixel((x,y-1));d=im.getpixel((x-1,y))
            f=im.getpixel((x+1,y));h=im.getpixel((x,y+1))
            for dx,dy,p,q in [(0,0,b,d),(1,0,b,f),(0,1,h,d),(1,1,h,f)]:
                if p==q and p!=e and p in BODY:
                    result.putpixel((x*2+dx,y*2+dy),p)
                    changed.append([x*2+dx,y*2+dy])
    original=im.resize((64,80),Image.Resampling.NEAREST)
    assert original.getchannel('A').tobytes()==result.getchannel('A').tobytes()
    assert set(result.get_flattened_data()).issubset(set(im.get_flattened_data()))
    assert original.crop((0,0,24,80)).tobytes()==result.crop((0,0,24,80)).tobytes()
    rect=(max(0,eye[0])*2,max(0,eye[1])*2,min(32,eye[2])*2,min(40,eye[3])*2)
    assert original.crop(rect).tobytes()==result.crop(rect).tobytes()
    return result,dict(changed_pixels=len(changed),coordinates=changed,protected_eye=eye)


def panel(source,refined,action,key):
    board=Image.new('RGB',(512,432),(46,56,51));d=ImageDraw.Draw(board)
    for i,(label,im) in enumerate([('SOURCE / 32x40',source),('2x2 SHADE DETAIL / 64x80',refined)]):
        d.text((i*256+8,10),label,fill=(238,233,218))
        big=im.resize((256,320),Image.Resampling.NEAREST)
        board.paste(big,(i*256,35),big)
        small=im.resize((32,40),Image.Resampling.NEAREST)
        board.paste(small,(i*256+50,381),small)
        med=im.resize((64,80),Image.Resampling.NEAREST)
        board.paste(med,(i*256+140,351),med)
    d.text((8,354),f'{action.upper()} / pose {key+1}',fill=(200,207,199))
    return board


def main():
    OUT.mkdir(exist_ok=True)
    clips={}
    report=[]
    before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.glob('*.png')}
    durations={'idle':[400,270,260,270],'walk':[100,130,100,140]}
    for action in ['idle','walk']:
        frames=[]
        for key in range(4):
            source=Image.open(SOURCE/f'{action}-{key}.png').convert('RGBA')
            refined,qa=refine(source)
            refined.save(OUT/f'{action}-{key}-64x80.png')
            report.append(dict(action=action,key=key,**qa))
            frames.append(panel(source,refined,action,key))
        clips[action]=frames
        frames[0].save(OUT/f'{action}-comparison.gif',save_all=True,
                       append_images=frames[1:],duration=durations[action],loop=0,disposal=2)
        strip=Image.new('RGB',(512*4,432))
        for i,frame in enumerate(frames):strip.paste(frame,(i*512,0))
        strip.save(OUT/f'{action}-all-poses.png')
    # A compact sequence of both loops, with exactly matched paired timing.
    combined=[];times=[]
    for action in ['idle','walk']:
        for repeat in range(3):
            combined.extend(clips[action]);times.extend(durations[action])
    combined[0].save(OUT/'motion-comparison.gif',save_all=True,
                      append_images=combined[1:],duration=times,loop=0,disposal=2)
    after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.glob('*.png')}
    assert before==after
    for action in ['idle','walk']:
        gif=Image.open(OUT/f'{action}-comparison.gif')
        assert gif.n_frames==4
        actual=[]
        for i in range(gif.n_frames):
            gif.seek(i);actual.append(gif.info['duration'])
        assert actual==durations[action]
    (OUT/'review.json').write_text(json.dumps(dict(art_source='existing',
        route='copied source keys + 2x nearest scaling + selective interior color-corner edits; no image model',
        dimensions=[64,80],source_hashes=before,source_unchanged=True,
        original_palette_preserved=True,alpha_preserved=True,production_changes=False,
        durations_ms=durations,frames=report),indent=2))
    (OUT/'README.md').write_text('''# Paired 2×2 sprite animation preview

Left: existing polished original source keys. Right: nearest-2× copies with
selected opaque interior color-cluster corners refined by one small pixel.
Every original pixel occupies 2×2 pixels, not 4×4. No new colors, blur,
silhouette changes, outline edits, generative retouch or game integration.
The same local corner rule is used for all eight supplied keys; eye regions
are protected using source eye colors with a margin, tail/flame side excluded.
This is a restrained shading-boundary sample, not a new animation or a
complete external-contour retouch. Coordinates and counts in review.json.

Both sides use identical keys, canvas, position and timing. No per-frame
cropping, recentering or rescaling. Existing Walk source keys have symmetric
vertical padding to 32×40; Idle uses its original 32×40 canvas.

Large views: original 8× / edited 4×, same 256×320 footprint. Below each:
32×40 and 64×80 display footprints with nearest sampling. These are direct
sprite previews, not game camera renders. Idle totals 1.2s, matching the
current Charmander idle period. Walk uses original source duration ratios,
rounded to GIF's 10ms timing (470ms loop); actual gameplay walks are driven
by movement distance. Runtime optical-flow subframes, lighting and post
effects are deliberately absent, so both sides expose the actual art keys.

Checks: unchanged source hashes, exact alpha, original palette, protected
eye and tail pixels, four GIF poses and paired timing. Animation consistency
still needs visual review; these structural checks do not establish anatomy
or production readiness. Contact strips contain all source poses.
''')
    print(json.dumps([{'action':r['action'],'key':r['key'],'changed_pixels':r['changed_pixels']} for r in report]))


if __name__=='__main__':
    main()
