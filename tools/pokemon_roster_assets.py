"""Install pinned PMDCollab originals for the 493-species roster.

Fetch Git blobs in bounded batches (the upstream is too large for a full
checkout). Existing/custom files are immutable. Credits and source hashes
travel with every newly installed original; no animation is invented here.
"""
from pathlib import Path
import argparse
import hashlib
import json
import os
import subprocess
import xml.etree.ElementTree as ET
from PIL import Image
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/pokemon_2x_rollout'
COMMIT = 'e56caec3fda47cbd4b9d2177b3d1bc05f0ff7dc7'


def sha(p):
    return hashlib.sha256(p.read_bytes()).hexdigest()


def fill_legacy_pidgey():
    """Complete the existing custom shiny XML using its verified colour LUT.

    Fourteen already accepted normal/shiny sheets have identical alpha and
    an unambiguous 11-colour mapping. Mouth red occurs only in the absent
    poses: preserve that source colour, explicitly recorded as an exception.
    """
    folder=ROOT/'assets/sprites/0016';lut={};matched=[]
    for source in folder.glob('*-Anim.png'):
        target=folder/'shiny'/source.name
        if not target.exists():continue
        a=np.array(Image.open(source).convert('RGBA'));b=np.array(Image.open(target).convert('RGBA'))
        if a.shape!=b.shape or not np.array_equal(a[...,3],b[...,3]):continue
        values=np.unique(np.concatenate([a[a[...,3]>0,:3],b[a[...,3]>0,:3]],axis=1),axis=0)
        for value in values:
            key=tuple(map(int,value[:3]));color=tuple(map(int,value[3:]))
            assert key not in lut or lut[key]==color,(source,key)
            lut[key]=color
        matched.append(dict(path=str(source.relative_to(ROOT)),sha256=sha(source),shiny_sha256=sha(target)))
    assert len(matched)>=14 and len(lut)>=11
    made=[]
    for source in folder.glob('*-Anim.png'):
        dest=folder/'shiny'/source.name
        if dest.exists():continue
        a=np.array(Image.open(source).convert('RGBA'));b=a.copy()
        colors=set(map(tuple,a[a[...,3]>0,:3]))
        unmapped=colors-set(lut)
        assert unmapped.issubset({(159,0,0)}),(source,unmapped)
        for old,new in lut.items():b[np.all(a[...,:3]==old,axis=-1)&(a[...,3]>0),:3]=new
        Image.fromarray(b).save(dest)
        offsets=source.with_name(source.name.replace('-Anim.png','-Offsets.png'));target=dest.with_name(offsets.name)
        if offsets.exists() and not target.exists():target.write_bytes(offsets.read_bytes())
        made.append(dict(path=str(dest.relative_to(ROOT)),source=str(source.relative_to(ROOT)),source_sha256=sha(source),
            sha256=sha(dest),method='verified_existing_normal_to_shiny_LUT',retained_unmapped_colors=[list(map(int,c)) for c in unmapped]))
    report=OUT/'derived-shiny.json'
    if made:
        report.write_text(json.dumps(dict(species=16,matched_sheets=matched,lut=[dict(source=list(k),shiny=list(v)) for k,v in lut.items()],
            added=made,warning='Unmapped mouth colour #9f0000 retained from the original; these supplemental poses are derived, not upstream shiny originals.'),indent=2)+'\n')
    return len(made)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--cache', type=Path, default=Path('/tmp/poke-original-sprites-src'))
    args = parser.parse_args()
    cache = args.cache
    assert subprocess.check_output(['git', '-C', str(cache), 'rev-parse', 'HEAD'], text=True).strip() == COMMIT
    selected = json.loads((OUT / 'upstream-objects.json').read_text())
    # Fetch only missing objects; this is safe to resume after a network error.
    env = dict(os.environ, GIT_NO_LAZY_FETCH='1')
    # Git 2.43 can lazily fetch during batch-check even with the environment
    # switch. Read pack indexes instead so discovery never fetches per object.
    present = set()
    for index in (cache/'.git/objects/pack').glob('*.idx'):
        with index.open('rb') as inp:
            result = subprocess.run(['git','show-index'], stdin=inp, capture_output=True, text=True, check=True)
        present.update(line.split()[1] for line in result.stdout.splitlines())
    missing = [oid for oid in dict.fromkeys(x[1] for x in selected) if oid not in present]
    for start in range(0, len(missing), 300):
        batch = missing[start:start+300]
        subprocess.run(['git', '-C', str(cache), '-c', 'fetch.negotiationAlgorithm=noop', 'fetch',
            '--quiet', '--no-tags', '--no-write-fetch-head', '--recurse-submodules=no', '--filter=blob:none', 'origin', '--stdin'],
            input='\n'.join(batch)+'\n', text=True, check=True)
        print(f'Original blobs fetched {min(start+300,len(missing))}/{len(missing)}', flush=True)
    reader = subprocess.Popen(['git', '-C', str(cache), 'cat-file', '--batch'], stdin=subprocess.PIPE, stdout=subprocess.PIPE, env=env)
    added = []; preserved = 0
    for source, oid in selected:
        parts = Path(source).parts
        dex = parts[1]
        shiny = len(parts) == 5
        local = ROOT / 'assets/sprites' / dex
        if shiny:
            local /= 'shiny'
        dest = local / parts[-1]
        if dest.exists():
            preserved += 1
            continue
        reader.stdin.write((oid+'\n').encode()); reader.stdin.flush()
        header = reader.stdout.readline().decode().split()
        assert len(header) == 3 and header[1] == 'blob', (source, header)
        size = int(header[2]); data = reader.stdout.read(size)
        assert len(data) == size and reader.stdout.read(1) == b'\n'
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_bytes(data)
        added.append(dict(path=str(dest.relative_to(ROOT)), source=source, git_blob=oid, sha256=hashlib.sha256(data).hexdigest()))
    reader.stdin.close(); reader.wait(); assert reader.returncode == 0
    derived=fill_legacy_pidgey()
    records = []; errors = []
    for dex in range(1, 494):
        for shiny in [False, True]:
            folder = ROOT / 'assets/sprites' / f'{dex:04}'
            if shiny: folder /= 'shiny'
            xml = folder / 'AnimData.xml'
            assert xml.exists() and (folder/'credits.txt').exists(), folder
            nodes = {a.findtext('Name'): a for a in ET.parse(xml).findall('.//Anim')}
            valid = []
            for name, node in nodes.items():
                if node.findtext('CopyOf'): continue
                path = folder / (name+'-Anim.png')
                if not path.exists():
                    errors.append(dict(path=str(path.relative_to(ROOT)), reason='declared_source_missing')); continue
                w,h = int(node.findtext('FrameWidth')), int(node.findtext('FrameHeight'))
                n = len(node.findall('./Durations/Duration'))
                with Image.open(path) as im:
                    if im.width != w*n or im.height % h:
                        errors.append(dict(path=str(path.relative_to(ROOT)), reason='geometry_mismatch', actual=list(im.size), expected_width=w*n)); continue
                valid.append(name)
            assert 'Walk' in valid, folder
            records.append(dict(dex=dex, shiny=shiny, physical_actions=valid, xml_sha256=sha(xml)))
    # Keep an earlier install record when rerunning to validate an existing set.
    report = OUT/'source-install.json'
    prior = json.loads(report.read_text()) if report.exists() else {}
    combined = {x['path']: x for x in prior.get('added_files', [])+added}
    report.write_text(json.dumps(dict(schema='pokemon-original-install/v1', art_source='existing',
        repository='https://github.com/PMDCollab/SpriteCollab', commit=COMMIT,
        species=493, variants=len(records), existing_files_preserved=preserved,
        added_files=list(combined.values()), derived_shiny_report='derived-shiny.json', sets=records, warnings=errors), indent=2)+'\n')
    print(f'Installed {len(added)} original files; {preserved} existing files preserved; {len(records)} normal/shiny sets; {len(errors)} source warnings', flush=True)
    print(f'Supplemental legacy Pidgey shiny poses derived: {derived}; colour exception recorded in derived-shiny.json',flush=True)


if __name__ == '__main__': main()
