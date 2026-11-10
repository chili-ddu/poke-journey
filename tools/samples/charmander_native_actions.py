"""All original Charmander actions: native-grid study, never game assets.

Existing art, not model generation. Retain all original keys and their times.
Use a 120 Hz timeline to split even a one-60-Hz-tick frame in half exactly.
One-shots hold their last pose; only authored cycles get last-to-first tweens.
"""
from pathlib import Path
import argparse
import base64
import hashlib
import json
import sys
import shutil
import xml.etree.ElementTree as ET

import cv2
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).parent))
from charmander_native_frames import midpoint, sheet, DIRECTIONS

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/charmander_native_actions'
SRC = ROOT / 'assets/sprites/0004'
LOOPS = {'Idle', 'Walk', 'Sleep', 'EventSleep', 'Eat', 'Float', 'Rotate', 'Pull'}
LABELS = dict(Walk='걷기', Attack='기본 공격', Kick='발차기', Shoot='발사 (모으기 공유)',
    Strike='할퀴기 원본', Sleep='수면', Hurt='피격', Idle='대기', Swing='휘두르기',
    Double='연속 공격', Hop='점프', Charge='모으기', Rotate='회전', EventSleep='이벤트 수면',
    Wake='기상', Eat='먹기', Tumble='구르기', Pose='포즈', Pull='당기기', Pain='아파하기',
    Float='뜨기', DeepBreath='심호흡', Nod='끄덕이기', Sit='앉기', LookUp='올려다보기',
    Sink='가라앉기', Trip='넘어지기', Laying='누운 정지 자세', LeapForth='앞으로 뛰기',
    Head='머리 정지 자세', Cringe='움츠리기', LostBalance='균형 잃기',
    TumbleBack='뒤로 구르기', Faint='기절', HitGround='바닥에 닿기')


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def source_path(name, suffix='-Anim.png'):
    a = SRC / (name + suffix)
    return a if a.exists() else OUT / 'source-extra' / (name + suffix)


def frames_for(name, row, variant):
    return [Image.open(p).convert('RGBA') for p in sorted((OUT / 'frames' / name / f'row-{row}' / variant).glob('*.png'))]


def conservative_midpoint(a, b):
    if not np.any(a[..., 3]) or not np.any(b[..., 3]):
        return a.copy(), 'empty_transition_hold'
    out = midpoint(a, b)
    area = int(np.count_nonzero(out[..., 3]))
    amin, amax = sorted([int(np.count_nonzero(x[..., 3])) for x in [a, b]])
    # Do not accept flow that eats a limb or grows substantial extra mass.
    if not .85 * amin <= area <= 1.15 * amax:
        return a.copy(), 'area_guard_hold'
    return out, 'native_pixel_transport'


def rigid_midpoint(a, delta):
    """Large authored root movement: carry the entire pose without warping it."""
    dx,dy=np.rint(np.asarray(delta)*.5).astype(int)
    h,w=a.shape[:2]
    out=cv2.warpAffine(a,np.float32([[1,0,dx],[0,1,dy]]),(w,h),flags=cv2.INTER_NEAREST)
    if np.count_nonzero(out[...,3]) != np.count_nonzero(a[...,3]):
        return a.copy(),'edge_guard_hold'
    return out,'rigid_root_midpoint'


