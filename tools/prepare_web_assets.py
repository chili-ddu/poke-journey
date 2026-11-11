"""Skip verified unused/redundant imports in the disposable Actions checkout.

The original assets remain in Git. Runtime HGSS models/textures are exported
as raw files by addons/runtime_assets, not loaded as imported Godot scenes.
"""
from pathlib import Path
import argparse
import json
import os

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    if args.apply and os.environ.get("GITHUB_ACTIONS") != "true":
        raise SystemExit("Asset removal is only allowed in the disposable Actions checkout; omit --apply for a dry run.")
    catalog = json.loads((ROOT / "assets/smooth/manifest.json").read_text())
    legacy = set()
    for source, entry in catalog.items():
        if source.startswith("res://assets/sprites/"):
            path = ROOT / entry["sheet"].removeprefix("res://")
            if not path.is_relative_to(ROOT / "assets/smooth"):
                raise SystemExit(f"Unexpected legacy sheet path: {path}")
            legacy.add(path)
    previews = set((ROOT / "assets/maps").rglob("preview.png"))
    redundant_model_imports = [
        ROOT / "assets/maps/johto_hgss/models",
        ROOT / "assets/maps/hgss_pallet_sample/models",
    ]
    active = {entry["sheet"] for source, entry in catalog.items() if not source.startswith("res://assets/sprites/")}
    assert not active.intersection("res://" + str(p.relative_to(ROOT)) for p in legacy)
    removed_bytes = sum(p.stat().st_size for p in legacy | previews if p.exists())
    if args.apply:
        for path in legacy | previews:
            path.unlink(missing_ok=True)
            Path(str(path) + ".import").unlink(missing_ok=True)
        for directory in redundant_model_imports:
            (directory / ".gdignore").write_text("# Runtime reads original GLB/PNG files; export plugin packages them.\n")
    print(json.dumps({"applied": args.apply, "legacy_sheets": len(legacy), "map_previews": len(previews),
                      "unused_source_bytes": removed_bytes,
                      "raw_model_directories": [str(p.relative_to(ROOT)) for p in redundant_model_imports]}))


if __name__ == "__main__":
    main()
