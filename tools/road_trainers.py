"""Import mainland road first battles, preserving existing encounter IDs.

Resolve map scripts -> TRAINER_* -> gTrainers party pointers. Object graphics
alone do not identify a party (twins, paired trainers and swimmers share art).
Gym leaders, rematches and story encounters are outside the roaming pools.
"""
import json
import re
from pathlib import Path
from frlg_npc import fetch

ROOT = Path(__file__).resolve().parents[1]
MOVE_IDS = json.loads((ROOT/"assets/data/moves.json").read_text())
MOVE_NAMES = {key.replace("_", ""):key for key in MOVE_IDS}
SOURCES = [(f"route{r}", f"Route{r}") for r in range(1, 26) if r != 21]
SOURCES += [("route21_north", "Route21_North"), ("route21_south", "Route21_South"),
            ("viridian_forest", "ViridianForest"), ("mt_moon_1f", "MtMoon_1F"), ("mt_moon_b2f", "MtMoon_B2F")]
CLASS_NAMES = {
    "YOUNGSTER": ("youngster", "YOUNGSTER", "반바지꼬마"),
    "BUG_CATCHER": ("bug_catcher", "BUG CATCHER", "곤충채집소년"),
    "LASS": ("lass", "LASS", "짧은치마"),
    "CAMPER": ("camper", "CAMPER", "캠프보이"),
    "PICNICKER": ("picnicker", "PICNICKER", "피크닉걸"),
    "HIKER": ("hiker", "HIKER", "등산가"),
    "GAMER": ("gamer", "GAMER", "갬블러"),
    "ENGINEER": ("engineer", "ENGINEER", "엔지니어"),
    "SUPER_NERD": ("super_nerd", "SUPER NERD", "이과계의남자"),
    "TEAM_ROCKET": ("rocket", "TEAM ROCKET", "로켓단"),
    "POKEMANIAC": ("poke_maniac", "POKéMANIAC", "포켓몬마니아"),
    "BIKER": ("biker", "BIKER", "폭주족"),
    "CUE_BALL": ("cue_ball", "CUE BALL", "스킨헤드"),
    "FISHERMAN": ("fisherman", "FISHERMAN", "낚시꾼"),
    "BIRD_KEEPER": ("bird_keeper", "BIRD KEEPER", "새조련사"),
    "ROCKER": ("rocker", "ROCKER", "기타리스트"),
    "BEAUTY": ("beauty", "BEAUTY", "아가씨"),
    "TWINS": ("twins", "TWINS", "쌍둥이"),
    "YOUNG_COUPLE": ("young_couple", "YOUNG COUPLE", "러브러브커플"),
    "CRUSH_KIN": ("crush_kin", "CRUSH KIN", "크러시남매"),
    "SIS_AND_BRO": ("sis_and_bro", "SIS AND BRO", "수영남매"),
    "SWIMMER_M": ("swimmer", "SWIMMER", "수영팬티소년"),
    "SWIMMER_F": ("swimmer_f", "SWIMMER", "비키니아가씨"),
}
KO_NAMES = {"Rick":"릭", "Doug":"더그", "Anthony":"앤서니", "Charlie":"찰리", "Sammy":"새미",
            "Jovan":"조반", "Iris":"아이리스", "Miriam":"미리암", "Robby":"로비", "Kent":"켄트",
            "Josh":"조시", "Marcos":"마르코스", **{f"Grunt{i}":"조무래기" for i in range(1, 5)}}


def native_data():
    parties = fetch("src/data/trainer_parties.h").read_text()
    party_blocks = dict(re.findall(r"static const struct \w+ (sParty_\w+)\[\] = \{[ \t]*\n(.*?)^\};", parties, re.S | re.M))
    trainers = fetch("src/data/trainers.h").read_text()
    entries = dict(re.findall(r"\[(TRAINER_\w+)\] = \{(.*?)^    \},", trainers, re.S | re.M))
    return entries, party_blocks


def first_battle(script, blocks):
    visited = set()
    while script not in visited:
        visited.add(script)
        body = blocks[script]
        match = re.search(r"\btrainerbattle\w*\s+(TRAINER_\w+)", body)
        if match:
            return match[1]
        branch = re.search(r"\b(?:goto|call)\s+(\w+)", body)
        assert branch and branch[1] in blocks, (script, body)
        script = branch[1]
    raise AssertionError(f"Cyclic trainer script: {script}")


def party_members(body):
    members, ivs = [], []
    for mon in re.findall(r"\{([^{}]*(?:\.moves\s*=\s*\{[^{}]*\}[^{}]*)?)\}", body, re.S):
        species = re.search(r"\.species\s*=\s*SPECIES_(\w+)", mon)
        level = re.search(r"\.lvl\s*=\s*(\d+)", mon)
        if not species or not level:
            continue
        row = [species[1].lower(), int(level[1])]
        moves = re.search(r"\.moves\s*=\s*\{([^}]+)\}", mon)
        if moves:
            row.append([MOVE_NAMES[m.lower().replace("_", "")] for m in re.findall(r"MOVE_(\w+)", moves[1]) if m != "NONE"])
        members.append(row)
        iv = re.search(r"\.iv\s*=\s*(\d+)", mon)
        ivs.append(int(iv[1]) if iv else 0)
    assert members, body
    return members, ivs