def build():
    OUT.mkdir(exist_ok=True, parents=True)
    nodes = {n.findtext('Name'): n for n in ET.parse(SRC / 'AnimData.xml').findall('.//Anim')}
    manifest = dict(schema='native-action-study/v1', species=4, applied=False,
        art_source='existing', model_generated=False, tick_hz=120, directions=DIRECTIONS,
        protected_hashes=json.loads((OUT / 'protected-before.json').read_text()), actions={})
    decisions = []
    for name, own in nodes.items():
        source_name = own.findtext('CopyOf') or name
        node = nodes[source_name]
        w, h = int(node.findtext('FrameWidth')), int(node.findtext('FrameHeight'))
        ticks = [int(t.text) for t in node.findall('Durations/Duration')]
        path = source_path(source_name)
        raw = np.array(Image.open(path).convert('RGBA'))
        assert raw.shape[1] == w * len(ticks) and raw.shape[0] % h == 0
        rows = raw.shape[0] // h
        offsets=np.array(Image.open(source_path(source_name,'-Offsets.png')).convert('RGBA'))
        added_rows = []
        for row in range(rows):
            cells = [raw[row*h:(row+1)*h, k*w:(k+1)*w].copy() for k in range(len(ticks))]
            roots=[]
            for k in range(len(ticks)):
                part=offsets[row*h:(row+1)*h,k*w:(k+1)*w]
                y,x=np.where(np.all(part==[0,0,0,255],axis=-1))
                roots.append(np.array([x[0],y[0]]) if len(x) else None)
            expanded = []
            for k, cell in enumerate(cells):
                reason = 'native_pixel_transport'
                if source_name in ['Idle', 'Walk']:
                    old = ROOT / 'docs/charmander_native_frames/frames' / source_name.lower() / DIRECTIONS[row] / 'added' / f'{k*2+1:03d}.png'
                    mid = np.array(Image.open(old).convert('RGBA'))
                    reason = 'retained_previous_study'
                elif len(cells) == 1:
                    mid, reason = cell.copy(), 'static_pose_hold'
                elif k == len(cells) - 1 and name not in LOOPS:
                    mid, reason = cell.copy(), 'terminal_hold_no_wrap'
                elif roots[k] is not None and roots[(k+1)%len(cells)] is not None and np.linalg.norm(roots[(k+1)%len(cells)]-roots[k]) >= 6:
                    mid,reason=rigid_midpoint(cell,roots[(k+1)%len(cells)]-roots[k])
                else:
                    mid, reason = conservative_midpoint(cell, cells[(k+1) % len(cells)])
                expanded.extend([cell.copy(), mid])
                identical = np.array_equal(mid, cell) or np.array_equal(mid, cells[(k+1) % len(cells)])
                decisions.append(dict(action=name, row=row, source_frame=k, added_frame=k*2+1,
                    method=reason, identical_to_endpoint=identical))
            added_rows.append(expanded)
            for variant, images in [('original', cells), ('added', expanded)]:
                folder = OUT / 'frames' / name / f'row-{row}' / variant
                folder.mkdir(exist_ok=True, parents=True)
                for k, image in enumerate(images):
                    file=folder/f'{k:03d}.png'
                    if file.exists() and not np.array_equal(np.array(Image.open(file).convert('RGBA')),image):
                        archived=OUT/'draft-v1/changed-inputs'/file.relative_to(OUT)
                        archived.parent.mkdir(parents=True,exist_ok=True)
                        if not archived.exists():shutil.copyfile(file,archived)
                    Image.fromarray(image).save(file)
        dest = OUT / 'sheets' / f'{name}-2frames.png'
        dest.parent.mkdir(exist_ok=True)
        sheet(added_rows).save(dest)
        events = {}
        for tag in ['RushFrame', 'HitFrame', 'ReturnFrame']:
            value = node.findtext(tag)
            if value is not None:
                i = int(value)
                events[tag] = dict(source_frame=i, added_frame=i*2, at_tick=sum(ticks[:i])*2)
        manifest['actions'][name] = dict(label=LABELS[name], source_name=source_name,
            alias_of=own.findtext('CopyOf'), source=str(path.relative_to(ROOT)), source_sha256=sha(path),
            sheet=str(dest.relative_to(OUT)), size=[w, h], rows=rows,
            original_ticks=[t*2 for t in ticks], added_ticks=[v for t in ticks for v in [t, t]],
            duration_ticks=sum(ticks)*2, loop=name in LOOPS, static=len(ticks)==1, events=events)
    (OUT / 'study.json').write_text(json.dumps(manifest, indent=2) + '\n')
    (OUT / 'midpoint-decisions.json').write_text(json.dumps(decisions, indent=2) + '\n')
    print(f'{len(nodes)} actions prepared; original keys retained; native grid; exact 120 Hz half-tick timeline.', flush=True)


def index_at(t, ticks, loop):
    if loop:
        t %= sum(ticks)
    else:
        t = min(max(t, 0), sum(ticks) - 1e-8)
    for k, duration in enumerate(ticks):
        if t < duration:
            return k
        t -= duration
    return len(ticks) - 1


