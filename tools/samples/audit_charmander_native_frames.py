"""Offline study QA only; does not launch the game or access save files."""
from pathlib import Path
from collections import Counter
import hashlib
import json
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'docs/charmander_native_frames'
SKILLS = Path('/Users/ichihun/.codex/skills')


def run(args, log):
    p = subprocess.run([sys.executable, *map(str, args)], cwd=ROOT, capture_output=True, text=True)
    log.parent.mkdir(exist_ok=True, parents=True)
    log.write_text(json.dumps(dict(command=[sys.executable, *map(str, args)], exit_code=p.returncode,
                                   stdout=p.stdout, stderr=p.stderr), indent=2) + '\n')
    return p.returncode


def main():
    m = json.loads((OUT / 'study.json').read_text())
    flags, calls, rows = [], [], []
    for action, meta in m['actions'].items():
        w, h = meta['size']
        source = np.array(Image.open(ROOT / meta['source']).convert('RGBA'))
        palette = set(map(tuple, source[..., :3][source[..., 3] > 0]))
        for row, direction in enumerate(m['directions']):
            pair = {}
            for variant in ['original', 'added']:
                files = sorted((OUT / 'frames' / action / direction / variant).glob('*.png'))
                frames = [np.array(Image.open(f).convert('RGBA')) for f in files]
                pair[variant] = frames
                assert all(a.shape == (h, w, 4) for a in frames)
                assert all(set(np.unique(a[..., 3])).issubset({0, 255}) for a in frames)
                assert all(set(map(tuple, a[..., :3][a[..., 3] > 0])).issubset(palette) for a in frames)
                dest = OUT / 'forge-qa-v2' / f'{action}-{direction}-{variant}'
                cycle = 'walk' if action == 'walk' else 'none'
                facing = direction if direction in ['left', 'right'] else 'right'
                args = [SKILLS / 'generate2dsprite/scripts/sheet_qc.py', 'frames', '--frames', *files,
                        '--cycle', cycle, '--loop', '--facing', facing, '--game-pixel', '1', '--output-dir', dest]
                code = run(args, OUT / 'logs' / f'qc-{action}-{direction}-{variant}.json')
                calls.append(dict(tool='sheet_qc', action=action, direction=direction, variant=variant, exit_code=code))
                report = json.loads((dest / 'sheet-qc.json').read_text())
                for check in report['checks']:
                    if check['status'] in ['warn', 'fail']:
                        flags.append(dict(action=action, direction=direction, variant=variant,
                                          report=str((dest / 'sheet-qc.json').relative_to(OUT)), **check))
            for k in range(4):
                raw = source[row*h:(row+1)*h, k*w:(k+1)*w]
                assert np.array_equal(raw, pair['original'][k])
                assert np.array_equal(raw, pair['added'][k*2])
            identical = [k for k in [1, 3, 5, 7] if np.array_equal(pair['added'][k], pair['added'][k-1]) or
                         np.array_equal(pair['added'][k], pair['added'][(k+1) % 8])]
            rows.append(dict(action=action, direction=direction,
                original_unique=len({a.tobytes() for a in pair['original']}),
                added_unique=len({a.tobytes() for a in pair['added']}),
                midpoint_identical_to_neighbour=identical,
                changed_midpoints=4-len(identical)))
        assert sum(meta['original_ticks']) == sum(meta['added_ticks'])
        assert list(np.cumsum([0] + meta['original_ticks'][:-1])) == list(np.cumsum([0] + meta['added_ticks'][:-1])[::2])
        for variant in ['original', 'added']:
            frames_dir = OUT / 'frames' / action / 'right' / variant
            ticks = meta[f'{variant}_ticks']
            timing = OUT / 'timing' / f'{action}-{variant}'
            args = [SKILLS / 'video2dsprite/scripts/retime.py', '--frames-dir', frames_dir,
                    '--fps', '60', '--kind', action, '--spans', f'0:{len(ticks)}',
                    '--ticks', ','.join(map(str, ticks)), '--tick-hz', '60', '--policy', 'cycle',
                    '--output-dir', timing]
            code = run(args, OUT / 'logs' / f'retime-{action}-{variant}.json')
            calls.append(dict(tool='retime', action=action, variant=variant, exit_code=code))
            # Expand held frames to a 60 Hz timeline so the Forge reviewer
            # shows source timing rather than assuming uniform key durations.
            expanded = OUT / 'timeline-60hz' / f'{action}-{variant}'
            expanded.mkdir(exist_ok=True, parents=True)
            n = 0
            for file, length in zip(sorted(frames_dir.glob('*.png')), ticks):
                for _ in range(length):
                    (expanded / f'{n:03d}.png').write_bytes(file.read_bytes())
                    n += 1
            args = [SKILLS / 'video2dsprite/scripts/animation_review.py', 'review',
                    '--frames-dir', expanded, '--out-dir', OUT / 'forge-review' / f'{action}-{variant}',
                    '--fps', '60', '--min-cycle', '8', '--max-cycle', str(n), '--preview-size', '128']
            code = run(args, OUT / 'logs' / f'review-{action}-{variant}.json')
            calls.append(dict(tool='animation_review', action=action, variant=variant, exit_code=code))
        gif = Image.open(OUT / f'{action}-comparison.gif')
        total = 0
        for k in range(gif.n_frames):
            gif.seek(k)
            assert gif.size == (384, 216)
            total += gif.info['duration']
        assert total == sum(meta['original_ticks']) * 50
    for path, digest in m['protected_hashes'].items():
        assert hashlib.sha256((ROOT / path).read_bytes()).hexdigest() == digest, path
    summary = dict(source_keys_exact=64, dimensions_and_palette_and_binary_alpha='pass',
                   timings_and_key_onsets='pass', protected_files_unchanged=list(m['protected_hashes']),
                   tools=calls, flag_counts=dict(Counter(f['status'] for f in flags)),
                   flags_by_id=dict(Counter(f['id'] for f in flags)), rows=rows)
    (OUT / 'qa-flags.json').write_text(json.dumps(flags, indent=2) + '\n')
    (OUT / 'qa-summary.json').write_text(json.dumps(summary, indent=2) + '\n')
    print(json.dumps({k: v for k, v in summary.items() if k not in ['tools', 'rows', 'protected_files_unchanged']}))
    print('Tool exits:', dict(Counter((c['tool'], c['exit_code']) for c in calls)))


if __name__ == '__main__':
    main()
