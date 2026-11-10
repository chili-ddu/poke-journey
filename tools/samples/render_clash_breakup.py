"""Export the two isolated clash sample sheets with PixelFX."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
from tempfile import TemporaryDirectory

root = Path(__file__).resolve().parents[2]
repo = root.parent / "pixelfx"
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--flecks", action="store_true")
parser.add_argument("--momentum", action="store_true")
parser.add_argument("--residual-knock", action="store_true")
parser.add_argument("--shimmer", action="store_true")
parser.add_argument("--broken-only", action="store_true")
parser.add_argument("--element-colors", action="store_true")
options = parser.parse_args()
if options.element_colors:
    options.broken_only = True
element_palettes = {
    "fire": ["#b44325", "#ec611e", "#ffa13d"],
    "water": ["#2358a6", "#267fe0", "#60c1f2"],
}
flecks = options.flecks
module = "clash_contact_flecks" if flecks else "clash_breakup"
names = ("skim_water", "skim_claw", "settle_water", "settle_claw") if flecks else ("physical", "elemental")
destination = "flecks" if flecks else "rebound"
if options.momentum or options.residual_knock or options.shimmer or options.broken_only:
    module, names, destination = "clash_momentum", ("fire", "water", "normal"), "momentum"
if options.residual_knock:
    destination = "residual_knock"
arguments = "fit,true" if options.residual_knock else "fit"
if options.shimmer:
    destination, arguments = "shimmer", "fit,true,true"
if options.broken_only:
    destination, arguments = "broken_only", "fit,true,true,true"
if options.element_colors:
    destination = "element_colors"
source = (root / f"tools/samples/{module}.mjs").as_uri()
with TemporaryDirectory(dir=repo / "src/fx", prefix="rebound-") as work, TemporaryDirectory() as rendered:
    folder = Path(work)
    for name in names:
        (folder / f"{name}.js").write_text(
            f'import {{fit}} from "../../core/index.js";\nimport {{{name}}} from "{source}";\n'
            f'export const {{meta,draw}}={name}({arguments});\n')
        fx = f"{folder.name}/{name}"
        palette_args = []
        if options.element_colors and name in element_palettes:
            palette_args = ["--opts", json.dumps({"palette":element_palettes[name]})]
        subprocess.run(["node","tools/render.mjs",fx,*palette_args,"--sheet","--no-actor","--fps","30","--zoom","1","--out",rendered], cwd=repo, check=True)
        subprocess.run(["node","tools/check.mjs",fx], cwd=repo, check=True)
        files = Path(rendered) / fx
        out = root / "docs/projectile_clash" / destination / "art" / name
        out.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(files / f"{name}.png", out / "sheet.png")
        frames = json.loads((files / f"{name}.json").read_text())["frames"]
        (out / "cells.json").write_text(json.dumps([f["frame"] for f in frames]))
