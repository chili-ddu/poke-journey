"""Read-only existing-art audit using installed Agent Sprite Forge QA."""
from pathlib import Path
import hashlib
import json
import subprocess
import sys
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/sprite_forge_audit'
OUT.mkdir(parents=True, exist_ok=True)
SKILL = Path.home() / '.codex/skills/generate2dsprite'
ANIMS = 'Walk Idle Hurt Attack Strike Jab Shoot Charge Hop Trip Sleep HitGround Swing TailWhip Eat Dance Rotate Withdraw Double Slice SpAttack FlapAround Hover'.split()
inventory = []
for xml in sorted((ROOT / 'assets/sprites').glob('[0-9][0-9][0-9][0-9]/AnimData.xml')):
    records = {a.findtext('Name'): a for a in ET.parse(xml).findall('.//Anim')}
    actions = {}
    for name in ANIMS:
        if name not in records:
            continue
        source = records[name]
        visited = set()
        while source.findtext('CopyOf'):
            target = source.findtext('CopyOf')
            if target in visited or target not in records:
                raise ValueError(f'{xml}: invalid CopyOf {name}')
            visited.add(target)
            source = records[target]
        png = xml.parent / (source.findtext('Name') + '-Anim.png')
        if not png.exists():
            continue
        fw, fh = int(source.findtext('FrameWidth')), int(source.findtext('FrameHeight'))
        ticks = [int(d.text) for d in source.findall('./Durations/Duration')]
        with Image.open(png) as image:
            width, height = image.size
            alpha = np.asarray(image.convert('RGBA'))[:, :, 3]
        rows = height // fh
        if width % fw or height % fh or width < fw * len(ticks):
            raise ValueError(f'{png}: cell geometry/duration mismatch')
        border = []
        for row in range(rows):
            for frame in range(len(ticks)):
                a = alpha[row*fh:(row+1)*fh, frame*fw:(frame+1)*fw]
                if (a[0] > 127).any() or (a[-1] > 127).any() or (a[:, 0] > 127).any() or (a[:, -1] > 127).any():
                    border.append([row, frame])
        actions[name] = {'source': str(png.relative_to(ROOT)), 'cell': [fw, fh],
                         'frames': len(ticks), 'rows': rows, 'ticks': ticks,
                         'seconds': sum(ticks)/60, 'border_touch_cells': border}
    inventory.append({'dex': int(xml.parent.name), 'actions': actions})
(OUT / 'source-inventory.json').write_text(json.dumps({'art_source': 'existing', 'species': inventory}, indent=2)+'\n')

jobs = [(1, 'Walk'), (4, 'Walk'), (7, 'Walk'), (25, 'Walk'),
        (4, 'Idle'), (4, 'Strike'), (4, 'Hop'), (4, 'Hurt')]
by_dex = {s['dex']: s for s in inventory}
prepared = []
for dex, action in jobs:
    meta = by_dex[dex]['actions'][action]
    path = ROOT / meta['source']
    folder = OUT / 'existing-frames' / f'{dex:04d}-{action.lower()}-right'
    folder.mkdir(parents=True, exist_ok=True)
    image = Image.open(path).convert('RGBA')
    fw, fh = meta['cell']
    # Preserve the source canvas. Merge Scratch's intentional held keys into
    # duration metadata rather than presenting them as extra unique drawings.
    indices = [0, 2, 3, 4, 1] if action == 'Strike' else list(range(meta['frames']))
    files = []
    for i, source_index in enumerate(indices):
        file = folder / f'frame-{i:03d}.png'
        image.crop((source_index*fw, 2*fh, (source_index+1)*fw, 3*fh)).save(file)
        files.append(file)
    prepared.append({'dex': dex, 'action': action, 'files': files,
                     'source': meta['source'], 'source_sha256': hashlib.sha256(path.read_bytes()).hexdigest(),
                     'source_indices': indices, 'ticks': meta['ticks']})

def run(job):
    output = OUT / 'forge-qa-v1' / f"{job['dex']:04d}-{job['action'].lower()}"
    command = [sys.executable, str(SKILL/'scripts/sheet_qc.py'), 'frames',
               '--frames', *map(str, job['files']), '--key', 'none', '--facing', 'right',
               '--cycle', 'walk' if job['action'] == 'Walk' else 'none',
               '--loop' if job['action'] in ['Walk', 'Idle'] else '--no-loop',
               '--output-dir', str(output)]
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    (OUT / f"{job['dex']:04d}-{job['action'].lower()}-forge.log").write_text(result.stdout+result.stderr)
    if not (output/'sheet-qc.json').exists():
        raise RuntimeError(result.stdout+result.stderr)
    return {**{k:v for k,v in job.items() if k!='files'}, 'exit_code': result.returncode,
            'report': str((output/'sheet-qc.json').relative_to(ROOT))}

with ThreadPoolExecutor(max_workers=2) as executor:
    results = list(executor.map(run, prepared))
(OUT/'forge-jobs.json').write_text(json.dumps(results, indent=2)+'\n')
print(json.dumps({'species': len(inventory), 'actions': sum(len(s['actions']) for s in inventory),
                  'forge_reports': len(results), 'art_source': 'existing',
                  'generation_calls': 0}))
