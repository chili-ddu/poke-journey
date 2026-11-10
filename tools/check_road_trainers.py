"""Verify generated encounters against cached native scripts and party records."""
import json
import re
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/"third_party/pokefirered"


def main():
    data=json.loads((ROOT/"assets/data/road_trainers.json").read_text())
    generated=(ROOT/"scripts/data/road_trainer_db.gd").read_text()
    trainers=json.loads(generated.split("const TRAINERS := ")[1].split("\nconst POOLS :=")[0])
    common=(SOURCE/"data/scripts/trainers.inc").read_text()
    parties=(SOURCE/"src/data/trainer_parties.h").read_text()
    metadata=(SOURCE/"src/data/trainers.h").read_text()
    move_names={k.replace("_",""):k for k in json.loads((ROOT/"assets/data/moves.json").read_text())}
    seen=set();members=0
    for id,record in data["origins"].items():
        assert record["trainer"] not in seen,record["trainer"]
        seen.add(record["trainer"])
        scripts_text=common+"\n"+(SOURCE/f"data/maps/{record['source']}/scripts.inc").read_text()
        for label in record["objects"]:
            script=scripts_text.split(label+"::",1)[1].split("\n\n",1)[0]
            initial=re.search(r"trainerbattle_(?:single|double)\s+(TRAINER_\w+)",script)
            assert initial and initial[1]==record["trainer"],label
        trainer=metadata.split("["+record["trainer"]+"] = {",1)[1].split("\n    },",1)[0]
        assert re.search(r"\.party = \w+\("+record["party_id"]+r"\)",trainer),id
        body=parties.split(record["party_id"]+"[] = {",1)[1].split("\n};",1)[0]
        native_pairs=[(s.lower(),int(lv)) for lv,s in re.findall(r"\.lvl = (\d+),\s*\.species = SPECIES_(\w+)",body)]
        assert native_pairs==[(r[0],r[1]) for r in record["party"]],id
        native_moves=[[move_names[m.lower().replace("_","")] for m in re.findall(r"MOVE_(\w+)",text) if m!="NONE"] for text in re.findall(r"\.moves = \{([^}]+)\}",body)]
        if native_moves:assert native_moves==[row[2] for row in record["party"]],id
        if id not in trainers:continue # Existing fixed Route 4 opponent.
        tr=trainers[id];assert tr["party"]==record["party"],id
        if any(record["native_ivs"]):assert tr["ivs"]==[v*31//255 for v in record["native_ivs"]],id
        assert tr["terrain"]==int(tr["sprite"].endswith("_water")),id
        members+=len(tr["party"])
    for area,cfg in data["coverage"].items():
        objects=json.loads((SOURCE/f"data/maps/{cfg['source']}/map.json").read_text())["object_events"]
        objects=[o for o in objects if o.get("trainer_type")=="TRAINER_TYPE_NORMAL"]
        assert cfg["objects"]==len(objects),area
        scripts={o["script"] for o in objects}
        included={label for id in cfg["trainers"]+cfg["fixed"] for label in data["origins"][id]["objects"]}
        assert scripts==included,area
    result={"passed":True,"roaming_teams":len(trainers),"party_members":members,"fixed_teams":len(seen)-len(trainers),
            "native_objects":sum(c["objects"] for c in data["coverage"].values()),
            "coverage":{a:{"teams":len(c["trainers"]),"fixed":len(c["fixed"]),"objects":c["objects"]} for a,c in data["coverage"].items()}}
    out=ROOT/"docs/road_trainers";out.mkdir(exist_ok=True)
    (out/"source_checks.json").write_text(json.dumps(result,ensure_ascii=False,indent=2)+"\n")
    print(f"Native scripts, unique teams, first-battle parties, custom moves, IVs and full source-object coverage passed: {len(trainers)} teams, {members} party members")


if __name__=="__main__":main()
