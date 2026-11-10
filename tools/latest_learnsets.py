#!/usr/bin/env python3
"""자력기 습득표를 '그 종이 나온 가장 최신 판' 기준으로 바꾼다(사용자 결정 2026-11-02: 밸런스는 나중에).

출처: PokeAPI CSV(third_party/pokeapi/pokemon_moves.csv·pokemon.csv·moves.csv·version_groups.csv, 사용자 승인 출처).
  판 고르기: 레벨업 데이터가 있는 버전 그룹 중 version_groups.order 가 가장 큰 것(스칼렛·바이올렛 → 없으면 BDSP·소드실드·레츠고…).
    Legends 아르세우스는 습득 체계가 달라(레벨 + 숙달) 다른 판이 하나도 없을 때만 쓴다.
  기술 이름: PokeAPI identifier 의 '-' 를 '_' 로 하고, 밑줄을 뺀 꼴이 같은 플래티넘 이름이 있으면 그걸로(smokescreen → smoke_screen,
  dragonbreath 류). 플래티넘 moves.json 에 없는 기술(5세대 이후)도 표에는 둔다 —
  모양(MoveShapes)이 없으면 어차피 배우지 않는다(SpeciesDB.learnable). 진화로 배우는 기술(level 0)은 Lv1 로.
  나머지(종족값·진화·경험치·기술머신)는 플래티넘 그대로. 구현해 둔 기술(거품·용의분노 …)은 남긴다(사용자 2026-11-02).

쓰임: tools/gen_gen4.py 가 species.json 을 만들 때 불러 쓰고, 단독 실행하면 지금 species.json 의 learnset 만 바꾼다.
  python3 tools/latest_learnsets.py            # species.json 갱신 + 바뀐 종 요약
  python3 tools/latest_learnsets.py --show charmander squirtle   # 표만 보여 준다
"""
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
API = ROOT / "third_party" / "pokeapi"
OUT = ROOT / "assets" / "data" / "species.json"
LEVEL_UP = 1          # pokemon_move_methods.csv: 1 = level-up


def _rows(name):
    with (API / name).open(newline="") as f:
        return list(csv.DictReader(f))


def load_latest() -> dict:
    """{도감번호: {"src": 판 identifier, "learnset": [[lv, move], …]}}"""
    order = {int(r["id"]): int(r["order"]) for r in _rows("version_groups.csv")}
    vg_name = {int(r["id"]): r["identifier"] for r in _rows("version_groups.csv")}
    ours = json.loads((ROOT / "assets" / "data" / "moves.json").read_text())
    flat = {k.replace("_", ""): k for k in ours}
    move_name = {}
    for r in _rows("moves.csv"):
        ident = r["identifier"].replace("-", "_")
        move_name[int(r["id"])] = ours and (ident if ident in ours else flat.get(ident.replace("_", ""), ident))
    LAST_RESORT = {"legends-arceus"}
    # 기본 폼만(pokemon.csv is_default) — 도감번호 = species_id
    dex_of = {int(r["id"]): int(r["species_id"]) for r in _rows("pokemon.csv") if r["is_default"] == "1"}
    best = {}           # dex → (order, vg)
    moves = {}          # (dex, vg) → [(level, order, move)]
    for r in _rows("pokemon_moves.csv"):
        if int(r["pokemon_move_method_id"]) != LEVEL_UP:
            continue
        pid = int(r["pokemon_id"])
        if pid not in dex_of:
            continue
        dex = dex_of[pid]
        vg = int(r["version_group_id"])
        moves.setdefault((dex, vg), []).append((max(1, int(r["level"])), int(r["order"] or 0), move_name[int(r["move_id"])]))
        rank = order[vg] - (1000 if vg_name[vg] in LAST_RESORT else 0)
        if dex not in best or rank > best[dex][0]:
            best[dex] = (rank, vg)
    out = {}
    for dex, (_, vg) in best.items():
        seen = set()
        learn = []
        for lv, _o, mv in sorted(moves[(dex, vg)]):
            if (lv, mv) in seen:
                continue
            seen.add((lv, mv))
            learn.append([lv, mv])
        out[dex] = {"src": vg_name[vg], "learnset": learn}
    return out


