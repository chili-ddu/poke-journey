from pathlib import Path
from tempfile import TemporaryDirectory
import subprocess,json,shutil
root=Path(__file__).resolve().parents[2]
repo=root.parent/'pixelfx'
out=root/'docs/projectile_clash/fragments'
out.mkdir(exist_ok=True)
with TemporaryDirectory(dir=repo/'src/fx',prefix='clash-study-') as work, TemporaryDirectory() as rendered:
    folder=Path(work)
    source=(root/'tools/samples/clash_fragments.mjs').as_uri()
    (folder/'elemental.js').write_text(f'import {{fit}} from "../../core/index.js";\nimport {{fragments}} from "{source}";\nexport const {{meta,draw}}=fragments(fit);\n')
    fx=folder.name+'/elemental'
    subprocess.run(['node','tools/render.mjs',fx,'--sheet','--no-actor','--fps','30','--zoom','1','--out',rendered],cwd=repo,check=True)
    subprocess.run(['node','tools/check.mjs',fx],cwd=repo,check=True)
    files=Path(rendered)/fx
    shutil.copyfile(files/'elemental.png',out/'sheet.png')
    meta=json.loads((files/'elemental.json').read_text())
    (out/'cells.json').write_text(json.dumps([frame['frame'] for frame in meta['frames']]))
