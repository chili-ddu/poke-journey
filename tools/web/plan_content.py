"""Keep every asset, but preload only species referenced by current game content.

The first 151 are always available. Other species remain downloadable, including
whole evolution families for imported saves. Rebuild the plan on every export.
"""
from pathlib import Path
import json
import re

ROOT = Path(__file__).resolve().parents[2]
METADATA = {"species.json", "abilities.json", "pokemon_sizes.json", "names_ko.json"}


def content_plan(root=ROOT):
    species = json.loads((root / "assets/data/species.json").read_text())
    used = {sid for sid, entry in species.items() if entry["dex"] <= 151}
    for folder in ("scripts", "assets/data", "assets/maps"):
        for path in (root / folder).rglob("*"):
            if path.suffix not in (".gd", ".json") or path.name in METADATA:
                continue
            used.update(set(re.findall(r'''["']([a-z][a-z0-9_-]*)["']''', path.read_text())) & species.keys())
    graph = {sid: {sid} for sid in species}
    for sid, entry in species.items():
        to = (entry.get("evolve") or {}).get("to")
        if to:
            graph[sid].add(to)
            graph[to].add(sid)

    def family(sid):
        found, pending = set(), [sid]
        while pending:
            member = pending.pop()
            if member not in found:
                found.add(member)
                pending.extend(graph[member] - found)
        return found

    used = set().union(*(family(sid) for sid in used))
    startup = sorted(species[sid]["dex"] for sid in used)
    groups = {sid: sorted({"actors" if member in used else f"pokemon-{species[member]['dex']:04d}"
                          for member in family(sid)}) for sid in species}
    return {"format": 1, "startup_dex": startup, "species": groups}


if __name__ == "__main__":
    import sys
    plan = content_plan()
    Path(sys.argv[1]).write_text(json.dumps(plan, separators=(",", ":")))
    print(json.dumps({"startup_species": len(plan["startup_dex"]), "total_species": len(plan["species"])}))
