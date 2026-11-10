"""플래티넘 포켓몬 상세창(상태창) 자산 → assets/ui/plat/sum_*.png, assets/ui/plat/front/<종>.png, assets/data/abilities.json

  python3 -I tools/plat_summary.py

pret/pokeplatinum res/graphics/pokemon_summary_screen/ 의 페이지 배경(page_info / page_skills / page_battle_moves /
page_battle_moves_select_mode .NSCR + tiles_main.png + tiles_main.pal), 탭 아이콘(tabs.png: 0~7 안 고른 16×16, 8~15 고른 24×16 —
tabs_cell.json 대로 16×16 + 8×16 조각을 붙인다), 잡은 볼(balls/poke_ball.png), 그리고 주인공 계열의 정면 그림
(res/pokemon/<종>/male_front.png 첫 프레임 80×80 + normal.pal)을 받아(이미 있으면 건너뜀) 굽는다.
특성: 종 → 특성은 플래티넘 res/pokemon/<종>/data.json, 이름·설명은 PokeAPI CSV(abilities, ability_names, ability_flavor_text;
영어는 platinum 판, 한국어는 한국어가 있는 가장 이른 판).
글자 자리는 src/applications/pokemon_summary_screen/window.c 의 창 배치를 그대로 쓴다(scripts/ui/summary_screen.gd).
원작 자료는 Nintendo / Game Freak / Creatures, PokeAPI 는 BSD-3 — personal use.
"""
import csv
import json
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import plat_bag as pb   # fetch / jasc / screen / sprite 같이 씀

ROOT = pb.ROOT
OUT = pb.OUT
G = "res/graphics/pokemon_summary_screen/"
PAGES = {"sum_info": "page_info", "sum_skills": "page_skills", "sum_moves": "page_battle_moves",
         "sum_moves_select": "page_battle_moves_select_mode"}
FRONTS = ["bulbasaur", "ivysaur", "venusaur", "charmander", "charmeleon", "charizard", "squirtle", "wartortle", "blastoise"]   # 상태창은 주인공(스타팅 세 계열)만 연다
PLATINUM_VG = 9                                       # PokeAPI version_group: platinum


def pages():
    tiles, pal = pb.fetch(G + "tiles_main.png"), pb.fetch(G + "tiles_main.pal")
    for out, n in PAGES.items():
        im = pb.screen(pb.fetch(G + n + ".NSCR"), tiles, pal)
        # 투명(색 번호 0) 자리는 원작 바탕색(팔레트 0번)으로 메운다 — 원작은 그 뒤에 단색 배경을 깐다.
        back = pb.jasc(pal)[0] + (255,)
        bg = Image.new("RGBA", im.size, back)
        bg.alpha_composite(im)
        bg.save(OUT / f"{out}.png")


