"""Read-only resource/UV audit for every generated native HD-2D map."""
import json
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
results, issues = [], []
for folder in sorted((ROOT / "assets/maps").iterdir()):
    cards_file = folder / "hd2d_cards.json"
    if not cards_file.exists():
        continue
    cards = json.loads(cards_file.read_text())
    record = {"map": folder.name, "cards": len(cards.get("cards", []))}
    for name in ["map.json", "hd2d_atlas.png"]:
        if not (folder / name).exists():
            issues.append({"map": folder.name, "missing": name})
    floor = folder / "hd2d_floor.png"
    if not floor.exists():
        floor = folder / "bottom.png"
    if not floor.exists():
        issues.append({"map": folder.name, "missing": "floor"})
    atlas_path = folder / "hd2d_atlas.png"
    if atlas_path.exists():
        with Image.open(atlas_path) as image:
            width, height = image.size
            image.verify()
        for index, card in enumerate(cards.get("cards", [])):
            x, y, tile_height = card[3], card[4], card[2]
            tile = cards.get("tile", 16)
            if x < 0 or y < 0 or x + tile > width or y + tile_height * tile > height:
                issues.append({"map": folder.name, "card": index, "invalid_uv": [x, y, tile_height]})
        record["atlas"] = [width, height]
    if floor.exists():
        with Image.open(floor) as image:
            record["floor"] = list(image.size)
            image.verify()
    results.append(record)
output = ROOT / "docs/map_item_review"
output.mkdir(parents=True, exist_ok=True)
report = {"maps_checked": len(results), "cards_checked": sum(r["cards"] for r in results),
          "issues": issues, "maps": results}
(output / "resource-audit.json").write_text(json.dumps(report, indent=2) + "\n")
print(json.dumps({k: report[k] for k in ["maps_checked", "cards_checked", "issues"]}))
raise SystemExit(bool(issues))
