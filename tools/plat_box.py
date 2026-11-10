"""플래티넘 PC 박스(시작 화면) 자산 → assets/ui/plat/box_*.png, assets/ui/plat/icons/<종>.png

  python3 -I tools/plat_box.py

res/prebuilt/graphic/box.narc(박스 그림 묶음)에서 원작 박스 화면을 굽는다(src/applications/pc_boxes 의 순서 그대로):
  BG1  4번 타일의 0번 칸으로 화면 전체를 채움(줄무늬) — ov19_021D75CC Bg_FillTilemapRect(…, 0x0, …)
  BG3  벽지: 화면표 30·타일 29·팔레트 28(0번 벽지 FOREST) — Unk_ov19_021E0178[0], 21×20칸을 x 11칸(88px)부터(ov19_021D8764)
  BG2  왼쪽 미리보기 판·이름 칸: 화면표 0·타일 1·팔레트 5(7줄)
  바탕색은 BG 팔레트 0번의 0번 색.
  손 커서: 12번 타일(32×32 블록 5개: 가리킴 ×2·벌림·쥠·그림자), OBJ 팔레트 26번의 0번(흰 장갑).
아이콘: res/pokemon/<종>/icon.png(32×64 두 프레임, PNG 안 팔레트 = data.json icon_palette 와 같음).
원작 자료는 Nintendo / Game Freak — personal use 로만.
"""
import importlib.util
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TP = ROOT / "third_party" / "pokeplatinum"
RAW = "https://raw.githubusercontent.com/pret/pokeplatinum/main/"
OUT = ROOT / "assets" / "ui" / "plat"
spec = importlib.util.spec_from_file_location("nd", ROOT / "tools" / "nitro_dump.py")
nd = importlib.util.module_from_spec(spec); spec.loader.exec_module(nd)
STARTERS = ["bulbasaur", "ivysaur", "venusaur", "charmander", "charmeleon", "charizard", "squirtle", "wartortle", "blastoise"]


def fetch(rel: str) -> Path:
    p = TP / rel
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(RAW + rel, timeout=60) as r:
            p.write_bytes(r.read())
    return p


def screen(files, scr: int, chars: int, pal: int) -> Image.Image:
    tiles, bpp, _, _ = nd.ncgr(files[chars])
    w, h, e = nd.nscr(files[scr])
    return nd.draw_screen(w, h, e, tiles, nd.nclr(files[pal]), bpp)


def build_wallpapers(files):
    """Original wallpaper entries 0–15, in the native PC table order (no recoloring)."""
    folder = OUT / "box_wallpapers"
    folder.mkdir(exist_ok=True)
    for index in range(16):
        base = 28 + index * 3
        screen(files, base + 2, base + 1, base).save(folder / f"{index:02d}.png")


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    files = [nd.lz10(f) for f in nd.narc_files(fetch("res/prebuilt/graphic/box.narc").read_bytes())]
    build_wallpapers(files)
    bg_pal = nd.nclr(files[5])
    out = Image.new("RGBA", (256, 192), bg_pal[0] + (255,))
    # BG1: 4번 타일 0번 칸(팔레트 0)으로 32×24칸을 채운다.
    t4, bpp4, _, _ = nd.ncgr(files[4])
    cell = nd.draw_tiles([t4[0]], bg_pal, cols=1, pal_index=0, bpp=bpp4)
    for y in range(0, 192, 8):
        for x in range(0, 256, 8):
            out.alpha_composite(cell, (x, y))
    # BG3: 벽지(FOREST)를 x 88 부터.
    wp = screen(files, 30, 29, 28)
    out.alpha_composite(wp, (88, 0))
    wp.save(OUT / "box_wallpaper.png")
    # BG2: 왼쪽 판(맨 위).
    out.alpha_composite(screen(files, 0, 1, 5), (0, 0))
    out.save(OUT / "box_bg.png")
    # 손 커서 5프레임(32×32)을 가로로.
    obj_pal = nd.nclr(files[26])
    t12, bpp12, _, _ = nd.ncgr(files[12])
    hand = Image.new("RGBA", (32 * 5, 32), (0, 0, 0, 0))
    for b in range(5):
        for k in range(16):
            t = b * 16 + k
            if t < len(t12):
                hand.alpha_composite(nd.draw_tiles([t12[t]], obj_pal, cols=1, pal_index=0, bpp=bpp12), (b * 32 + (k % 4) * 8, (k // 4) * 8))
    hand.save(OUT / "box_hand.png")
    # 아이콘.
    (OUT / "icons").mkdir(exist_ok=True)
    for sp in STARTERS:
        im = Image.open(fetch(f"res/pokemon/{sp}/icon.png"))
        pal = im.getpalette()
        rgba = Image.new("RGBA", im.size, (0, 0, 0, 0))
        for y in range(im.height):
            for x in range(im.width):
                i = im.getpixel((x, y))
                if i % 16:
                    rgba.putpixel((x, y), tuple(pal[i * 3:i * 3 + 3]) + (255,))
        rgba.save(OUT / "icons" / f"{sp}.png")
    print("구움: box_bg 256×192, box_wallpaper", wp.size, "box_hand 160×32, icons", len(STARTERS))


if __name__ == "__main__":
    main()