def build():
    native, parties = native_data()
    common = fetch("data/scripts/trainers.inc").read_text()
    trainers, pools, origins, classes = {}, {}, {}, {}
    coverage = {}
    for area, source in SOURCES:
        objects = json.loads(fetch(f"data/maps/{source}/map.json").read_text())["object_events"]
        objects = [o for o in objects if o.get("trainer_type") == "TRAINER_TYPE_NORMAL"]
        coverage[area] = {"source": source, "objects": len(objects), "trainers": [], "fixed": []}
        if not objects:
            continue
        text = common + "\n" + fetch(f"data/maps/{source}/scripts.inc").read_text()
        blocks = dict(re.findall(r"^(\w+)::[^\n]*\n(.*?)(?=^\w+::|\Z)", text, re.M | re.S))
        seen = {}
        for obj in objects:
            constant = first_battle(obj["script"], blocks)
            kind = obj["graphics_id"].removeprefix("OBJ_EVENT_GFX_").lower()
            if constant in seen:
                origins[seen[constant]]["objects"].append(obj["script"])
                origins[seen[constant]]["partner_sprite"] = kind
                if seen[constant] in trainers:
                    trainers[seen[constant]]["partner_sprite"] = kind
                    trainers[seen[constant]]["senders"] = ["lead" if i%2==0 else "partner" for i in range(len(trainers[seen[constant]]["party"]))]
                continue
            raw = native[constant]
            party_id = re.search(r"\.party\s*=\s*\w+\((sParty_\w+)\)", raw)[1]
            party, ivs = party_members(parties[party_id])
            native_class = re.search(r"\.trainerClass\s*=\s*TRAINER_CLASS_(\w+)", raw)[1]
            cls, en, ko = CLASS_NAMES[native_class]
            label = obj["script"].split("_")[-1]
            name = re.search(r'\.trainerName\s*=\s*_\("([^"\n]*)"\)', raw)[1]
            tid = (f"road{area.removeprefix('route')}_{kind}_{label.lower()}" if area.startswith("route") else
                   "bug_catcher_sammy" if label == "Sammy" else
                   f"{area}_{kind}_{label.lower()}" if area.startswith("mt_moon") else f"forest_{kind}_{label.lower()}")
            # Route 4's strong optional opponent already has a fixed authored encounter.
            fixed = area == "route4"
            if fixed:
                tid = "route4_lass_crissy"
            seen[constant] = tid
            classes.setdefault(cls, {"en":en, "ko":ko, "sprite":kind, "eye":"seq_eye_boy"})
            data = {"class":cls, "name":name, "name_ko":KO_NAMES.get(label, "조무래기" if cls=="rocket" else name.title()),
                    "party":party, "sprite":kind, "terrain":1 if kind.endswith("_water") else 0,
                    "arena":"arena_mt_moon" if area.startswith("mt_moon") else "arena_viridian_forest" if area=="viridian_forest" else "arena_route1",
                    "intro":{"ko":["야생 포켓몬이다!\n어디 한번 실력을 볼까?"], "en":["A wild POKéMON!\nLet me see what you can do!"]},
                    "defeat":{"ko":["강하구나! 이번엔 내가 졌어."], "en":["You are strong! You win this time."]},
                    "after":{"ko":["다음에 다시 만나자!"], "en":["See you around!"]}}
            if any(ivs):
                data["ivs"] = [iv*31//255 for iv in ivs]
            origins[tid] = {"area":area, "source":source, "trainer":constant, "party_id":party_id, "party":party,
                            "native_ivs":ivs, "double_battle":bool(re.search(r"\.doubleBattle\s*=\s*TRUE",raw)),
                            "sprite":kind, "terrain":data["terrain"], "objects":[obj["script"]]}
            coverage[area]["fixed" if fixed else "trainers"].append(tid)
            if fixed:
                continue
            trainers[tid] = data
            pools.setdefault(area, []).append(tid)
    info = fetch("src/data/object_events/object_event_graphics_info.h").read_text()
    blocks = {n.removeprefix("gObjectEventGraphicsInfo_").replace("_", "").lower():b
              for n,b in re.findall(r"const struct ObjectEventGraphicsInfo (\w+) = \{(.*?)\n\};", info, re.S)}
    sprites = {t[key] for t in trainers.values() for key in ["sprite", "partner_sprite"] if key in t}
    npcs = {}
    for sprite in sorted(sprites):
        body = blocks[sprite.replace("_", "")]
        npcs[sprite] = {"frame":[int(re.search(r"\.width = (\d+)",body)[1]), int(re.search(r"\.height = (\d+)",body)[1])],
                        "palette":re.search(r"\.paletteTag = OBJ_EVENT_PAL_TAG_(\w+)",body)[1].lower()}
    return trainers, pools, classes, {"source":"pret/pokefirered", "coverage":coverage, "origins":origins, "npcs":npcs}


def main():
    trainers, pools, classes, manifest = build()
    text = 'extends RefCounted\n# Generated by tools/road_trainers.py; native first battles, no rematches.\n'
    for name, value in [("TRAINERS",trainers), ("POOLS",pools), ("CLASSES",classes)]:
        text += "const "+name+" := "+json.dumps(value, ensure_ascii=False, indent=2)+"\n"
    text += "const SPRITE_FRAMES := "+json.dumps({s:cfg["frame"] for s,cfg in manifest["npcs"].items()})+"\n"
    (ROOT/"scripts/data/road_trainer_db.gd").write_text(text)
    (ROOT/"assets/data/road_trainers.json").write_text(json.dumps(manifest, ensure_ascii=False, indent=2)+"\n")
    print({area:len(ids) for area,ids in pools.items()})
    print(f"{len(trainers)} roaming trainers; fixed encounters preserved; {len(classes)} classes")


if __name__ == "__main__":
    main()
