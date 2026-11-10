"""Extract native Cut-tree objects from cached FRLG maps, without map-name lists.

The map baker caches each original map under third_party/pokefirered/data/maps.
Neighbor-map clones point at the same object and must not become extra trees.
Run python3 tools/field_cut_trees.py after adding a map, or pass --check to audit.
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
TP = ROOT / "third_party/pokefirered"
OUT = ROOT / "assets/data/field_cut_trees.json"


def originals():
    trees = {}
    for path in sorted((TP / "data/maps").glob("*/map.json")):
        source = json.loads(path.read_text())
        points = [[obj["x"], obj["y"]]
                  for obj in source.get("object_events", [])
                  if obj.get("type") == "object"
                  and obj.get("graphics_id") == "OBJ_EVENT_GFX_CUT_TREE"]
        if points:
            trees[source["id"].removeprefix("MAP_").lower()] = points
    return trees


def bake():
    trees = originals()
    OUT.write_text(json.dumps(trees, indent=2) + "\n")
    return trees


def main():
    trees = originals()
    if "--check" in sys.argv:
        assert json.loads(OUT.read_text()) == trees, "Cut-tree data differs from the original FRLG objects"
    else:
        bake()
    print(f"Native Cut trees: {sum(map(len, trees.values()))} objects across {len(trees)} areas")


if __name__ == "__main__":
    main()
