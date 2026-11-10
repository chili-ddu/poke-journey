"""Native-grid, source-preserving inbetween study. Never writes game assets.

Derived frames use native-resolution optical-flow-guided pixel transport
and a rigid upper-face patch. This is offline interpolation,
not image/video-model generation. Original keys are copied without edits.
"""
from pathlib import Path
import hashlib
import json
import argparse
import xml.etree.ElementTree as ET

import cv2
import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/charmander_native_frames'
SRC = ROOT / 'assets/sprites/0004'
DIRECTIONS = ['down', 'down-right', 'right', 'up-right', 'up', 'up-left', 'left', 'down-left']


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def gray(a):
    alpha = a[..., 3:4].astype(np.float32) / 255
    rgb = a[..., :3] * alpha + 96 * (1 - alpha)
    return cv2.cvtColor(rgb.astype(np.uint8), cv2.COLOR_RGB2GRAY)


def midpoint(a, b):
    """Work at the original pixel grid throughout; never resize source art."""
    if np.array_equal(a, b):
        return a.copy()
    flow = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    flow.setFinestScale(0)
    ab = flow.calc(gray(a), gray(b), None)
    h, w = a.shape[:2]
    yy, xx = np.mgrid[:h, :w].astype(np.float32)
    # Transport intact source pixels. Blending two tiny limbs introduces muddy
    # patches even after palette quantization; do not invent intermediate RGB.
    out = cv2.remap(a, xx - ab[..., 0] * .5, yy - ab[..., 1] * .5,
                    cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT)

    # Protect the face as one rigid source pixel cluster, not a blended eye.
    ay, ax = np.where(a[..., 3] > 0)
    cutoff = int(ay.min() + (ay.max() - ay.min() + 1) * .52)
    head = (a[..., 3] > 0) & (yy < cutoff)
    delta = np.median(ab[head], axis=0)
    dx, dy = np.rint(delta * .5).astype(int)
    matrix = np.float32([[1, 0, dx], [0, 1, dy]])
    patch = cv2.warpAffine(a, matrix, (w, h), flags=cv2.INTER_NEAREST)
    region = yy < cutoff + dy
    out[region] = patch[region]
    # A midpoint must not grow a new low foot/extra tip outside both poses.
    by, bx = np.where(b[..., 3] > 0)
    bounds = ((xx >= min(ax.min(), bx.min())) & (xx <= max(ax.max(), bx.max())) &
              (yy >= min(ay.min(), by.min())) & (yy <= max(ay.max(), by.max())))
    out[~bounds] = 0
    return out


def sheet(frames):
    h, w = frames[0][0].shape[:2]
    out = Image.new('RGBA', (len(frames[0]) * w, len(frames) * h))
    for row, cells in enumerate(frames):
        for k, cell in enumerate(cells):
            out.paste(Image.fromarray(cell), (k * w, row * h))
    return out


