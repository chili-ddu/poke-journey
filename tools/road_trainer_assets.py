"""Fill missing native road trainer/party art and cries; preserve existing assets."""
import json
from pathlib import Path
from PIL import Image
import frlg_npc
import kanto_wild_assets
import plat_sfx

ROOT = Path(__file__).resolve().parents[1]


def main():
    data = json.loads((ROOT/"assets/data/road_trainers.json").read_text())
    species = json.loads((ROOT/"assets/data/species.json").read_text())
    names = {mon[0] for entry in data["origins"].values() for mon in entry["party"]}
    dexes = sorted(species[name]["dex"] for name in names)
    kanto_wild_assets.main(dexes)
    for sprite, cfg in data["npcs"].items():
        target = ROOT/"assets/npcs"/(sprite+".png")
        if target.exists():
            continue
        source = Image.open(frlg_npc.fetch("graphics/object_events/pics/people/"+sprite+".png"))
        palette = frlg_npc.jasc(frlg_npc.fetch("graphics/object_events/palettes/"+cfg["palette"]+".pal"))
        assert source.mode == "P", sprite
        output = Image.new("RGBA", source.size)
        output.putdata([palette[i % len(palette)]+(255,) if i % 16 else (0,0,0,0) for i in source.getdata()])
        output.save(target)
        print("Native trainer", sprite, "frame", cfg["frame"], flush=True)
    sd = plat_sfx.pm.Sdat(plat_sfx.pm.SDAT)
    plat_sfx.cries(sd, missing_only=True)
    print("Road trainer/party assets ready; existing art and audio preserved", flush=True)


if __name__ == "__main__":
    main()
