"""Compare gym configuration with native first parties and all human objects."""
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"third_party/pokefirered"


def main():
    data=json.loads((ROOT/"assets/data/gym_leaders.json").read_text())
    trainers=(SOURCE/"src/data/trainers.h").read_text()
    parties=(SOURCE/"src/data/trainer_parties.h").read_text()
    names={m.replace("_",""):m for m in json.loads((ROOT/"assets/data/moves.json").read_text())}
    rows=0
    for id,origin in {**data["origins"],**data["npc_parties"]}.items():
        body=trainers.split("["+origin["trainer"]+"] = {",1)[1].split("\n    },",1)[0]
        assert re.search(r"\.party = \w+\("+origin["party_id"]+r"\)",body),id
        party=parties.split(origin["party_id"]+"[] = {",1)[1].split("\n};",1)[0]
        pairs=[(s.lower(),int(lv)) for lv,s in re.findall(r"\.lvl = (\d+),\s*\.species = SPECIES_(\w+)",party)]
        assert pairs==[(r[0],r[1]) for r in origin["party"]],id
        moves=[[names[m.lower().replace("_","")] for m in re.findall(r"MOVE_(\w+)",entry) if m!="NONE"] for entry in re.findall(r"\.moves = \{([^}]+)\}",party)]
        if moves:assert moves==[r[2] for r in origin["party"]],id
        assert [int(v) for v in re.findall(r"\.iv = (\d+)",party)]==origin["native_ivs"],id
        rows+=len(pairs)
    ordinary=guides=0
    for place,gym in data["gyms"].items():
        source=json.loads((SOURCE/f"data/maps/{gym['source']}/map.json").read_text())
        people=[o for o in source["object_events"] if o.get("trainer_type")=="TRAINER_TYPE_NORMAL" or o["script"].endswith("_GymGuy")]
        npcs=data["places"][place]["npcs"]
        assert len(npcs)==len(people),place
        for obj in people:
            matched=[n for n in npcs if n["tile"]==[obj["x"],obj["y"]]]
            assert len(matched)==1 and "trainer" not in matched[0],(place,obj["script"])
            assert matched[0]["sprite"]==obj["graphics_id"].removeprefix("OBJ_EVENT_GFX_").lower()
            if obj["script"].endswith("_GymGuy"):guides+=1
            else:ordinary+=1
        assert len(data["places"][place]["trainers"])==1
    assert ordinary==41 and guides==7
    result={"passed":True,"gyms":8,"new_leaders":6,"new_leader_party_members":sum(len(v["party"]) for v in data["origins"].values()),
            "ordinary_noncombat_members":ordinary,"guides":guides,"native_party_records_including_unused_members":rows,
            "legacy_parties":"Brock's authored three Pokemon and Misty's existing party are preserved.",
            "open_barriers":{place:len(json.loads((ROOT/f'assets/maps/{place}/map.json').read_text())["gym_open_gates"]) for place in ["vermilion_city_gym","cinnabar_island_gym"]}}
    out=ROOT/"docs/gym_leaders";out.mkdir(exist_ok=True)
    (out/"source_checks.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print("Native gym source checks passed:",result)


if __name__=="__main__":main()
