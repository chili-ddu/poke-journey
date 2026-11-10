"""플래티넘 디컴파일 JSON → 게임 데이터 (1단계, docs/plan-gen4.md).

  python3 -I tools/gen_gen4.py

읽는 곳: third_party/pokeplatinum/ (tools/plat_fetch.py 로 받은 것)
쓰는 곳: assets/data/species.json, assets/data/moves.json, assets/data/exp_tables.json

species.json  { id: {name, dex, types, base{hp,atk,def,spa,spd,spe}, exp, weight(kg), growth, evolve{to,level}|null,
                     learnset[[level, move_id]…](원작 순서), tms[TM01…], tutor[move_id…]} }   — 전국 도감 전부
moves.json    { id: {name, type, cat, power, accuracy, pp, effect, effect_chance, desc, tm}}  — 기술 전부
exp_tables.json { growth: [레벨 0..100 누적 경험치] }

액션 게임용 모양(사거리·탄·도트 동작)은 원작에 없다. scripts/data/move_shapes.gd 가 기술 id 별로 덧씌운다.
id 는 pret 폴더 이름 그대로(smoke_screen, thunder_shock …).
"""
import csv
import json
import sys
sys.path.insert(0, str(__import__("pathlib").Path(__file__).resolve().parent))
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "third_party" / "pokeplatinum"
OUT = ROOT / "assets" / "data"

STAT_KEYS = {"hp": "hp", "attack": "atk", "defense": "def", "special_attack": "spa", "special_defense": "spd", "speed": "spe"}
GROWTH = {"EXP_RATE_MEDIUM_FAST": "medium_fast", "EXP_RATE_ERRATIC": "erratic", "EXP_RATE_FLUCTUATING": "fluctuating",
          "EXP_RATE_MEDIUM_SLOW": "medium_slow", "EXP_RATE_FAST": "fast", "EXP_RATE_SLOW": "slow"}


def const_to_id(c: str, prefix: str) -> str:
    return c[len(prefix):].lower()


def load_species_order() -> list:
    # generated/species.txt: SPECIES_NONE, SPECIES_BULBASAUR, … 줄 번호 = 전국 도감 번호
    return [l.strip() for l in (SRC / "generated" / "species.txt").read_text().splitlines() if l.strip()]


def gen_moves(tm_of: dict) -> dict:
    moves = {}
    for d in sorted((SRC / "res" / "moves").iterdir()):
        f = d / "data.json"
        if not f.exists():
            continue
        j = json.loads(f.read_text())
        mid = d.name
        eff = j.get("effect", {}) or {}
        moves[mid] = {
            "name": j["name"].upper(),                                   # 4세대 표기는 대문자
            "type": const_to_id(j["type"], "TYPE_"),
            "cat": const_to_id(j["class"], "CLASS_"),                    # physical / special / status
            "power": int(j.get("power", 0)),
            "accuracy": int(j.get("accuracy", 0)),
            "pp": int(j.get("pp", 0)),
            "effect": const_to_id(eff.get("type", "BATTLE_EFFECT_HIT"), "BATTLE_EFFECT_"),
            "effect_chance": int(eff.get("chance", 0)),
            "desc": "".join(j.get("description", [])).replace("\n", " ").strip(),
            "tm": tm_of.get("MOVE_" + mid.upper()),
        }
    return moves


def gen_tms() -> dict:
    """MOVE_X → "TM35" / "HM04"."""
    out = {}
    for f in sorted((SRC / "res" / "items" / "data").glob("*.json")):
        if not re.match(r"(tm|hm)\d+\.json", f.name):
            continue
        j = json.loads(f.read_text())
        if j.get("teachesMove"):
            out[j["teachesMove"]] = j["name"]
    return out


def gen_species(order: list, move_ids: set) -> dict:
    species = {}
    for dex, const in enumerate(order):
        if const in ("SPECIES_NONE", "SPECIES_EGG", "SPECIES_BAD_EGG"):
            continue
        sid = const_to_id(const, "SPECIES_")
        f = SRC / "res" / "pokemon" / sid / "data.json"
        if not f.exists():
            continue
        j = json.loads(f.read_text())
        types = [const_to_id(t, "TYPE_") for t in j["types"]]
        if len(types) == 2 and types[0] == types[1]:
            types = types[:1]
        learn = []
        seen = set()
        for lv, mv in j["learnset"]["by_level"]:
            mid = const_to_id(mv, "MOVE_")
            if mid in move_ids and mid not in seen:            # 같은 기술이 두 번 나오면(진화형 Lv1) 먼저 것
                learn.append([int(lv), mid])
                seen.add(mid)
        evolve = None
        for ev in j.get("evolutions", []):
            if ev[0] == "EVO_LEVEL":
                evolve = {"to": const_to_id(ev[2], "SPECIES_"), "level": int(ev[1])}
                break
        species[sid] = {
            "name": sid.upper().replace("_", " "),
            "dex": dex,
            "types": types,
            "base": {STAT_KEYS[k]: int(v) for k, v in j["base_stats"].items()},
            "exp": int(j["base_exp_reward"]),
            "weight": round(float(j["pokedex_data"]["weight_pounds"]) * 0.45359237, 1),   # kg — 넉백 비율(사용자 결정 2026-10-30)
            "growth": GROWTH[j["exp_rate"]],
            "evolve": evolve,
            "learnset": learn,
            "tms": list(j["learnset"].get("by_tm", [])),
            "tutor": [const_to_id(m, "MOVE_") for m in j["learnset"].get("by_tutor", [])],
        }
    return species


def gen_exp_tables() -> dict:
    rows = list(csv.DictReader((SRC / "res" / "pokemon" / ".shared" / "exp_tables.csv").open()))
    out = {}
    for col in ["medium_fast", "erratic", "fluctuating", "medium_slow", "fast", "slow"]:
        out[col] = [int(r[col]) for r in rows]
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    tm_of = gen_tms()
    moves = gen_moves(tm_of)
    species = gen_species(load_species_order(), set(moves))
    exp = gen_exp_tables()
    (OUT / "moves.json").write_text(json.dumps(moves, ensure_ascii=False, indent=0, sort_keys=True))
    # 자력기 표만 '그 종의 가장 최신 판'(PokeAPI) 기준으로 덮어쓴다(사용자 결정 2026-11-02, tools/latest_learnsets.py).
    try:
        import latest_learnsets
        latest_learnsets.apply_latest(species, moves)      # 5세대 이후 기술 레코드도 PokeAPI 값으로 보충
    except FileNotFoundError as e:
        print("최신 습득표 건너뜀(PokeAPI CSV 없음):", e)
    (OUT / "species.json").write_text(json.dumps(species, ensure_ascii=False, indent=0, sort_keys=True))
    (OUT / "exp_tables.json").write_text(json.dumps(exp))
    print(f"moves {len(moves)}, species {len(species)}, tms {len(tm_of)}, exp curves {len(exp)}")
    c = species["charmander"]
    print("charmander:", c["dex"], c["types"], c["base"], c["exp"], c["growth"], c["evolve"])
    print("  learnset:", c["learnset"])
    print("ember:", moves["ember"])


if __name__ == "__main__":
    main()
