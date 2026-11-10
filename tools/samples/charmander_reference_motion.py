"""Extend the forehead-restored still study to existing Idle/Walk keys."""
from pathlib import Path
import json,hashlib
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]
SOURCE=ROOT/'docs/charmander_resolution_sample/source'
STILL=ROOT/'docs/charmander_reference_study'
OUT=ROOT/'docs/charmander_reference_motion'
CREAM=(239,215,168,255);SHADE=(207,178,133,255);DEEP=(173,139,100,255)
MID=(217,104,53,255)


def refine(im,key,action):
    original=im.resize((64,80),Image.Resampling.NEAREST)
    result=original.copy()
    # The 0/2 poses share the same torso drawing, with authored vertical bob.
    # Translate edit coordinates, never translate or recenter the sprite.
    if key in [0,2]:
        a=Image.open(STILL/'original-nearest-2x.png').convert('RGBA')
        b=Image.open(STILL/'reference-study-v2-64x80.png').convert('RGBA')
        dy=-6 if action=='idle' and key==2 else 0
        for y in range(80):
            for x in range(64):
                if a.getpixel((x,y))!=b.getpixel((x,y)):
                    assert original.getpixel((x,y+dy))==a.getpixel((x,y))
                    result.putpixel((x,y+dy),b.getpixel((x,y)))
    else:
        # Extended-arm keys expose different belly shapes. Recolor only the
        # existing visible belly cells, preserving the hand's occlusion.
        gold=[]
        for y in range(8,27):
            for x in range(12,23):
                c=im.getpixel((x,y))
                if c in [(228,190,115,255),(173,129,74,255),(255,247,0,255)]:
                    gold.append((x,y,c))
        bottom=max(y for x,y,c in gold)
        for x,y,c in gold:
            color=DEEP if c==(173,129,74,255) else SHADE if y==bottom else CREAM
            for dx in range(2):
                for dy in range(2):result.putpixel((x*2+dx,y*2+dy),color)
        shift=-6 if action=='idle' else 0
        # One rounded entry to the existing connected arm shadow in each
        # arm pose; do not run the earlier general color-corner filter.
        coords=([(29,36),(28,37)] if key==1 else [(25,36),(24,37)])
        for x,y in coords:
            y+=shift
            assert original.getpixel((x,y))==(147,67,56,255)
            result.putpixel((x,y),MID)
    assert result.getchannel('A').tobytes()==original.getchannel('A').tobytes()
    assert result.crop((0,0,24,80)).tobytes()==original.crop((0,0,24,80)).tobytes()
    # Keep all pixels at and above the eyes identical, including forehead.
    eyes=[(x,y) for y in range(20) for x in range(12,24)
          if im.getpixel((x,y)) in [(60,82,106,255),(255,255,255,255)]]
    eyemax=max(y for x,y in eyes)
    assert result.crop((0,0,64,(eyemax+1)*2)).tobytes()==original.crop((0,0,64,(eyemax+1)*2)).tobytes()
    return original,result


def panel(a,b,action,key):
    board=Image.new('RGB',(512,440),(46,56,51));d=ImageDraw.Draw(board)
    for i,(label,im) in enumerate([('ORIGINAL',a),('REFERENCE STUDY / FOREHEAD FIX',b)]):
        d.text((i*256+6,10),label,fill=(238,233,218))
        large=im.resize((256,320),Image.Resampling.NEAREST)
        board.paste(large,(i*256,38),large)
        board.paste(im,(i*256+140,356),im)
        tiny=im.resize((32,40),Image.Resampling.NEAREST)
        board.paste(tiny,(i*256+50,392),tiny)
    d.text((8,361),f'{action.upper()} / pose {key+1}',fill=(200,207,199))
    return board


def main():
    OUT.mkdir(exist_ok=True)
    before={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.glob('*.png')}
    clips={};report=[]
    durations={'idle':[400,270,260,270],'walk':[100,130,100,140]}
    for action in ['idle','walk']:
        frames=[]
        for key in range(4):
            source=Image.open(SOURCE/f'{action}-{key}.png').convert('RGBA')
            a,b=refine(source,key,action)
            b.save(OUT/f'{action}-{key}-64x80.png')
            if key==0:
                assert b.tobytes()==Image.open(STILL/'reference-study-v2-64x80.png').convert('RGBA').tobytes()
            edits=[dict(x=x,y=y,before=a.getpixel((x,y)),after=b.getpixel((x,y)))
                   for y in range(80) for x in range(64) if a.getpixel((x,y))!=b.getpixel((x,y))]
            report.append(dict(action=action,key=key,changed_pixels=len(edits),edits=edits))
            frames.append(panel(a,b,action,key))
        clips[action]=frames
        frames[0].save(OUT/f'{action}-comparison.gif',save_all=True,append_images=frames[1:],
                       duration=durations[action],loop=0,disposal=2)
        strip=Image.new('RGB',(512*4,440))
        for i,frame in enumerate(frames):strip.paste(frame,(512*i,0))
        strip.save(OUT/f'{action}-all-poses.png')
    combined=[];times=[]
    for action in ['idle','walk']:
        for repeat in range(3):combined.extend(clips[action]);times.extend(durations[action])
    combined[0].save(OUT/'motion-comparison.gif',save_all=True,append_images=combined[1:],
                      duration=times,loop=0,disposal=2)
    after={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in SOURCE.glob('*.png')}
    assert before==after
    for action in ['idle','walk']:
        gif=Image.open(OUT/f'{action}-comparison.gif');assert gif.n_frames==4
        actual=[]
        for i in range(4):gif.seek(i);actual.append(gif.info['duration'])
        assert actual==durations[action]
    (OUT/'review.json').write_text(json.dumps(dict(art_source='existing',
        route='existing source keys + pose-specific pixel edits; no image model',
        official_reference='https://sg.portal-pokemon.com/pokedex/0004/',
        source_sha256=before,canvas=[64,80],production_changes=False,
        source_unchanged=True,alpha_unchanged=True,forehead_eye_tail_unchanged=True,
        first_key_matches_approved_forehead_revision=True,
        durations_ms=durations,frames=report),indent=2))
    (OUT/'README.md').write_text('''# Forehead-restored reference study in motion — not applied

Extends the separate reference-study-v2 still to eight existing source keys.
No generated motion. Current polished originals at left; 64×80 pose-specific
edits at right, matched position and timing. Key 0 exactly matches the last
forehead-restored still. The shared 0/2 torso edits follow its authored bob;
the 1/3 poses use their own visible belly masks and two selected arm-shadow
entry edits. Hand occlusion remains as drawn. Three shared cream tones.
Forehead, eye region, tail/flame and silhouette remain original in every key.

Idle 1.2s; Walk source key proportions rounded to GIF 10ms ticks, 470ms.
Actual gameplay Walk is distance-driven. No optical-flow in-between frames,
lighting or camera processing. Source Walk cells retain symmetric padding
to the 32×40 comparison canvas; no pose recentering or rescaling.

Top: equal 256×320 enlarged footprints (original/effectively 8×; edited 4×).
Below: 32×40 and 64×80 direct sprite display previews. No game capture or
integration. Anatomy/temporal review applies only to these right-facing keys.
Checks: original source hashes, exact alpha, protected regions, first-frame
match to the still study, four GIF frames and paired durations. All eight
poses are on contact strips. Pixel coordinates and colors in review.json.
Official design reference: https://sg.portal-pokemon.com/pokedex/0004/.
''')
    print(json.dumps([{k:r[k] for k in ['action','key','changed_pixels']} for r in report]))


if __name__=='__main__':main()
