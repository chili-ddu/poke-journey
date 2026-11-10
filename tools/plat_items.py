"""도구 데이터·아이콘 → assets/data/items.json, assets/items/<id>.png

  python3 -I tools/plat_items.py

pret/pokeplatinum 의 res/items/data/<id>.json(영문 이름·설명·가격)과 res/items/icons/<id>.png + .pal(아이콘, 팔레트 따로)을
third_party/pokeplatinum/ 로 받아(이미 있으면 건너뜀) 쓴다. 한글 이름은 PokeAPI CSV(third_party/pokeapi/items.csv + item_names.csv,
local_language_id 3)에서. 자료는 Nintendo / Game Freak / Creatures(pret), PokeAPI(BSD-3) — personal use.

ITEMS: 상점에서 파는 것(사용자 결정 2026-10-28: 플래티넘 프렌들리숍 물건 중 지금 게임에서 효과가 있는 것만, 몬스터볼 제외)
HELD : 야생 포켓몬이 원작 확률로 지니고 나와 떨어뜨리는 것(교환 재료 — 사용자 결정: 원작 지닌 물건만으로 물물교환)
"""
import csv
import json
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TP = ROOT / "third_party" / "pokeplatinum"
RAW = "https://raw.githubusercontent.com/pret/pokeplatinum/main/"
OUT_JSON = ROOT / "assets" / "data" / "items.json"
OUT_ICONS = ROOT / "assets" / "items"
OUT_HELD = ROOT / "assets" / "data" / "held_items.json"   # 종 → {common, rare} (원작: 흔함 50%, 드묾 5%, 둘이 같으면 100%)
ITEMS = ["potion", "super_potion", "hyper_potion", "max_potion", "full_restore", "revive",
         "antidote", "burn_heal", "parlyz_heal", "full_heal", "escape_rope", "repel", "super_repel", "max_repel"]
HELD = ["oran_berry", "chilan_berry", "light_ball", "poison_barb"]
BERRIES = ["oran_berry","sitrus_berry","leppa_berry","cheri_berry","chesto_berry","pecha_berry","rawst_berry","persim_berry","lum_berry"]
BERRY_DESC = {
    "oran_berry":"HP를 10만큼 회복한다.",
    "sitrus_berry":"HP를 최대 HP의 1/4만큼 회복한다.",
    "leppa_berry":"기술 하나의 PP를 10 회복한다. 단축키로 쓰면 PP 비율이 가장 낮은 기술에 사용한다.",
    "cheri_berry":"마비 상태를 치료한다.", "chesto_berry":"잠듦 상태를 치료한다.",
    "pecha_berry":"독 상태를 치료한다.", "rawst_berry":"화상 상태를 치료한다.",
    "persim_berry":"혼란 상태를 치료한다.", "lum_berry":"독, 화상, 마비, 잠듦과 혼란을 치료한다.",
}
GIFTS = ["everstone"]        # 이벤트로 받는 물건(상점 ×, 교환 재료 ×): 변함없는돌 — 상록시티 비주기(사용자 요청 2026-10-30)
ALIAS = {"parlyz_heal": "paralyze-heal"}   # pret id → PokeAPI identifier(밑줄→붙임표로 안 맞는 것)
# 원작 가방 주머니(fieldPocket) → 우리 id. 가방 화면은 이 순서(플래티넘 주머니 순서)대로 보여 준다.
POCKETS = {"POCKET_ITEMS": "items", "POCKET_MEDICINE": "medicine", "POCKET_BALLS": "balls", "POCKET_TMHMS": "tms",
           "POCKET_BERRIES": "berries", "POCKET_MAIL": "mail", "POCKET_BATTLE_ITEMS": "battle", "POCKET_KEY_ITEMS": "key"}


def fetch(rel: str) -> Path:
    p = TP / rel
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(RAW + rel, timeout=60) as r:
            p.write_bytes(r.read())
    return p


def jasc(path: Path) -> list:
    lines = path.read_text().split()
    n = int(lines[2])
    return [tuple(int(v) for v in lines[3 + i * 3:6 + i * 3]) for i in range(n)]


