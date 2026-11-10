"""플래티넘 글꼴(pret/pokeplatinum res/fonts) → Godot 비트맵 글꼴(BMFont .fnt + PNG) (2단계, docs/plan-gen4.md).

  python3 -I tools/plat_font.py            # third_party/pokeplatinum 에서 읽어 assets/fonts/plat_*.{fnt,png} 를 쓴다

입력
  res/fonts/font_message.png + .json   대사·기술 이름용 큰 글꼴(폭 7~11px)
  res/fonts/font_system.png  + .json   HUD 숫자·작은 글용(폭 3~10px)
  tools/msgenc/charmap.txt             "HEXCODE=<글자>" — 글꼴 시트의 셀 번호 = 글자 코드 − 1 (16×16 셀, 16열; 코드 1 = 전각 공백이 셀 0)
셀 안 팔레트: 1=글자, 2=그림자(오른쪽 아래), 3=글자 배경, 0=빈 칸. 그림자는 게임에서 PixelUi 가 찍으므로 1만 흰색으로 남긴다.
줄 높이 16, 기준선은 'A' 의 아랫줄에서 잰다.
"""
import json
import re
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "third_party" / "pokeplatinum"
OUT = ROOT / "assets" / "fonts"
FONTS = {"plat_message": "font_message", "plat_system": "font_system"}
CELL = 16
COLS = 16


def charmap() -> dict:
    """코드 → 한 글자. 명령({…})·여러 글자 항목은 뺀다. 곧은 따옴표는 굽은 따옴표 셀을 같이 쓴다."""
    out = {}
    for line in (SRC / "tools" / "msgenc" / "charmap.txt").read_text(encoding="utf-8").splitlines():
        m = re.match(r"^\s*([0-9A-Fa-f]{4})=(.)$", line)
        if m:
            out.setdefault(int(m.group(1), 16), m.group(2))
    rev = {ch: code for code, ch in out.items()}
    pairs = [(ch, code) for code, ch in out.items()]
    for plain, curly in (("'", "’"), ('"', "”")):
        if curly in rev and plain not in rev:
            pairs.append((plain, rev[curly]))
    return dict(pairs)   # 글자 → 코드


def build(name: str, src_name: str, cmap: dict):
    sheet = Image.open(SRC / "res" / "fonts" / f"{src_name}.png")
    widths = json.loads((SRC / "res" / "fonts" / f"{src_name}.json").read_text())["glyphWidths"]
    atlas = Image.new("RGBA", sheet.size, (0, 0, 0, 0))
    chars = []
    base = None
    for ch, code in sorted(cmap.items(), key=lambda p: ord(p[0])):
        idx = code - 1
        if idx < 0 or idx >= len(widths):
            continue
        cx, cy = (idx % COLS) * CELL, (idx // COLS) * CELL
        x0, x1, bottom = CELL, 0, None
        for y in range(CELL):
            for x in range(CELL):
                if sheet.getpixel((cx + x, cy + y)) == 1:
                    atlas.putpixel((cx + x, cy + y), (255, 255, 255, 255))
                    x0, x1 = min(x0, x), max(x1, x + 1)
                    bottom = y
        w = max(0, x1 - x0)
        if ch == "A" and bottom is not None:
            base = bottom + 1
        chars.append((ord(ch), cx + x0 if w else cx, cy, w, CELL, x0 if w else 0, widths[idx]))
    base = base or 12
    atlas.save(OUT / f"{name}.png")
    lines = [
        f'info face="{name}" size={CELL} bold=0 italic=0 charset="" unicode=1 stretchH=100 smooth=0 aa=1 padding=0,0,0,0 spacing=0,0 outline=0',
        f"common lineHeight={CELL} base={base} scaleW={sheet.width} scaleH={sheet.height} pages=1 packed=0 alphaChnl=0 redChnl=4 greenChnl=4 blueChnl=4",
        f'page id=0 file="{name}.png"',
        f"chars count={len(chars)}",
    ]
    for cid, x, y, w, h, xo, xa in chars:
        lines.append(f"char id={cid} x={x} y={y} width={w} height={h} xoffset={xo} yoffset=0 xadvance={xa} page=0 chnl=15")
    (OUT / f"{name}.fnt").write_text("\n".join(lines) + "\n")
    print(name, len(chars), "glyphs, base", base, "A width", widths[cmap["A"] - 1], "0 width", widths[cmap["0"] - 1])


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    cmap = charmap()
    for name, src in FONTS.items():
        build(name, src, cmap)


if __name__ == "__main__":
    main()
