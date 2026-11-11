"""Postprocess a verified Godot Web export into lossless, on-demand bundles."""
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
WASM_FETCH = 'preloader.loadPromise(`${loadPath}.wasm`, size, true)'


def compress(source, name, destination):
    target = destination / f"{name}.pck.gz"
    with source.open('rb') as src, target.open('wb') as out:
        with gzip.GzipFile(filename='', mode='wb', fileobj=out, compresslevel=6, mtime=0) as zipped:
            shutil.copyfileobj(src, zipped, 1024 * 1024)
    with target.open('rb') as file:
        digest = hashlib.file_digest(file, 'sha256').hexdigest()
    renamed = target.with_name(f"{name}-{digest[:16]}.gz")
    target.rename(renamed)
    return {"url": f"content/{renamed.name}", "bytes": renamed.stat().st_size,
            "raw_bytes": source.stat().st_size, "sha256": digest}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    parser.add_argument('--godot', default='godot')
    args = parser.parse_args()
    directory = args.directory.resolve()
    js = (directory / 'index.js').read_text()
    if js.count(WASM_FETCH) != 1:
        raise SystemExit('Pinned Godot Web loader changed; inspect before packaging.')
    html = (directory / 'index.html').read_text()
    begin = html.index('\t\tengine.startGame({')
    end = html.index('\t\t}).then(() => {', begin) + len('\t\t})')
    plan = content_plan()
    original = sum(p.stat().st_size for p in directory.rglob('*') if p.is_file())
    content = directory / 'content'
    if content.exists():
        raise SystemExit('Use a fresh Web export; content directory already exists.')
    content.mkdir()
    with tempfile.TemporaryDirectory(prefix='poke-web-pack-') as temp:
        host = Path(temp) / 'host'
        host.mkdir()
        (host / 'project.godot').touch()
        (Path(temp) / 'plan.json').write_text(json.dumps(plan))
        packs = Path(temp) / 'packs'
        subprocess.run([args.godot, '--headless', '--path', str(host), '--script',
                        str(ROOT / 'tools/web/split_pack.gd'), '--', str(directory / 'index.pck'),
                        str(Path(temp) / 'plan.json'), str(packs)], check=True)
        entries = {p.stem: compress(p, p.stem, content) for p in sorted(packs.glob('*.pck'))}
    boot = entries.pop('boot')
    engine = compress(directory / 'index.wasm', 'engine', content)
    manifest = {"format": 1, "engine": engine, "boot": boot, "packs": entries, "species": plan['species'],
                "startup_species": len(plan['startup_dex'])}
    (directory / 'content-manifest.json').write_text(json.dumps(manifest, separators=(',', ':')))
    script_tag = '<script src="index.js"></script>'
    assert html.count(script_tag) == 1
    html = html[:begin] + '\t\tjourneyContent.start(engine, GODOT_CONFIG)' + html[end:]
    wrapper = js.replace(WASM_FETCH, 'window.journeyContent.wasm()')
    loader = (ROOT / 'tools/web/content_loader.js').read_bytes()
    wrapper_tag = '<script src="index.js?v=' + hashlib.sha256(wrapper.encode()).hexdigest()[:16] + '"></script>'
    loader_tag = '<script src="content-loader.js?v=' + hashlib.sha256(loader).hexdigest()[:16] + '"></script>'
    html = html.replace(script_tag, '<script>window.JOURNEY_CONTENT=' + json.dumps(manifest, separators=(',', ':'))
                        + ';</script>\n\t\t' + loader_tag + '\n\t\t' + wrapper_tag)
    # Version script URLs too: existing visitors can still have the old Web wrapper cached.
    (directory / 'index.js').write_text(wrapper)
    (directory / 'index.html').write_text(html)
    shutil.copyfile(ROOT / 'tools/web/content_loader.js', directory / 'content-loader.js')
    # Full, uncompressed outputs are validated before this step, and never published.
    (directory / 'index.pck').unlink()
    (directory / 'index.wasm').unlink()
    initial = boot['bytes'] + engine['bytes']
    initial += sum((directory / name).stat().st_size for name in ('index.html', 'index.js', 'content-loader.js', 'index.png'))
    playable = initial + entries['world']['bytes'] + entries['actors']['bytes']
    report = {"original_bytes": original, "title_download_bytes": initial, "playable_download_bytes": playable,
              "published_bytes": sum(p.stat().st_size for p in directory.rglob('*') if p.is_file()),
              "startup_species": manifest['startup_species'], "total_species": len(plan['species'])}
    (directory / 'download-sizes.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report))


if __name__ == '__main__':
    main()