def tabs():
    src = pb.sprite(pb.fetch(G + "tabs.png"))          # 16 폭, 타일은 2개씩 한 줄
    def tile(t):
        return src.crop(((t % 2) * 8, (t // 2) * 8, (t % 2) * 8 + 8, (t // 2) * 8 + 8))
    def block16(t0):
        im = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
        for k in range(4):
            im.alpha_composite(tile(t0 + k), ((k % 2) * 8, (k // 2) * 8))
        return im
    out = Image.new("RGBA", (24 * 8, 32), (0, 0, 0, 0))
    for i in range(8):
        out.alpha_composite(block16(4 * i), (i * 24, 0))           # 위 줄: 안 고른 탭 16×16
        f = Image.new("RGBA", (24, 16), (0, 0, 0, 0))              # 아래 줄: 고른 탭 24×16 (16×16 + 8×16)
        f.alpha_composite(block16(32 + 6 * i), (0, 0))
        f.alpha_composite(tile(36 + 6 * i), (16, 0))
        f.alpha_composite(tile(37 + 6 * i), (16, 8))
        out.alpha_composite(f, (i * 24, 16))
    out.save(OUT / "sum_tabs.png")


def move_parts():
    """기술 페이지: 고른 기술 상세 패널(move_info.NSCR 왼쪽 판, 기술을 고르면 왼쪽에 겹친다)과 선택 커서(move_cursor: 64×32 왼쪽 반을 좌우로 뒤집어 128×32)."""
    info = pb.screen(pb.fetch(G + "move_info.NSCR"), pb.fetch(G + "tiles_main.png"), pb.fetch(G + "tiles_main.pal"))
    left = info.crop((0, 0, 256, 192))
    box = left.getbbox()
    left.crop(box).save(OUT / "sum_move_info.png")
    print("move_info 판:", box)
    src = pb.sprite(pb.fetch(G + "move_cursor.png"))     # 8 폭, 타일 한 줄에 하나
    half = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
    for t in range(32):
        half.alpha_composite(src.crop((0, t * 8, 8, t * 8 + 8)), ((t % 8) * 8, (t // 8) * 8))
    cur = Image.new("RGBA", (128, 32), (0, 0, 0, 0))
    cur.alpha_composite(half, (0, 0))
    cur.alpha_composite(half.transpose(Image.FLIP_LEFT_RIGHT), (64, 0))
    cur.save(OUT / "sum_move_cursor.png")


def move_desc_ko():
    """기술 한국어 설명(PokeAPI move_flavor_text, 한국어가 있는 가장 이른 판) → assets/data/move_desc_ko.json {pret 기술 id: 글}."""
    import ko_names
    api = ROOT / "third_party" / "pokeapi"
    rows = lambda n: csv.DictReader((api / f"{n}.csv").open(encoding="utf-8", newline=""))
    ident = {r["id"]: r["identifier"] for r in rows("moves")}
    best, text = {}, {}
    for r in rows("move_flavor_text"):
        if r["language_id"] != "3":
            continue
        key, vg = ident.get(r["move_id"], ""), int(r["version_group_id"])
        if key and (key not in best or vg < best[key]):
            best[key] = vg
            text[key] = r["flavor_text"].replace("\n", " ").replace("\f", " ").strip()
    moves = json.loads((ROOT / "assets" / "data" / "moves.json").read_text())
    out = {}
    for mid in moves:
        key = ko_names.ALIAS.get(mid, mid.replace("_", "-"))
        if key in text:
            out[mid] = text[key]
    (ROOT / "assets" / "data" / "move_desc_ko.json").write_text(json.dumps(out, ensure_ascii=False, indent=1) + "\n")
    print("기술 한국어 설명:", len(out), "/", len(moves), "ember:", out.get("ember"))


def ball():
    pb.sprite(pb.fetch(G + "balls/poke_ball.png")).save(OUT / "sum_ball.png")


def fronts():
    """앞모습: 보통(normal.pal) → front/<종>.png, 이로치(shiny.pal) → front/<종>_shiny.png."""
    d = OUT / "front"
    d.mkdir(parents=True, exist_ok=True)
    for sp in FRONTS:
        im = Image.open(pb.fetch(f"res/pokemon/{sp}/male_front.png"))
        src = im.load()
        for pal_name, suffix in (("normal", ""), ("shiny", "_shiny")):
            pal = pb.jasc(pb.fetch(f"res/pokemon/{sp}/{pal_name}.pal"))
            out = Image.new("RGBA", (80, 80), (0, 0, 0, 0))
            dst = out.load()
            for y in range(80):
                for x in range(80):
                    i = src[x, y] % 16
                    if i:
                        dst[x, y] = pal[i] + (255,)
            out.save(d / f"{sp}{suffix}.png")


def shiny_icon():
    """이로치 별(shiny_and_pokerus_cured_icon.png 위 8×8 칸, sprites.pal 2번 팔레트 — sprites.c SUMMARY_SPRITE_SHINY_ICON) → sum_shiny.png."""
    im = Image.open(pb.fetch(G + "shiny_and_pokerus_cured_icon.png"))
    pal = pb.jasc(pb.fetch(G + "sprites.pal"))
    out = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
    for y in range(8):
        for x in range(8):
            i = im.getpixel((x, y)) % 16
            if i:
                out.putpixel((x, y), pal[32 + i] + (255,))
    out.save(OUT / "sum_shiny.png")


def abilities():
    api = ROOT / "third_party" / "pokeapi"
    rows = lambda n: list(csv.DictReader((api / f"{n}.csv").open(encoding="utf-8", newline="")))
    ident = {r["id"]: r["identifier"] for r in rows("abilities")}
    names, descs, best = {}, {}, {}
    for r in rows("ability_names"):
        if r["local_language_id"] in ("3", "9"):
            names.setdefault(ident[r["ability_id"]], {})[r["local_language_id"]] = r["name"]
    for r in rows("ability_flavor_text"):
        key, lang, vg = ident[r["ability_id"]], r["language_id"], int(r["version_group_id"])
        text = r["flavor_text"].replace("\n", " ").replace("\f", " ").strip()
        if lang == "9" and vg == PLATINUM_VG:
            descs.setdefault(key, {})["9"] = text
        if lang == "3" and (key not in best or vg < best[key]):
            best[key] = vg
            descs.setdefault(key, {})["3"] = text
    species = json.loads((ROOT / "assets" / "data" / "species.json").read_text())
    by_species, used = {}, set()
    for sid in species:
        f = pb.TP / "res" / "pokemon" / sid / "data.json"
        if not f.exists():
            continue
        abil = [a.removeprefix("ABILITY_").lower() for a in json.loads(f.read_text()).get("abilities", []) if a != "ABILITY_NONE"]
        if abil:
            by_species[sid] = abil
            used.update(abil)
    table = {}
    for a in sorted(used):
        key = a.replace("_", "-")
        table[a] = {"name": names.get(key, {}).get("9", a).upper(), "name_ko": names.get(key, {}).get("3", ""),
                    "desc": descs.get(key, {}).get("9", ""), "desc_ko": descs.get(key, {}).get("3", "")}
    (ROOT / "assets" / "data" / "abilities.json").write_text(json.dumps({"species": by_species, "abilities": table}, ensure_ascii=False, indent=1) + "\n")
    print("abilities:", len(table), "charmander:", by_species.get("charmander"), table.get("blaze"))


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    pages()
    tabs()
    ball()
    move_parts()
    move_desc_ko()
    fronts()
    shiny_icon()
    abilities()
    print("구움:", sorted(p.name for p in OUT.glob("sum_*.png")), sorted(p.name for p in (OUT / "front").glob("*.png")))


if __name__ == "__main__":
    main()
