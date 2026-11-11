"""Validate compressed downloads, then mount all bundles in a source-free project."""
from pathlib import Path
import argparse
import gzip
import hashlib
import json
import shutil
import subprocess
import tempfile

from plan_content import content_plan

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    directory = args.directory.resolve()
    manifest = json.loads((directory / 'content-manifest.json').read_text())
    assert manifest['format'] == 1 and len(manifest['species']) == 493
    assert {'world', 'actors'} <= manifest['packs'].keys()
    assert not (directory / 'index.pck').exists() and not (directory / 'index.wasm').exists()
    assert 'journeyContent.start(engine, GODOT_CONFIG)' in (directory / 'index.html').read_text()
    assert 'window.journeyContent.wasm()' in (directory / 'index.js').read_text()
    html = (directory / 'index.html').read_text()
    for script in ('index.js', 'content-loader.js'):
        digest = hashlib.sha256((directory / script).read_bytes()).hexdigest()[:16]
        assert f'src="{script}?v={digest}"' in html, f'Unversioned script: {script}'
    entries = {'boot': manifest['boot'], 'engine': manifest['engine'], **manifest['packs']}
    for groups in manifest['species'].values():
        assert set(groups) <= manifest['packs'].keys(), groups
    with tempfile.TemporaryDirectory(prefix='poke-content-check-') as temp:
        host = Path(temp) / 'host'
        host.mkdir()
        (host / 'project.godot').touch()
        packs = []
        for name, entry in entries.items():
            path = directory / entry['url']
            assert path.is_relative_to(directory / 'content') and path.is_file(), path
            assert path.stat().st_size == entry['bytes'], path
            with path.open('rb') as file:
                assert hashlib.file_digest(file, 'sha256').hexdigest() == entry['sha256'], path
            unpacked = Path(temp) / (name + '.pck')
            with gzip.open(path, 'rb') as src, unpacked.open('wb') as dst:
                shutil.copyfileobj(src, dst)
            assert unpacked.stat().st_size == entry['raw_bytes'], path
            if name == 'engine':
                with unpacked.open('rb') as file:
                    assert file.read(4) == b'\x00asm'
            else:
                packs.append(str(unpacked))
        plan = Path(temp) / 'plan.json'
        plan.write_text(json.dumps(content_plan()))
        subprocess.run([args.godot, '--headless', '--path', str(host), '--script',
                        str(ROOT / 'tools/web/check_startup_pack.gd'), '--', str(plan),
                        *(str(Path(temp) / (name + '.pck')) for name in ('boot', 'world', 'actors'))], check=True)
        subprocess.run([args.godot, '--headless', '--path', str(host), '--script',
                        str(ROOT / 'tools/check_export_pack.gd'), '--', *packs], check=True)
    total = sum(p.stat().st_size for p in directory.rglob('*') if p.is_file())
    if total >= 1_000_000_000:
        raise SystemExit(f'Pages artifact exceeds 1 GB: {total}')
    if any(p.is_symlink() for p in directory.rglob('*')):
        raise SystemExit('Symlinks in Pages artifact')
    report = json.loads((directory / 'download-sizes.json').read_text())
    if report['title_download_bytes'] > 30_000_000:
        raise SystemExit('Initial title download exceeds the 30 MB budget')
    (directory / '.nojekyll').touch()
    print(json.dumps({'compressed_entries_verified': len(entries), 'species': len(manifest['species']), **report}))


if __name__ == '__main__':
    main()
