"""FRLG 사람 NPC 도트 → assets/npcs/<이름>.png

  python3 -I tools/frlg_npc.py nurse:npc_pink clerk:npc_white
  python3 -I tools/frlg_npc.py bug_catcher:npc_green camper:npc_green brock:npc_green   (트레이너, 2026-10-29)
  python3 -I tools/frlg_npc.py prof_oak:npc_white   (연구소의 오박사, 2026-10-29)
  python3 -I tools/frlg_npc.py blue:npc_green       (라이벌 그린 — 원작 이름 BLUE 그림, 팔레트 NPC_GREEN, 2026-10-30)
  python3 -I tools/frlg_npc.py --emote      → assets/fx/emote_exclaim.png(트레이너가 알아챌 때 "!", graphics/misc/emoticons.png 의 셋째 열 첫 칸 16×16)
  python3 -I tools/frlg_npc.py --ball       → assets/fx/item_ball.png(연구소 탁자 위 스타팅 볼, 지도 물건 ITEM_BALL — pics/misc/item_ball.png + NPC_WHITE 팔레트)

pret/pokefirered 의 graphics/object_events/pics/people/<이름>.png(4bpp, 16×32 프레임 가로로: 0 아래·1 위·2 왼쪽 대기, 그 뒤 걷기)에
graphics/object_events/palettes/<팔레트>.pal 을 입혀(0번 투명) 시트 그대로 저장한다. 오른쪽은 왼쪽을 뒤집어 쓴다(원작과 같음).
어느 팔레트인지는 src/data/object_events/object_event_graphics_info.h 의 paletteTag(간호순 NPC_PINK, 점원 NPC_WHITE).
받은 파일은 third_party/pokefirered/ 에(이미 있으면 건너뜀). 원작 자료는 Nintendo / Game Freak / Creatures — personal use.
"""
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TP = ROOT / "third_party" / "pokefirered"
RAW = "https://raw.githubusercontent.com/pret/pokefirered/master/"


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


def emote():
    img = Image.open(fetch("graphics/misc/emoticons.png"))
    pal = img.getpalette()
    src = img.crop((32, 0, 48, 16))
    out = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    for y in range(16):
        for x in range(16):
            i = src.getpixel((x, y))
            if i % 16:
                out.putpixel((x, y), tuple(pal[i * 3:i * 3 + 3]) + (255,))
    out.save(ROOT / "assets" / "fx" / "emote_exclaim.png")
    print("emote_exclaim", out.getbbox())


def ball():
    img = Image.open(fetch("graphics/object_events/pics/misc/item_ball.png"))
    pal = jasc(fetch("graphics/object_events/palettes/npc_white.pal"))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    for y in range(img.height):
        for x in range(img.width):
            i = img.getpixel((x, y)) % 16
            if i:
                out.putpixel((x, y), pal[i] + (255,))
    out.save(ROOT / "assets" / "fx" / "item_ball.png")
    print("item_ball", img.size, out.getbbox())


def main():
    if "--emote" in sys.argv:
        emote()
        return
    if "--ball" in sys.argv:
        ball()
        return
    out_dir = ROOT / "assets" / "npcs"
    out_dir.mkdir(parents=True, exist_ok=True)
    for arg in sys.argv[1:]:
        name, pal_name = arg.split(":")
        img = Image.open(fetch(f"graphics/object_events/pics/people/{name}.png"))
        pal = jasc(fetch(f"graphics/object_events/palettes/{pal_name}.pal"))
        idx = img if img.mode == "P" else img.convert("P")
        w, h = idx.size
        out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        src, dst = idx.load(), out.load()
        for y in range(h):
            for x in range(w):
                i = src[x, y]
                if i != 0:
                    dst[x, y] = pal[i % len(pal)] + (255,)
        out.save(out_dir / f"{name}.png")
        print(name, (w, h), "frames", w // 16)


if __name__ == "__main__":
    main()