def apply_latest(species: dict, moves: dict | None = None) -> dict:
    """gen_gen4.py 의 species dict(id → 레코드)에 최신 표를 덮어쓴다. {id: (전 표, 새 표, 판)} 를 돌려준다.
    moves(moves.json dict)를 주면 표에 나오는데 플래티넘에 없는 기술(5세대 이후)을 PokeAPI 값으로 보충한다(extra_moves)."""
    latest = load_latest()
    changed = {}
    for sid, rec in species.items():
        got = latest.get(int(rec["dex"]))
        if got is None:
            continue
        if rec["learnset"] != got["learnset"]:
            changed[sid] = (rec["learnset"], got["learnset"], got["src"])
        rec["learnset"] = got["learnset"]
        rec["learnset_src"] = got["src"]
    if moves is not None:
        need = {mv for rec in species.values() for _lv, mv in rec["learnset"]} - set(moves)
        moves.update(extra_moves(need))
    return changed


def extra_moves(ids: set) -> dict:
    """플래티넘에 없는 기술의 레코드를 PokeAPI 값으로(moves.csv·types.csv·move_flavor_text.csv). 플래티넘 레코드와 같은 키 +
    gen(세대). effect 는 "hit"(부가 효과는 모양(MoveShapes)에 직접 적는다). tm 은 없음(기술머신은 플래티넘 기준)."""
    if not ids:
        return {}
    types = {int(r["id"]): r["identifier"] for r in _rows("types.csv")}
    cls = {1: "status", 2: "physical", 3: "special"}
    desc = {}          # move_id → (vg, 영어 설명): 가장 최신 판
    for r in _rows("move_flavor_text.csv"):
        if r["language_id"] != "9":
            continue
        mid = int(r["move_id"]); vg = int(r["version_group_id"])
        if mid not in desc or vg > desc[mid][0]:
            desc[mid] = (vg, r["flavor_text"].replace("\n", " ").replace("\f", " ").strip())
    out = {}
    for r in _rows("moves.csv"):
        ident = r["identifier"].replace("-", "_")
        if ident not in ids:
            continue
        mid = int(r["id"])
        out[ident] = {
            "name": r["identifier"].replace("-", " ").upper(),
            "type": types[int(r["type_id"])],
            "cat": cls[int(r["damage_class_id"])],
            "power": int(r["power"] or 0), "pp": int(r["pp"] or 0), "accuracy": int(r["accuracy"] or 0),
            "effect": "hit", "effect_chance": int(r["effect_chance"] or 0),
            "desc": desc.get(mid, (0, ""))[1], "tm": None,
            "gen": int(r["generation_id"]),
        }
    return out


def main(argv):
    species = json.loads(OUT.read_text())
    if argv and argv[0] == "--show":
        latest = load_latest()
        for sid in argv[1:]:
            got = latest[int(species[sid]["dex"])]
            print(sid, got["src"], got["learnset"])
        return
    moves_path = ROOT / "assets" / "data" / "moves.json"
    moves = json.loads(moves_path.read_text())
    before = set(moves)
    changed = apply_latest(species, moves)
    OUT.write_text(json.dumps(species, ensure_ascii=False, indent=0, sort_keys=True))
    moves_path.write_text(json.dumps(moves, ensure_ascii=False, indent=0, sort_keys=True))
    print("보충한 기술 %d: %s" % (len(set(moves) - before), sorted(set(moves) - before)[:12]))
    srcs = {}
    for sid, (_a, _b, src) in changed.items():
        srcs[src] = srcs.get(src, 0) + 1
    print("바뀐 종 %d / %d, 판별: %s" % (len(changed), len(species), srcs))
    for sid in ["charmander", "charmeleon", "charizard", "squirtle", "wartortle", "bulbasaur", "ivysaur",
                "rattata", "pidgey", "caterpie", "weedle", "kakuna", "beedrill", "pikachu", "geodude", "sandshrew", "onix"]:
        print("  %-10s [%s] %s" % (sid, species[sid].get("learnset_src", "platinum"), species[sid]["learnset"]))


if __name__ == "__main__":
    main(sys.argv[1:])
