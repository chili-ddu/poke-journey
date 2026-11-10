"""Extract canonical target IDs for the installed move catalogue."""
import csv
import json
from pathlib import Path

root = Path(__file__).resolve().parents[1]
aliases = dict(smelling_salt="smelling-salts", selfdestruct="self-destruct",
               faint_attack="feint-attack", softboiled="soft-boiled",
               smoke_screen="smokescreen", hi_jump_kick="high-jump-kick")
with (root / "third_party/pokeapi/moves.csv").open() as stream:
    targets = {r["identifier"]: int(r["target_id"]) for r in csv.DictReader(stream)}
moves = json.loads((root / "assets/data/moves.json").read_text())
mapping = {m: targets[aliases.get(m, m.replace("_", "-"))] for m in sorted(moves) if m != "none"}
(root / "assets/data/move_targets.json").write_text(json.dumps(mapping, indent=2)+"\n")
