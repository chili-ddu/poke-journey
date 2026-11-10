"""플래티넘 트레이너 인카운트 연출 그림 → assets/ui/plat/enc_ball.png(128×128), enc_ball_small.png(64×64),
관장 컷인 enc_leader_banner_rock.png(256×60), enc_vs.png·enc_vs_outline.png(64×64), enc_mugshot_brock.png(96×64)

  python3 -I tools/plat_encounter.py

res/trainers/classes/.shared/enc_trainer_high.png·enc_trainer_low.png(4bpp, 그림은 이미 2D 배치) + enc_trainer.pal(0번 투명).
src/overlay005/encounter_effect_core.c 의 EncounterEffect_Trainer_Grass_LowerLevel(큰 볼이 돌며 커진 뒤 위·아래 반쪽으로 갈라짐)과
_HigherLevel(작은 볼 둘이 양옆에서 굴러옴)이 쓰는 몬스터볼. 셀(enc_trainer_*_cell.json): 0 = 전체, 1 = 위 반쪽, 2 = 아래 반쪽.
관장 컷인(EncounterEffect_GymLeader, 사용자 결정 2026-10-29): 플래티넘 구조 그대로, 그림은
  띠       leader_roark/banner.png + banner.NSCR 의 가운데 띠(y 42~101) — 같은 바위 타입 관장 강석의 띠(웅의 플래티넘 그림은 없다)
  VS       .shared/vs.png(셀 0 = 꽉 찬 VS, 셀 1 = 테두리 VS, 각 64×64), 팔레트는 PNG 안
  얼굴     파이어레드 웅 트레이너 그림(pret/pokefirered graphics/trainers/front_pics/leader_brock_front_pic.png + palettes/leader_brock.pal)
           의 상반신(x 8~55, y 0~31)을 정수 2배 → 플래티넘 얼굴 그림(mugshot) 크기 96×64
원작 자료는 Nintendo / Game Freak — personal use 로만.
"""
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
TP = ROOT / "third_party" / "pokeplatinum"
RAW = "https://raw.githubusercontent.com/pret/pokeplatinum/main/"
OUT = ROOT / "assets" / "ui" / "plat"


def fetch(rel: str) -> Path:
    p = TP / rel
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(RAW + rel, timeout=60) as r:
            p.write_bytes(r.read())
    return p


FR_RAW = "https://raw.githubusercontent.com/pret/pokefirered/master/"
FR = ROOT / "third_party" / "pokefirered"


def fetch_fr(rel: str) -> Path:
    p = FR / rel
    if not p.exists():
        p.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(FR_RAW + rel, timeout=60) as r:
            p.write_bytes(r.read())
    return p


def flat(im: Image.Image, pal: list, transparent0: bool = True) -> Image.Image:
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    for y in range(im.height):
        for x in range(im.width):
            i = im.getpixel((x, y))
            if (i % 16) if transparent0 else True:
                out.putpixel((x, y), pal[i % len(pal)] + (255,))
    return out


def leader(name="brock", band="roark", color="rock"):
    import importlib.util, struct
    spec = importlib.util.spec_from_file_location("nd", ROOT / "tools" / "nitro_dump.py")
    nd = importlib.util.module_from_spec(spec); spec.loader.exec_module(nd)
    im = Image.open(fetch(f"res/trainers/classes/leader_{band}/banner.png"))
    pal = [tuple(im.getpalette()[i * 3:i * 3 + 3]) for i in range(256)]
    tiles = [[im.getpixel((tx * 8 + i % 8, ty * 8 + i // 8)) & 15 for i in range(64)]
             for ty in range(im.height // 8) for tx in range(im.width // 8)]
    w, h, e = nd.nscr(fetch(f"res/trainers/classes/leader_{band}/banner.NSCR").read_bytes())
    band = nd.draw_screen(w, h, e, tiles, pal, 4).crop((0, 42, 256, 102))
    band.save(OUT / f"enc_leader_banner_{color}.png"); print(f"enc_leader_banner_{color}", band.size)
    vs = Image.open(fetch("res/trainers/classes/.shared/vs.png"))
    vpal = [tuple(vs.getpalette()[i * 3:i * 3 + 3]) for i in range(256)]
    flat(vs.crop((0, 0, 64, 64)), vpal).save(OUT / "enc_vs.png")
    flat(vs.crop((0, 65, 64, 129)), vpal).save(OUT / "enc_vs_outline.png")
    print("enc_vs / enc_vs_outline 64×64")
    fp = Image.open(fetch_fr(f"graphics/trainers/front_pics/leader_{name}_front_pic.png"))
    v = fetch_fr(f"graphics/trainers/palettes/leader_{name}.pal").read_text().split()
    bpal = [tuple(int(c) for c in v[3 + i * 3:6 + i * 3]) for i in range(int(v[2]))]
    face = flat(fp, bpal).crop((8, 0, 56, 32)).resize((96, 64), Image.NEAREST)
    face.save(OUT / f"enc_mugshot_{name}.png"); print(f"enc_mugshot_{name}", face.size)


def main():
    v = fetch("res/trainers/classes/.shared/enc_trainer.pal").read_text().split()
    pal = [tuple(int(c) for c in v[3 + i * 3:6 + i * 3]) for i in range(int(v[2]))]
    for src, name in (("enc_trainer_high", "enc_ball"), ("enc_trainer_low", "enc_ball_small")):
        im = Image.open(fetch(f"res/trainers/classes/.shared/{src}.png"))
        out = Image.new("RGBA", im.size, (0, 0, 0, 0))
        for y in range(im.height):
            for x in range(im.width):
                i = im.getpixel((x, y))
                if i % 16:
                    out.putpixel((x, y), pal[i % len(pal)] + (255,))
        out.save(OUT / f"{name}.png")
        print(name, out.size, out.getbbox())
    leader()


if __name__ == "__main__":
    main()
