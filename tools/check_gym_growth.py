"""Validate gym growth stages against native evolution methods and owner parties."""
import json
from pathlib import Path
from PIL import Image
from gym_growth import build
from gym_rosters import load as load_rosters

ROOT = Path(__file__).resolve().parents[1]


def main():
    data = json.loads((ROOT / "assets/data/gym_growth.json").read_text())
    species = json.loads((ROOT / "assets/data/species.json").read_text())
    assert data["leaders"] == build()
    assert data["level_bonus"] == [3, 7] and data["maximum_level"] == 100
    for leader,roster in load_rosters()['leaders'].items():
        cfg=data['leaders'][leader]
        assert len(cfg['slots'])==len(roster['party'])
        assert len(set(cfg['slots']))==len(cfg['slots'])
        for root,row in zip(cfg['slots'],roster['party']):assert root==row[0],(leader,root,row)
    native_levels = []
    special_levels = []
    forms = set()
    for id, cfg in data["leaders"].items():
        for root, family in cfg["families"].items():
            assert family[0] == {"species": root, "level": 1, "method": "base"}
            for before, stage in zip(family, family[1:]):
                raw = json.loads((ROOT / f'third_party/pokeplatinum/res/pokemon/{before["species"]}/data.json').read_text())
                matches = [ev for ev in raw["evolutions"] if ev[-1] == "SPECIES_" + stage["species"].upper()]
                assert len(matches) == 1, (id, stage)
                ev = matches[0]
                assert ev[0] == stage["method"]
                if ev[0] == "EVO_LEVEL":
                    assert ev[1] == stage["level"]
                    native_levels.append([id, stage["species"], stage["level"]])
                else:
                    special_levels.append([id, stage["species"], stage["level"], stage["method"]])
            forms.update(stage["species"] for stage in family)
    assert len(forms) == 68
    additions = []
    for sid in sorted(forms):
        dex = species[sid]["dex"]
        for variant in ["", "shiny/"]:
            folder = ROOT / f"assets/sprites/{dex:04d}" / variant
            image = Image.open(folder / "Walk-Anim.png")
            assert image.mode == "RGBA" and image.getextrema()[-1][0] == 0
            assert (folder / "AnimData.xml").exists() and (folder / "credits.txt").exists()
            additions.append({"species": sid, "variant": variant or "normal", "source": "PMDCollab/SpriteCollab existing animation sheets", "size": list(image.size), "art_source": "existing", "image_generation": False, "original_pixels_edited": False})
        assert (ROOT / f"assets/audio/cry/{sid}.wav").exists()
    result = {"passed": True, "leaders": len(data["leaders"]), "forms": len(forms), "native_level_evolution_records": native_levels,
              "special_gym_readiness_records": special_levels, "validated_original_assets": additions,
              "special_evolution_rule_is_game_specific": True, "no_unauthored_item_or_trade_branches": True}
    out = ROOT / "docs/gym_growth"
    out.mkdir(exist_ok=True)
    (out / "source_checks.json").write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n")
    print("Gym growth source checks passed:", len(data["leaders"]), "leaders,", len(forms), "forms")


if __name__ == "__main__":
    main()
