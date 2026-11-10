"""Check all added Green parties directly against cached FireRed source."""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / "third_party/pokefirered"


def main():
    data = json.loads((ROOT / "assets/data/rival_progression.json").read_text())
    trainers = (SOURCE / "src/data/trainers.h").read_text()
    parties = (SOURCE / "src/data/trainer_parties.h").read_text()
    moves = {m.replace("_", ""): m for m in json.loads((ROOT / "assets/data/moves.json").read_text())}
    members = 0
    for id, origin in data["origins"].items():
        body = trainers.split("[" + origin["trainer"] + "] = {", 1)[1].split("\n    },", 1)[0]
        assert re.search(r"\.party = \w+\(" + origin["party_id"] + r"\)", body), id
        party = parties.split(origin["party_id"] + "[] = {", 1)[1].split("\n};", 1)[0]
        pairs = [(s.lower(), int(lv)) for lv, s in re.findall(r"\.lvl = (\d+),\s*\.species = SPECIES_(\w+)", party)]
        assert pairs == [(r[0], r[1]) for r in origin["party"]], id
        native_moves = [[moves[m.lower().replace("_", "")] for m in re.findall(r"MOVE_(\w+)", entry) if m != "NONE"] for entry in re.findall(r"\.moves = \{([^}]+)\}", party)]
        if native_moves:
            assert native_moves == [r[2] for r in origin["party"]], id
        assert [int(v) for v in re.findall(r"\.iv = (\d+)", party)] == origin["native_ivs"], id
        members += len(pairs)
    assert len(data["origins"]) == 12 and members == 54
    assert [s["id"] for s in data["stages"]] == ["route22_early", "lavender", "silph", "route22_late"]
    assert all(not s["map"].startswith("pokemon_tower") for s in data["stages"])
    result = {"passed": True, "new_stages": 4, "starter_branches": 3, "native_teams": 12, "native_party_members": members,
              "party_species_levels_moves_ivs_match": True, "tower_encounter_location": "Lavender Town outside the tower"}
    out = ROOT / "docs/rival_progression"
    out.mkdir(exist_ok=True)
    (out / "source_checks.json").write_text(json.dumps(result, indent=2) + "\n")
    print("Native Green source checks passed:", result)


if __name__ == "__main__":
    main()