def ko_names() -> tuple:
    """(identifier → 한글 이름, identifier → 한글 설명). 설명은 플래티넘 판에 한국어가 없어 한국어가 있는 가장 이른 판(item_flavor_text.csv)."""
    src = ROOT / "third_party" / "pokeapi"
    ident = {}
    with (src / "items.csv").open(encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            ident[r["id"]] = r["identifier"]
    out = {}
    with (src / "item_names.csv").open(encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            if r["local_language_id"] == "3":
                out[ident[r["item_id"]]] = r["name"]
    desc, best = {}, {}
    with (src / "item_flavor_text.csv").open(encoding="utf-8", newline="") as f:
        for r in csv.DictReader(f):
            if r["language_id"] != "3":
                continue
            key, vg = ident[r["item_id"]], int(r["version_group_id"])
            if key not in best or vg < best[key]:
                best[key], desc[key] = vg, r["flavor_text"].replace("\n", " ").replace("\f", " ").strip()
    return out, desc


def icon(item: str, spec: dict) -> None:
    # 그림·팔레트 이름은 데이터의 icon 항목(여러 도구가 그림 하나를 팔레트만 바꿔 쓴다: 좋은상처약 = 상처약 그림 + 제 팔레트).
    sprite = spec.get("sprite", item + "_NCGR").removesuffix("_NCGR")
    palette = spec.get("palette", item + "_NCLR").removesuffix("_NCLR")
    png = Image.open(fetch(f"res/items/icons/{sprite}.png"))
    pal = jasc(fetch(f"res/items/icons/{palette}.pal"))
    idx = png.convert("P") if png.mode != "P" else png
    w, h = idx.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    src, dst = idx.load(), out.load()
    for y in range(h):
        for x in range(w):
            i = src[x, y]
            if i != 0:
                dst[x, y] = pal[i % len(pal)] + (255,)
    OUT_ICONS.mkdir(parents=True, exist_ok=True)
    out.save(OUT_ICONS / f"{item}.png")


def main():
    ko, ko_desc = ko_names()
    data = {}
    for item in dict.fromkeys(ITEMS + HELD + GIFTS + BERRIES):
        j = json.loads(fetch(f"res/items/data/{item}.json").read_text())
        pkey = ALIAS.get(item, item.replace("_", "-"))
        name_ko = ko.get(pkey, "")
        if not name_ko:
            print("한글 이름 없음:", item)
        data[item] = {"name": j["name"].upper(), "name_ko": name_ko, "price": int(j["price"]),
                      "desc": "".join(j.get("description", [])).replace("\n", " ").strip(),
                      "desc_ko": BERRY_DESC.get(item, ko_desc.get(pkey, "")), "pocket": POCKETS.get(j.get("fieldPocket", ""), "items"),
                      "shop": item in ITEMS or item in BERRIES, "held": item in HELD or item in BERRIES}
        icon(item, j.get("icon", {}))
    OUT_JSON.write_text(json.dumps(data, ensure_ascii=False, indent=1) + "\n")
    # 지닌 물건 표: 우리 게임의 종(species.json) 중 위 목록의 물건을 지닌 것만.
    species = json.loads((ROOT / "assets" / "data" / "species.json").read_text())
    held = {}
    for sid in species:
        f = TP / "res" / "pokemon" / sid / "data.json"
        if not f.exists():
            continue
        h = json.loads(f.read_text()).get("held_items", {})
        pick = {k: (v.removeprefix("ITEM_").lower() if v and v != "ITEM_NONE" else None) for k, v in h.items()}
        pick = {k: (v if v in data else None) for k, v in pick.items()}
        if any(pick.values()):
            held[sid] = pick
    OUT_HELD.write_text(json.dumps(held, ensure_ascii=False, indent=1) + "\n")
    print("held:", held)
    for k, v in data.items():
        print(f"{k:14s} {v['name']:14s} {v['name_ko']:10s} ₽{v['price']}")


if __name__ == "__main__":
    main()