def contacts(action, rows, diagonals=False):
    # Display-only nearest-neighbour enlargement; stored frames stay native.
    w, h = rows[0][0].shape[1], rows[0][0].shape[0]
    scale, cellw, cellh = 5, 180, h * 5 + 28
    canvas = Image.new('RGB', (8 * cellw, 4 * cellh), '#222a28')
    d = ImageDraw.Draw(canvas)
    for rr, row in enumerate([1, 3, 5, 7] if diagonals else [0, 2, 4, 6]):
        for k, cell in enumerate(rows[row]):
            x, y = k * cellw, rr * cellh
            d.text((x + 5, y + 4), f'{DIRECTIONS[row]} / {"KEY" if k % 2 == 0 else "MID"} {k}', fill='#f1e8d5')
            im = Image.fromarray(cell).resize((w * scale, h * scale), Image.Resampling.NEAREST)
            canvas.paste(im, (x + (cellw - w * scale) // 2, y + 22), im)
    canvas.save(OUT / f'{action.lower()}{"-diagonal" if diagonals else ""}-frames.png')


def build():
    OUT.mkdir(exist_ok=True, parents=True)
    tree = ET.parse(SRC / 'AnimData.xml')
    manifest = dict(schema='native-frame-study/v1', species=4, applied=False,
                    method='native-grid DIS-guided nearest pixel transport; source palette; rigid upper-face patch',
                    model_generated=False, tick_hz=60, directions=DIRECTIONS, actions={})
    for name in ['Idle', 'Walk']:
        node = next(n for n in tree.findall('.//Anim') if n.findtext('Name') == name)
        w, h = int(node.findtext('FrameWidth')), int(node.findtext('FrameHeight'))
        ticks = [int(t.text) for t in node.findall('Durations/Duration')]
        source = SRC / f'{name}-Anim.png'
        original = np.array(Image.open(source).convert('RGBA'))
        keys, derived = [], []
        for row in range(original.shape[0] // h):
            cells = [original[row*h:(row+1)*h, k*w:(k+1)*w].copy() for k in range(len(ticks))]
            keys.append(cells)
            frames = []
            for k, a in enumerate(cells):
                frames.extend([a.copy(), midpoint(a, cells[(k + 1) % len(cells)])])
            derived.append(frames)
            for variant, imgs in [('original', cells), ('added', frames)]:
                dest = OUT / 'frames' / name.lower() / DIRECTIONS[row] / variant
                dest.mkdir(parents=True, exist_ok=True)
                for k, img in enumerate(imgs):
                    Image.fromarray(img).save(dest / f'{k:03d}.png')
        sheet(derived).save(OUT / f'{name}-8frames.png')
        contacts(name, derived)
        contacts(name, derived, diagonals=True)
        manifest['actions'][name.lower()] = dict(size=[w, h], source=str(source.relative_to(ROOT)),
            source_sha256=sha(source), original_ticks=ticks,
            added_ticks=[v for t in ticks for v in [t // 2, t - t // 2]],
            frames_original=len(ticks), frames_added=len(ticks) * 2,
            duration_ticks=sum(ticks), rows=len(derived))
    protected = [SRC / 'AnimData.xml', SRC / 'Idle-Anim.png', SRC / 'Walk-Anim.png',
                 ROOT / 'assets/smooth/manifest.json', ROOT / 'scripts/view/mon_sprite.gd',
                 ROOT / 'scripts/view/charmander_motion.gd']
    manifest['protected_hashes'] = {str(p.relative_to(ROOT)): sha(p) for p in protected}
    (OUT / 'study.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print('Native-grid study prepared: Idle 32x40, Walk 32x32; 4 -> 8 frames x 8 directions. No game writes.')


def load_frames(action, direction, variant):
    return [Image.open(f).convert('RGBA') for f in sorted((OUT / 'frames' / action / direction / variant).glob('*.png'))]


def pose_at(tick, ticks):
    t = tick % sum(ticks)
    for i, length in enumerate(ticks):
        if t < length:
            return i
        t -= length
    return 0


def preview():
    manifest = json.loads((OUT / 'study.json').read_text())
    web = {'directions': DIRECTIONS, 'actions': {}}
    for action, meta in manifest['actions'].items():
        original, added = load_frames(action, 'right', 'original'), load_frames(action, 'right', 'added')
        frames = []
        duration_ms = sum(meta['original_ticks']) * 50  # Exactly three loops, in integer ms.
        for ms in range(0, duration_ms, 10):
            canvas = Image.new('RGB', (384, 216), '#222a28')
            d = ImageDraw.Draw(canvas)
            d.text((10, 7), f'{action.upper()} / ORIGINAL GRID / SAME TIMING', fill='#f1e8d5')
            d.line((192, 27, 192, 210), fill='#47524c')
            for side, (images, ticks, label) in enumerate([
                (original, meta['original_ticks'], 'ORIGINAL - 4 KEYS'),
                (added, meta['added_ticks'], 'ADDED - 8 SLOTS')]):
                x = side * 192
                k = pose_at(ms * 60 / 1000, ticks)
                im = images[k]
                d.text((x + 10, 26), label, fill='#f1e8d5')
                large = im.resize((im.width * 3, im.height * 3), Image.Resampling.NEAREST)
                canvas.paste(large, (x + 48, 47 + (40 - im.height) * 3), large)
                canvas.paste(im, (x + 80, 173 + (40 - im.height)), im)
                d.text((x + 12, 183), '1x', fill='#c0c6b3')
                d.text((x + 132, 184), f'{k + 1}/{len(images)}', fill='#c0c6b3')
            frames.append(canvas)
        frames[0].save(OUT / f'{action}-comparison.gif', save_all=True, append_images=frames[1:],
                       duration=10, loop=0, disposal=2, optimize=False)
        frames[0].save(OUT / f'{action}-poster.png')
        web['actions'][action] = dict(meta, sheets={'original': meta['source'], 'added': f'{action.title()}-8frames.png'})
    # Self-contained sprites in the local review page: exact 60 Hz timing;
    # same global playhead, per-direction stepping, no image smoothing.
    import base64
    for action, data in web['actions'].items():
        for variant, path in data['sheets'].items():
            src = ROOT / path if variant == 'original' else OUT / path
            data['sheets'][variant] = 'data:image/png;base64,' + base64.b64encode(src.read_bytes()).decode()
    template = '''<!doctype html><html lang="ko"><meta charset="utf-8"><title>파이리 원본 해상도 프레임 비교</title>
<style>body{background:#222a28;color:#f1e8d5;font:15px system-ui;max-width:850px;margin:32px auto;padding:0 20px}button,select,input{font:inherit;margin:6px;padding:5px}canvas{image-rendering:pixelated;border:1px solid #47524c}p{line-height:1.6}small{color:#c0c6b3}</style>
<h1>파이리 · 원본 해상도에서 프레임 추가</h1><p>왼쪽 원본 4장 / 오른쪽 8칸. 원본 키 프레임·팔레트·전체 재생 시간 유지.<br>게임 미적용. 상단은 3배 보기용 확대, 하단은 원본 1배 표시.</p>
<select id="action"><option value="idle">대기</option><option value="walk">걷기</option></select>
<select id="direction"></select><button id="play">일시 정지</button><button id="prev">이전 칸</button><button id="next">다음 칸</button><button id="slow">0.5배속</button><br>
<canvas id="preview" width="384" height="216"></canvas><p id="caption"></p>
<p><small>기존 프레임을 처리한 보간 샘플입니다. 이미지·동영상 모델로 새 동작을 생성한 결과가 아닙니다. 원본 픽셀을 이동하므로 1픽셀 이동 구간은 중간 프레임이 원본과 같을 수 있습니다. 다리 겹침과 꼬리의 연결은 계속 검토할 부분입니다.</small></p>
<p><a href="idle-frames.png">대기 전체 키/중간 프레임</a> · <a href="walk-frames.png">걷기 전체 키/중간 프레임</a> · <a href="QA-NOTES.md">검수 기록</a></p>
<script>const data=STUDY;const action=document.querySelector('#action'),direction=document.querySelector('#direction'),c=document.querySelector('canvas'),ctx=c.getContext('2d');ctx.imageSmoothingEnabled=false;data.directions.forEach((d,i)=>direction.add(new Option(d,i)));direction.value='2';const images={};for(const [a,m]of Object.entries(data.actions)){images[a]={};for(const [v,url]of Object.entries(m.sheets)){let im=new Image();im.src=url;images[a][v]=im;}}
let tick=0,last=performance.now(),running=true,rate=1;const index=(t,ts)=>{t=((t%ts.reduce((a,b)=>a+b,0))+ts.reduce((a,b)=>a+b,0))%ts.reduce((a,b)=>a+b,0);for(let k=0;k<ts.length;k++){if(t<ts[k])return k;t-=ts[k];}return 0};
function render(now){const m=data.actions[action.value];if(running)tick+=(now-last)*.06*rate;last=now;ctx.fillStyle='#222a28';ctx.fillRect(0,0,384,216);ctx.fillStyle='#f1e8d5';ctx.font='12px system-ui';for(const [side,v]of ['original','added'].entries()){const ticks=m[v+'_ticks'],k=index(tick,ticks),[w,h]=m.size,x=side*192,im=images[action.value][v];ctx.fillText(v==='original'?'원본 4장':'중간 프레임 추가 · 8칸',x+10,24);if(im.complete&&im.naturalWidth){ctx.drawImage(im,k*w,+direction.value*h,w,h,x+48,47+(40-h)*3,w*3,h*3);ctx.drawImage(im,k*w,+direction.value*h,w,h,x+80,173+(40-h),w,h);}ctx.fillText('1배',x+12,193);ctx.fillText(`${k+1}/${ticks.length}`,x+132,193);}document.querySelector('#caption').textContent=`원본 ${m.size.join('×')} px · 1주기 ${(m.duration_ticks/60).toFixed(3)}초 · ${rate}배속 · 같은 시각 비교`;requestAnimationFrame(render)}requestAnimationFrame(render);
document.querySelector('#play').onclick=()=>{running=!running;document.querySelector('#play').textContent=running?'일시 정지':'재생'};function step(d){running=false;document.querySelector('#play').textContent='재생';const ts=data.actions[action.value].added_ticks;let k=(index(tick,ts)+d+ts.length)%ts.length;tick=ts.slice(0,k).reduce((a,b)=>a+b,0)+.001;}document.querySelector('#next').onclick=()=>step(1);document.querySelector('#prev').onclick=()=>step(-1);document.querySelector('#slow').onclick=()=>{rate=rate===1?.5:1;document.querySelector('#slow').textContent=rate===1?'0.5배속':'1배속'};action.onchange=()=>{tick=0};</script></html>'''
    (OUT / 'index.html').write_text(template.replace('STUDY', json.dumps(web)))
    print('Two synchronized 384x216 GIFs, 1x strips and self-contained 8-direction reviewer exported.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('command', nargs='?', choices=['build', 'preview', 'all'], default='all')
    args = parser.parse_args()
    if args.command in ['build', 'all']:
        build()
    if args.command in ['preview', 'all']:
        preview()
