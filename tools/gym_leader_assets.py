"""Import native gym NPCs, first-party Pokemon, cries and leader cut-ins."""
import json
import re
from PIL import Image
from frlg_npc import ROOT,fetch,jasc
import kanto_wild_assets
import plat_sfx
import plat_encounter
from gym_leaders import GYMS


def main():
    data=json.loads((ROOT/"assets/data/gym_leaders.json").read_text())
    species=json.loads((ROOT/"assets/data/species.json").read_text())
    names={row[0] for entry in data["origins"].values() for row in entry["party"]}
    kanto_wild_assets.main(sorted(species[s]["dex"] for s in names))
    sprites={npc["sprite"] for place in data["places"].values() for npc in place.get("npcs",[])}
    sprites.update(g[2] for g in GYMS)
    text=fetch("src/data/object_events/object_event_graphics_info.h").read_text()
    blocks={n.removeprefix("gObjectEventGraphicsInfo_").replace("_","").lower():b for n,b in re.findall(r"const struct ObjectEventGraphicsInfo (\w+) = \{(.*?)\n\};",text,re.S)}
    for sprite in sorted(sprites):
        target=ROOT/"assets/npcs"/(sprite+".png")
        if target.exists():continue
        body=blocks[sprite.replace("_","")]
        palette=re.search(r"\.paletteTag = OBJ_EVENT_PAL_TAG_(\w+)",body)[1].lower()
        source=Image.open(fetch("graphics/object_events/pics/people/"+sprite+".png"))
        pal=jasc(fetch("graphics/object_events/palettes/"+palette+".pal"))
        output=Image.new("RGBA",source.size)
        output.putdata([pal[i%len(pal)]+(255,) if i%16 else (0,0,0,0) for i in source.getdata()])
        output.save(target);print("Gym NPC",sprite,flush=True)
    for _,_,slug,_,_,_,color,band in GYMS[2:]:
        plat_encounter.leader(slug,band,color)
    sd=plat_sfx.pm.Sdat(plat_sfx.pm.SDAT)
    plat_sfx.cries(sd,missing_only=True)
    print("Gym native sprites, cries and cut-ins ready",flush=True)


if __name__=="__main__":main()