def paint(name, meta, pair, tick, scale=2, light=False):
    bg, ink = ('#d7d8c4', '#30382e') if light else ('#222a28', '#f1e8d5')
    canvas = Image.new('RGB', (384, 216), bg)
    d = ImageDraw.Draw(canvas)
    d.line((192, 24, 192, 215), fill='#677366')
    for side, variant in enumerate(['original', 'added']):
        k = index_at(tick, meta[f'{variant}_ticks'], meta['loop'])
        im = pair[variant][k]
        x = side*192 + 96 - im.width*scale//2
        y = 120 - im.height*scale//2
        big = im.resize((im.width*scale, im.height*scale), Image.Resampling.NEAREST)
        canvas.paste(big, (x, y), big)
        d.text((side*192+7, 6), f'{name}: {variant.upper()}', fill=ink)
        d.text((side*192+7, 20), f'{k+1}/{len(pair[variant])}    {scale}x', fill=ink)
    return canvas


def contacts(name, meta):
    # Every frame in every direction, paged to keep the pixels inspectable.
    out = OUT / 'contacts' / name
    out.mkdir(parents=True, exist_ok=True)
    w, h = meta['size']
    cellw, cellh = max(100, w*2+10), h*2+24
    for start in range(0, len(meta['added_ticks']), 8):
        count = min(8, len(meta['added_ticks'])-start)
        board = Image.new('RGB', (count*cellw, meta['rows']*cellh), '#222a28')
        d = ImageDraw.Draw(board)
        for row in range(meta['rows']):
            for i, im in enumerate(frames_for(name, row, 'added')[start:start+count]):
                k = i+start
                x, y = i*cellw, row*cellh
                d.text((x+3, y+3), f'r{row} {"KEY" if k%2==0 else "MID"} {k}', fill='#f1e8d5')
                big = im.resize((w*2, h*2), Image.Resampling.NEAREST)
                board.paste(big, (x+(cellw-w*2)//2,y+22), big)
        board.save(out / f'page-{start//8+1}.png')


def preview():
    m = json.loads((OUT / 'study.json').read_text())
    web = dict(tick_hz=m['tick_hz'], directions=DIRECTIONS, actions={})
    for name, meta in m['actions'].items():
        row = min(2, meta['rows']-1)
        pair = {v: frames_for(name, row, v) for v in ['original', 'added']}
        total_ms = meta['duration_ticks'] * 25 + (0 if meta['loop'] else 1500)
        cycle_ticks = meta['duration_ticks'] + (0 if meta['loop'] else 60)
        for scale in [1, 2]:
            gif_frames = []
            for ms in range(0, total_ms, 10):
                tick = (ms*.12) % cycle_ticks
                gif_frames.append(paint(name, meta, pair, tick, scale))
            folder = OUT / 'gifs';folder.mkdir(exist_ok=True)
            gif_frames[0].save(folder/f'{name}-{scale}x.gif', save_all=True,
                append_images=gif_frames[1:], duration=10, loop=0, optimize=False, disposal=2)
        contacts(name, meta)
        sheets = {}
        for variant, path in [('original', ROOT/meta['source']), ('added', OUT/meta['sheet'])]:
            sheets[variant] = 'data:image/png;base64,' + base64.b64encode(path.read_bytes()).decode()
        web['actions'][name] = dict(meta, sheets=sheets)
        print('Preview', name, flush=True)
    template = (Path(__file__).parent / 'charmander_native_actions_review.html').read_text()
    (OUT/'index.html').write_text(template.replace('__STUDY_JSON__', json.dumps(web)))


def overview():
    m=json.loads((OUT/'study.json').read_text());names=list(m['actions'])
    for start in range(0,len(names),5):
        batch=names[start:start+5]
        board=Image.new('RGB',(1152,len(batch)*202),'#222a28');d=ImageDraw.Draw(board)
        for r,name in enumerate(batch):
            a=m['actions'][name];mids=frames_for(name,min(2,a['rows']-1),'added')[1::2]
            d.text((5,r*202+3),name,fill='#f1e8d5')
            d.text((960,r*202+3),f'{len(mids)} -> {len(mids)*2}',fill='#f1e8d5')
            for col,im in enumerate(mids):
                cw=1152//len(mids);big=im.resize((im.width*2,im.height*2),Image.Resampling.NEAREST)
                board.paste(big,(col*cw+(cw-big.width)//2,r*202+25+(176-big.height)//2),big)
        board.save(OUT/f'review-page-{start//5+1}.png')


if __name__ == '__main__':
    p=argparse.ArgumentParser();p.add_argument('command',choices=['build','preview','all'],default='all',nargs='?')
    a=p.parse_args()
    if a.command in ['build','all']:build()
    if a.command in ['preview','all']:
        preview();overview()
