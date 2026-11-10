"""플래티넘 장소 이름 알림판(MapNamePopUp) 그림 → assets/ui/plat/popup_<종류>.png (사용자 요청 2026-10-30: 장소 배너도 원작 것)

  python3 -I tools/plat_popup.py

출처: pret/pokeplatinum res/graphics/map_popups/<종류>_popup.png(136×48, 팔레트 PNG — 0번 투명) — 없으면 받는다.
종류: town · city · route · forest · cave · indoors · lake · park · water. 움직임·글자 자리는 src/overlay005/map_name_popup.c
(위에서 4px/프레임으로 내려와 60프레임 머문 뒤 올라감, FONT_SYSTEM 색 3·그림자 2, y 16) — Game._banner·Hud._draw_banner 가 따른다.
전부 Nintendo / Game Freak 저작물 — personal use 로만.
"""
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "third_party" / "pokeplatinum"
OUT = ROOT / "assets" / "ui" / "plat"
RAW = "https://raw.githubusercontent.com/pret/pokeplatinum/main/"
KINDS = ["town", "city", "route", "forest", "cave", "indoors", "lake", "park", "water"]


def fetch(rel: str) -> Path:
    p = SRC / rel
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(RAW + rel, timeout=60) as r:
            p.write_bytes(r.read())
    return p


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for k in KINDS:
        im = Image.open(fetch(f"res/graphics/map_popups/{k}_popup.png"))
        pal = im.getpalette()
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        src, dst = im.load(), out.load()
        for y in range(im.height):
            for x in range(im.width):
                i = src[x, y]
                if i:
                    dst[x, y] = (pal[i * 3], pal[i * 3 + 1], pal[i * 3 + 2], 255)
        out.save(OUT / f"popup_{k}.png")
        print(k, im.size, "글자", tuple(pal[9:12]), "그림자", tuple(pal[6:9]))


if __name__ == "__main__":
    main()
