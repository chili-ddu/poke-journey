"""Render and check the nine review layers with the adjacent PixelFX checkout."""
from pathlib import Path
from tempfile import TemporaryDirectory
import argparse
import json
import subprocess
root = Path(__file__).resolve().parents[2]
checkout = root.parent / "pixelfx"
out = root / "docs/charmander_sv_forward/sheets"
source = (root / "tools/samples/charmander_sv_fx.mjs").as_uri()
moves = "scratch slash fire_fang smoke_screen dragon_breath flamethrower fire_spin inferno flare_blitz".split()
parser = argparse.ArgumentParser(description=__doc__)
variants = parser.add_mutually_exclusive_group()
variants.add_argument("--raised-finish", action="store_true")
variants.add_argument("--descending-cuts", action="store_true")
variants.add_argument("--outward-cuts", action="store_true")
args = parser.parse_args()
descending = args.descending_cuts or args.raised_finish
outward = args.outward_cuts or descending
if outward:
    moves = ["scratch", "slash"]
    folder_name = "charmander_downstroke" if descending else "charmander_ember_family"
    review = root / "docs" / folder_name
    out = (review / "raised" if args.raised_finish else review) / "sheets"
# The CLI discovers effects under src/fx. Stage only these modules for this run.
with TemporaryDirectory(prefix="sv-study-", dir=checkout/"src/fx") as tmp:
    folder = Path(tmp)
    ids = []
    for move in moves:
        wrapper = folder / (move.replace("_", "-") + ".js")
        tip_lift = {"scratch": 14, "slash": 20}[move] if args.raised_finish else 0
        wrapper.write_text(f'import {{fit}} from "../../core/index.js";\nimport {{effect}} from "{source}";\nexport const {{meta,draw}}=effect("{move}",fit,{json.dumps(outward)},{json.dumps(descending)},{tip_lift});\n')
        ids.append(folder.name + "/" + wrapper.stem)
    with TemporaryDirectory() as rendered:
        subprocess.run(["node","tools/render.mjs",*ids,"--sheet","--no-actor","--fps","30","--max","1.4","--zoom","1","--out",rendered],cwd=checkout,check=True)
        for move, ident in zip(moves,ids):
            dest = out / move
            dest.mkdir(parents=True,exist_ok=True)
            path = Path(rendered)/ident
            (dest/"sheet.png").write_bytes((path/(path.name+".png")).read_bytes())
            metadata = json.loads((path/(path.name+".json")).read_text())
            metadata["meta"]["image"] = "sheet.png"
            metadata["meta"]["pixelfx"]["id"] = "charmander-sv/" + move
            (dest/"sheet.json").write_text(json.dumps(metadata, indent=1) + "\n")
    subprocess.run(["node","tools/check.mjs",*ids],cwd=checkout,check=True)
