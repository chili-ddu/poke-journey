"""Package unscaled GPU captures from the isolated material study."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw, ImageFont
import argparse, hashlib, json, subprocess

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/skill_shader_review'
NAMES = {'electric': '전기쇼크', 'leaf': '잎날가르기', 'wind': '바람일으키기', 'psychic': '염동력'}
FONT = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 11)


def package_case(job):
    kind, direction, entries, round_number = job
    a = next(r for r in entries if r['variant'] == 'existing')
    b = next(r for r in entries if r['variant'] == 'sample')
    assert a['trace'] == b['trace'] and a['hit_frame'] == b['hit_frame']
    assert a['target_visible'] == b['target_visible']
    assert b['material_metrics']['shader_frames'] > 0
    assert all(r['material_metrics']['initial_facing_correct'] for r in entries)
    count = len(a['trace'])
    crop_x = max(0, min(192, round((192 + a['centers'][0][0]) / 2 - 96)))
    folder = OUT / f'native-r{round_number}' / f'{kind}-{direction}'
    dest = OUT / f'comparison-r{round_number}' / f'{kind}-{direction}'
    dest.mkdir(parents=True, exist_ok=True)
    frames = []
    for frame in range(count):
        canvas = Image.new('RGB', (384, 216))
        for col, variant in enumerate(['existing', 'sample']):
            with Image.open(folder / variant / f'{frame:03}.png') as im:
                assert im.size == (384, 216)
                canvas.paste(im.convert('RGB').crop((crop_x, 0, crop_x + 192, 216)), (192 * col, 0))
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((0, 0, 383, 18), fill='#222a28')
        draw.text((5, 2), '기존 연출', font=FONT, fill='#f1e8d5')
        draw.text((197, 2), '속성별 쉐이더 샘플', font=FONT, fill='#f1e8d5')
        draw.line((191, 0, 191, 215), fill='#6f7e73')
        canvas.save(dest / f'{frame:03}.png')
        frames.append(canvas)
    durations = [33, 33, 34] * (count // 3)
    frames[0].save(dest / 'comparison.png', save_all=True, append_images=frames[1:],
                   duration=durations, loop=0, disposal=0, blend=0)
    proc = subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '30', '-i', str(dest / '%03d.png'),
                           '-c:v', 'libvpx-vp9', '-lossless', '1', '-pix_fmt', 'yuv444p', '-deadline', 'good',
                           '-cpu-used', '4', '-row-mt', '1', '-an', str(dest / 'comparison.webm')],
                          text=True, capture_output=True)
    assert proc.returncode == 0, proc.stderr
    with Image.open(dest / 'comparison.png') as im:
        stored = im.n_frames
        total = 0
        for i in range(im.n_frames):
            im.seek(i)
            total += im.info['duration']
        assert total == sum(durations) and im.size == (384, 216)
    return dict(kind=kind, name=NAMES[kind], direction=direction, native_size=[384, 216],
                frames=count, stored_apng_frames=stored, duration_ms=total, fps=30,
                damage=b['damage'], hit_frame=b['hit_frame'], state_equal=True, feedback_equal=True,
                initial_facing_correct=True, material_metrics=b['material_metrics'],
                video=str((dest / 'comparison.webm').relative_to(OUT)),
                image=str((dest / 'comparison.png').relative_to(OUT)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--round', type=int, default=4)
    args = parser.parse_args()
    report = json.loads((OUT / f'native-r{args.round}/checks.json').read_text())
    groups = sorted({(r['kind'], r['direction']) for r in report})
    jobs = [(k, d, [r for r in report if r['kind'] == k and r['direction'] == d], args.round) for k, d in groups]
    with ThreadPoolExecutor(max_workers=3) as pool:
        cases = list(pool.map(package_case, jobs))
    (OUT / f'comparisons-r{args.round}.json').write_text(json.dumps(cases, indent=2, ensure_ascii=False) + '\n')
    if args.round >= 3:
        assert len(report) == 32 and len(cases) == 16
        (OUT / 'comparisons.json').write_text(json.dumps(cases, indent=2, ensure_ascii=False) + '\n')
        (OUT / 'index.html').write_text((ROOT / 'tools/samples/skill_shader_review.html').read_text())
        protected = json.loads((OUT / 'protected-before.json').read_text())
        changed = [p for p, h in protected.items() if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != h]
        # Other work may update the shared checkout during a long render. Record
        # those observations without overwriting them or claiming a clean tree.
        references = [str(p.relative_to(ROOT)) for folder in ['scripts', 'scenes'] for p in (ROOT / folder).rglob('*')
                      if p.is_file() and p.suffix in ['.gd', '.tscn']
                      and any(name in p.read_text() for name in ['skill_flow_material', 'skill_shader_review'])]
        assert not references, references
        (OUT / 'qa-summary.json').write_text(json.dumps(dict(native_cases=len(report), comparisons=len(cases),
            protected_files=len(protected), observed_production_hash_changes=changed,
            production_references_to_sample=references, game_connected=False,
            state_equal=True, feedback_equal=True, initial_facing_correct=True), indent=2) + '\n')
    print(f'Round {args.round}: {len(cases)} GPU comparisons; original combat, feedback, and initial direction verified')


if __name__ == '__main__':
    main()
