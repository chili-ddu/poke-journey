"""Compose source cutouts at alternate positions for visual review; no game writes."""
import hashlib
import json
from pathlib import Path
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]
D = ROOT / 'docs/source_object_audit/center_masks'
OUT = D / 'counter_restored/placement'

def main():
    OUT.mkdir(exist_ok=True)
    records = {o['id']: o for o in json.loads((D / 'objects.json').read_text())['objects']}
    names = ['vase_left', 'vase_right', 'counter_nameplate']
    paths = [D / 'counter_restored/counter.png'] + [D / 'objects' / f'{n}.png' for n in names]
    hashes = {str(p.relative_to(ROOT)): hashlib.sha256(p.read_bytes()).hexdigest() for p in paths}
    counter = Image.open(paths[0]).convert('RGBA')
    sprites = {n: Image.open(D / 'objects' / f'{n}.png').convert('RGBA') for n in names}
    origin = records['counter']['bounds_pixels'][:2]
    original = {n: [records[n]['bounds_pixels'][i] - origin[i] for i in range(2)] for n in names}
    cases = [
        ('Original positions', original),
        ('All objects removed', {}),
        ('Vases moved inward; nameplate moved left', {n: [original[n][0] + dx, original[n][1]] for n, dx in zip(names, [20, -20, -16])}),
        ('Vases moved up rear arms; nameplate moved right', {n: [original[n][0] + dx, original[n][1] + dy] for n, dx, dy in zip(names, [0, 0, 16], [-10, -10, 0])}),
    ]
    board = Image.new('RGB', (744, 4 * 276), '#252a33')
    draw = ImageDraw.Draw(board)
    results = []
    for i, (title, positions) in enumerate(cases):
        scene = counter.copy()
        coverage = Image.new('L', scene.size)
        for name, pos in positions.items():
            sprite = sprites[name]
            x, y = pos
            assert x >= 0 and y >= 0 and x + sprite.width <= scene.width and y + sprite.height <= scene.height
            scene.alpha_composite(sprite, tuple(pos))
            coverage.paste(sprite.getchannel('A'), tuple(pos))
        # Revealed areas must be exactly the restored counter, without stale source objects.
        for y in range(scene.height):
            for x in range(scene.width):
                if coverage.getpixel((x, y)) == 0:
                    assert scene.getpixel((x, y)) == counter.getpixel((x, y))
        scene.save(OUT / f'case_{i}.png')
        yy = i * 276
        draw.text((16, yy + 8), title, fill='white')
        background = Image.new('RGBA', scene.size)
        bd = ImageDraw.Draw(background)
        for y in range(0, scene.height, 2):
            for x in range(0, scene.width, 2):
                bd.rectangle((x, y, x+1, y+1), fill='#666e7a' if (x+y)//2 % 2 else '#8d96a3')
        background.alpha_composite(scene)
        board.paste(background.resize((scene.width*6, scene.height*6), Image.Resampling.NEAREST), (16, yy+28))
        results.append({'title': title, 'positions_counter_local_pixels': positions})
    board.save(OUT / 'comparison.png')
    edges = Image.new('RGB', (720, 220), '#252a33')
    ed = ImageDraw.Draw(edges)
    for i, name in enumerate(names):
        ed.text((i*240+8, 8), name, fill='white')
        sprite = sprites[name]
        for j, color in enumerate(['#000000', '#ffffff']):
            bg = Image.new('RGBA', (20, 20), color)
            bg.alpha_composite(sprite, (2, 2))
            edges.paste(bg.resize((100, 100), Image.Resampling.NEAREST), (i*240+j*112+8, 36))
    edges.save(OUT / 'edges.png')
    assert all(hashlib.sha256((ROOT / p).read_bytes()).hexdigest() == h for p, h in hashes.items())
    (OUT / 'review.json').write_text(json.dumps({'status': '2d_composite_review_only', 'input_sha256': hashes, 'cases': results, 'checks': ['input files unchanged', 'objects inside canvas', 'uncovered pixels equal restored counter'], 'limitations': ['No Godot depth sorting, collision or perspective validation.', 'Baked object shading retained; black/white backgrounds expose edge colors for review.']}, indent=2))
    (OUT / 'index.html').write_text('''<!doctype html><meta charset="utf-8"><title>카운터 배치 검토</title><style>body{background:#191e26;color:#eee;font:16px system-ui;margin:32px;max-width:1000px}img{max-width:100%;image-rendering:pixelated}a{color:#9cf}</style><h1>카운터 소품 이동 검토</h1><p>순서: 원래 위치 / 소품 제거 / 화병을 안쪽으로·명패를 왼쪽으로 / 화병을 위쪽으로·명패를 오른쪽으로. 원본 1픽셀 단위로 이동하며 확대는 최근접 보간입니다.</p><img src="comparison.png"><h2>소품 가장자리 — 검정·흰색</h2><img src="edges.png"><p>육안 검토: 이동 후 원래 위치의 구멍·잔상과 복원 경계의 가는 선은 보이지 않았습니다. 화병 하단의 회색 테두리/음영은 소품에 남아 함께 이동합니다. 형태와 접지 음영의 분리 여부는 HD-2D 화면에서 추가 판단해야 합니다. 2D 합성 검토이며 게임의 깊이 정렬·충돌·HD-2D 시점 검증은 포함하지 않습니다.</p><a href="review.json">좌표 및 검증 기록</a> · <a href="../index.html">복원 비교로 돌아가기</a>''')
    print('4 placement cases; unchanged inputs and uncovered pixels verified')

if __name__ == '__main__':
    main()
