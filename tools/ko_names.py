"""한글 이름 표 생성 → assets/data/names_ko.json (언어 옵션용; 사용자 결정 2026-10-27: PokeAPI CSV 에서)

  python3 -I tools/ko_names.py

입력: third_party/pokeapi/*.csv — github PokeAPI/pokeapi `data/v2/csv/` 의
  pokemon_species.csv + pokemon_species_names.csv, moves.csv + move_names.csv, types.csv + type_names.csv, stats.csv + stat_names.csv
  (local_language_id 3 = 한국어). 자료는 BSD-3 — personal use.
출력: {"species": {pret id: 한글}, "moves": {...}, "types": {...}, "stats": {hp/atk/def/spa/spd/spe: 한글}}
PokeAPI 식별자는 '-' 로 잇고(fire-fang) pret 은 '_' 로 잇는다(fire_fang). 몇 개는 이름이 달라 ALIAS 로 맞춘다. 못 맞춘 id 는 출력에 찍힌다.
"""
import csv
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "third_party" / "pokeapi"
OUT = ROOT / "assets" / "data" / "names_ko.json"
KO = "3"
# pret id → PokeAPI identifier (밑줄→붙임표 변환으로 안 맞는 것)
ALIAS = {"smoke_screen": "smokescreen", "double_slap": "double-slap", "sand_attack": "sand-attack", "self_destruct": "self-destruct",
         "soft_boiled": "soft-boiled", "vice_grip": "vice-grip", "feint_attack": "feint-attack", "dynamic_punch": "dynamic-punch",
         "thunder_punch": "thunder-punch", "sonic_boom": "sonic-boom", "poison_powder": "poison-powder", "dragon_breath": "dragon-breath",
         "extreme_speed": "extreme-speed", "ancient_power": "ancient-power", "grass_whistle": "grass-whistle", "nidoran_f": "nidoran-f",
         "nidoran_m": "nidoran-m", "mr_mime": "mr-mime", "ho_oh": "ho-oh", "porygon_z": "porygon-z", "mime_jr": "mime-jr",
         "farfetchd": "farfetchd", "high_jump_kick": "high-jump-kick", "hi_jump_kick": "high-jump-kick",
         "faint_attack": "feint-attack", "selfdestruct": "self-destruct", "smelling_salt": "smelling-salts", "softboiled": "soft-boiled"}
STAT_KEYS = {"1": "hp", "2": "atk", "3": "def", "4": "spa", "5": "spd", "6": "spe"}


def rows(name: str) -> list:
    with (SRC / f"{name}.csv").open(encoding="utf-8", newline="") as f:
        return list(csv.DictReader(f))


def ko_names(base: str, names: str, key: str) -> dict:
    """identifier → 한글 이름."""
    ident = {r["id"]: r["identifier"] for r in rows(base)}
    out = {}
    for r in rows(names):
        if r["local_language_id"] == KO and r[key] in ident:
            out[ident[r[key]]] = r["name"]
    return out


def match(our_ids: list, api: dict) -> tuple:
    got, missing = {}, []
    for pid in our_ids:
        cand = ALIAS.get(pid, pid.replace("_", "-"))
        if cand in api:
            got[pid] = api[cand]
        elif pid.replace("_", "") in api:
            got[pid] = api[pid.replace("_", "")]
        else:
            missing.append(pid)
    return got, missing


def main():
    species = json.loads((ROOT / "assets" / "data" / "species.json").read_text())
    moves = json.loads((ROOT / "assets" / "data" / "moves.json").read_text())
    sp, sp_miss = match(list(species), ko_names("pokemon_species", "pokemon_species_names", "pokemon_species_id"))
    mv, mv_miss = match(list(moves), ko_names("moves", "move_names", "move_id"))
    types = ko_names("types", "type_names", "type_id")
    stat_ident = {r["id"]: r["identifier"] for r in rows("stats")}
    stats = {STAT_KEYS[r["stat_id"]]: r["name"] for r in rows("stat_names") if r["local_language_id"] == KO and r["stat_id"] in STAT_KEYS}
    stats["hp"] = "최대HP"   # 레벨업 창 표기(원작 스크린샷)
    out = {"species": sp, "moves": mv, "types": {t: types[t] for t in types if t in
           ["normal", "fire", "water", "grass", "electric", "ice", "fighting", "poison", "ground", "flying", "psychic", "bug", "rock",
            "ghost", "dragon", "dark", "steel", "fairy"]}, "stats": stats}
    OUT.write_text(json.dumps(out, ensure_ascii=False, indent=0) + "\n", encoding="utf-8")
    print(f"species {len(sp)}/{len(species)} moves {len(mv)}/{len(moves)} types {len(out['types'])} stats {len(stats)}")
    if sp_miss:
        print("missing species:", sp_miss)
    if mv_miss:
        print("missing moves:", mv_miss)


if __name__ == "__main__":
    main()
