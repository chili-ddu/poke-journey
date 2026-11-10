"""Compare actual native GPU captures, with no post-composited FX."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import json, subprocess, hashlib
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/skill_softness_review'
FONT = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 11)
NAMES = {'fire': '불꽃세례', 'water': '물대포'}
REPORT = []


def package_case(job):
    kind, direction, reference = job
    entries = [r for r in REPORT if r['kind'] == kind and r['direction'] == direction]
    a = next(r for r in entries if r['variant'] == reference)
    b = next(r for r in entries if r['variant'] == 'sample')
    assert a['trace'] == b['trace']
    assert a['hit_frame'] == b['hit_frame'] and a['target_visible'] == b['target_visible']
    if kind == 'fire':
        assert b['material_metrics']['original_heat_shader_frames'] > 0
    else:
        assert b['material_metrics']['original_water_layer_frames'] > 0
    crop_x = max(0, min(192, round((192 + a['centers'][0][0]) / 2 - 96)))
    dest = OUT / 'comparison' / f'{kind}-{direction}-{reference}'
    dest.mkdir(parents=True, exist_ok=True)
    frames = []
    for frame in range(60):
        canvas = Image.new('RGB', (384, 216))
        for side, variant in enumerate([reference, 'sample']):
            src = OUT / 'native' / f'{kind}-{direction}' / variant / f'{frame:03}.png'
            with Image.open(src) as im:
                assert im.size == (384, 216)
                canvas.paste(im.convert('RGB').crop((crop_x, 0, crop_x + 192, 216)), (side * 192, 0))
        draw = ImageDraw.Draw(canvas)
        draw.rectangle((0, 0, 383, 18), fill='#222a28')
        draw.text((5, 2), '기존 연출' if reference == 'existing' else '앞선 시안', font=FONT, fill='#f1e8d5')
        draw.text((197, 2), '기존 재질 유지 · 흐름 조정', font=FONT, fill='#f1e8d5')
        draw.line((191, 0, 191, 215), fill='#6f7e73')
        canvas.save(dest / f'{frame:03}.png')
        frames.append(canvas)
    frames[0].save(dest / 'comparison.png', save_all=True, append_images=frames[1:],
                   duration=[33, 33, 34] * 20, loop=0, disposal=0, blend=0)
    p = subprocess.run(['ffmpeg', '-y', '-loglevel', 'error', '-framerate', '30', '-i', str(dest / '%03d.png'),
                        '-c:v', 'libvpx-vp9', '-lossless', '1', '-pix_fmt', 'yuv444p', '-deadline', 'good',
                        '-cpu-used', '4', '-row-mt', '1', '-an', str(dest / 'comparison.webm')],
                       capture_output=True, text=True)
    assert p.returncode == 0, p.stderr
    return dict(kind=kind, name=NAMES[kind], direction=direction, reference=reference, frames=60, fps=30,
                damage=b['damage'], hit_frame=b['hit_frame'], state_equal=True, hit_feedback_equal=True,
                native_size=[384, 216], crop_x=crop_x, material_metrics=b['material_metrics'],
                video=str((dest / 'comparison.webm').relative_to(OUT)),
                image=str((dest / 'comparison.png').relative_to(OUT)))


def main():
    global REPORT
    REPORT = json.loads((OUT / 'native/checks.json').read_text())
    groups = sorted({(r['kind'], r['direction']) for r in REPORT})
    assert len(REPORT) == len(groups) * 3
    jobs = [(k, d, ref) for k, d in groups for ref in ['existing', 'crisp']]
    with ThreadPoolExecutor(max_workers=3) as pool:
        cases = list(pool.map(package_case, jobs))
    (OUT / 'comparisons.json').write_text(json.dumps(cases, indent=2, ensure_ascii=False) + '\n')
    (OUT / 'index.html').write_text((ROOT / 'tools/samples/skill_softness_review.html').read_text())
    before = json.loads((OUT / 'protected-before.json').read_text())
    changed = [p for p, h in before.items() if hashlib.sha256((ROOT / p).read_bytes()).hexdigest() != h]
    assert not changed, changed
    result = dict(native_cases=len(REPORT), comparisons=len(cases), protected_files=len(before),
                  production_files_changed=changed, game_connected=False, state_equal=True, feedback_equal=True,
                  material_checks={f"{r['kind']}-{r['direction']}": r['material_metrics']
                                   for r in REPORT if r['variant'] == 'sample'})
    (OUT / 'qa-summary.json').write_text(json.dumps(result, indent=2) + '\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
