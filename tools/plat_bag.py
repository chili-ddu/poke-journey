"""플래티넘 가방 화면 자산 → assets/ui/plat/bag_*.png

  python3 -I tools/plat_bag.py

pret/pokeplatinum res/graphics/bag/ 의 위 화면 배경(bag_ui_main.NSCR + bag_ui_main_tileset.png + bag_ui_main.pal),
가방 그림(bag_sprite_male.png, 64×64 × 8 = 주머니마다 그 칸이 빨갛게), 주머니 아이콘(pocket_selector_icons.png, 16×16 × 16 = 주머니마다 안 고름·고름),
화살표(pocket_selector_arrows.png), 목록 선택 줄(item_highlight.png), 아이콘 선택 틀(pocket_highlight.png)을 받아(이미 있으면 건너뜀) RGBA 로 굽는다.
타일 그림(bag_ui_main_tileset.png)은 회색조 PNG 인데 값이 뒤집혀 있다: 색 번호 = 15 − 회색값/17.
배경의 투명(색 번호 0) 자리는 그대로 투명 — 게임이 그 자리에 목록·설명 글을 그린다(원작도 글 창을 따로 얹는다).
원작 자료는 Nintendo / Game Freak / Creatures — personal use.
"""
import struct
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TP = ROOT / "third_party" / "pokeplatinum"
RAW = "https://raw.githubusercontent.com/pret/pokeplatinum/main/"
OUT = ROOT / "assets" / "ui" / "plat"
G = "res/graphics/bag/"


def fetch(rel: str) -> Path:
    p = TP / rel
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(RAW + rel, timeout=60) as r:
            p.write_bytes(r.read())
    return p


def jasc(path: Path) -> list:
    v = path.read_text().split()
    return [tuple(int(c) for c in v[3 + i * 3:6 + i * 3]) for i in range(int(v[2]))]


def nscr(d: bytes) -> tuple:
    i = 16
    while i < len(d):
        magic, size = d[i:i + 4], struct.unpack("<I", d[i + 4:i + 8])[0]
        if magic in (b"NRCS", b"SCRN"):
            s = d[i + 8:i + size]
            w, h = struct.unpack("<HH", s[0:4])
            n = struct.unpack("<I", s[8:12])[0]
            return w, h, struct.unpack("<%dH" % (n // 2), s[12:12 + n])
        i += size
    raise ValueError("SCRN 없음")


def tiles_of(png: Path) -> list:
    im = Image.open(png)
    w, h = im.size
    px = im.load()
    out = []
    for ty in range(h // 8):
        for tx in range(w // 8):
            t = []
            for y in range(8):
                for x in range(8):
                    v = px[tx * 8 + x, ty * 8 + y]
                    t.append(15 - v // 17 if im.mode == "L" else v)
            out.append(t)
    return out


def screen(nscr_p: Path, tiles_p: Path, pal_p: Path, rows: int = 24) -> Image.Image:
    w, h, ent = nscr(nscr_p.read_bytes())
    tiles, pal = tiles_of(tiles_p), jasc(pal_p)
    cols = w // 8
    im = Image.new("RGBA", (w, rows * 8), (0, 0, 0, 0))
    px = im.load()
    for i, e in enumerate(ent):
        cx, cy = i % cols, i // cols
        if cy >= rows:
            break
        t, hf, vf, b = e & 0x3FF, (e >> 10) & 1, (e >> 11) & 1, e >> 12
        if t >= len(tiles):
            continue
        for k, ci in enumerate(tiles[t]):
            if ci == 0:
                continue
            x, y = k % 8, k // 8
            px[cx * 8 + (7 - x if hf else x), cy * 8 + (7 - y if vf else y)] = pal[(b * 16 + ci) % len(pal)] + (255,)
    return im


def sprite(png: Path) -> Image.Image:
    im = Image.open(png)
    if im.mode != "P":
        return im.convert("RGBA")
    pal = im.getpalette()
    w, h = im.size
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s, d = im.load(), out.load()
    for y in range(h):
        for x in range(w):
            i = s[x, y]
            if i % 16:
                d[x, y] = tuple(pal[i * 3:i * 3 + 3]) + (255,)
    return out


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    bg = screen(fetch(G + "bag_ui_main.NSCR"), fetch(G + "bag_ui_main_tileset.png"), fetch(G + "bag_ui_main.pal"))
    raw = bg.copy()
    # 글 창 자리 채우기: 목록 창(오른쪽 초록 틀 안)은 흰 바탕, 주머니 이름 칸은 짙은 남색(흰 글자). 원작은 글 창을 따로 얹는다.
    px = bg.load()
    for (x0, y0, x1, y1), col in (((100, 2, 254, 138), (248, 248, 248, 255)), ((3, 104, 98, 124), (56, 64, 96, 255))):
        for y in range(y0, y1):
            for x in range(x0, x1):
                if px[x, y][3] == 0:
                    px[x, y] = col
    bg.save(OUT / "bag_bg.png")
    sprite(fetch(G + "bag_sprite_male.png")).save(OUT / "bag_sprite.png")
    sprite(fetch(G + "pocket_selector_icons.png")).save(OUT / "bag_pocket_icons.png")
    sprite(fetch(G + "pocket_selector_arrows.png")).save(OUT / "bag_arrows.png")
    sprite(fetch(G + "item_highlight.png")).crop((0, 7, 148, 24)).save(OUT / "bag_item_cursor.png")   # 152×32 안의 틀은 (0,7) 148×17
    sprite(fetch(G + "pocket_highlight.png")).save(OUT / "bag_pocket_cursor.png")
    # 투명 자리(글 창) 찾기: 열마다·줄마다 투명 칸이 이어진 큰 사각형을 찍어 둔다(배치 상수용).
    a = raw.split()[3].load()
    w, h = raw.size
    seen = set()
    for y in range(h):
        for x in range(w):
            if a[x, y] == 0 and (x, y) not in seen:
                x1 = x
                while x1 < w and a[x1, y] == 0:
                    x1 += 1
                y1 = y
                while y1 < h and all(a[xx, y1] == 0 for xx in range(x, x1)):
                    y1 += 1
                if (x1 - x) * (y1 - y) > 200:
                    print("투명 자리", (x, y, x1 - x, y1 - y))
                for yy in range(y, y1):
                    for xx in range(x, x1):
                        seen.add((xx, yy))
    print("구움:", sorted(p.name for p in OUT.glob("bag_*.png")))


if __name__ == "__main__":
    main()
