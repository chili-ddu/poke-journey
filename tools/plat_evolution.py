"""플래티넘 진화 화면 자산 → assets/ui/plat/evo_bg.png, assets/fx/evo_*.png

  python3 -I tools/plat_evolution.py          # 굽기
  python3 -I tools/plat_evolution.py --spa    # 이미터 값만 찍기(scripts/ui/evolution_screen.gd 의 EMITTERS 가 이 값)

원작 진화 장면(pret/pokeplatinum src/evolution.c)이 쓰는 그림:
  배경  NARC_INDEX_DEMO__EGG__DATA__EGG_DATA(= 알 부화 그림 묶음) 0·1·8번 = res/graphics/egg_hatch/background.png(타일) +
        background.NSCR + 그 PNG 팔레트(두 벌). evolution.c 의 sinnoh_document_NCGR 같은 이름은 diploma.naix 의 번호만 빌려 쓴 것.
        팔레트 0번 색 0(검정)이 원작의 바탕(backdrop) — 색 번호 0 자리는 그 색으로 메운다. 256×192 그대로.
  파티클 res/prebuilt/demo/shinka/data/particle/shinka_demo_particle.narc 의 0번 SPA(이미터 13개, 텍스처 5장).
        evo_glow.png(0번 사분면 → 32×32 빛 알갱이) · evo_star.png(1번 64×64 네 갈래 별) · evo_ray.png(2번 반쪽 → 16×64 빛줄기) ·
        evo_ring_a.png / evo_ring_b.png(3·4번 사분면 → 64×64 고리, 10번 이미터의 텍스처 애니메이션).
받은 원본은 third_party/pokeplatinum/ 에 둔다(이미 있으면 건너뜀). Nintendo / Game Freak / Creatures 저작물 — personal use.
"""
import struct
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import plat_bag as pb   # fetch
import plat_fx          # spa_textures / spa_resources / mirror

ROOT = pb.ROOT
G = "res/graphics/egg_hatch/"
NARC = "res/prebuilt/demo/shinka/data/particle/shinka_demo_particle.narc"
TEX = [(0, "evo_glow", "quad"), (1, "evo_star", None), (2, "evo_ray", "lr"), (3, "evo_ring_a", "quad"), (4, "evo_ring_b", "quad")]


def narc_files(data: bytes) -> list:
    """NARC(BTAF·BTNF·GMIF) → 파일 바이트 목록."""
    o = 16
    assert data[o:o + 4] == b"BTAF"
    size, n = struct.unpack("<IH", data[o + 4:o + 10])
    fat = [struct.unpack("<II", data[o + 12 + 8 * i:o + 20 + 8 * i]) for i in range(n)]
    o += size
    assert data[o:o + 4] == b"BTNF"
    o += struct.unpack("<I", data[o + 4:o + 8])[0]
    assert data[o:o + 4] == b"GMIF"
    base = o + 8
    return [data[base + a:base + b] for a, b in fat]


def background() -> Image.Image:
    tiles = Image.open(pb.fetch(G + "background.png"))
    pal = tiles.getpalette()
    tp = tiles.load()
    _, _, ent = pb.nscr(pb.fetch(G + "background.NSCR").read_bytes())
    back = tuple(pal[0:3])
    im = Image.new("RGB", (256, 192), back)
    px = im.load()
    for i, e in enumerate(ent[:32 * 24]):
        cx, cy = i % 32, i // 32
        t, hf, vf, b = e & 0x3FF, (e >> 10) & 1, (e >> 11) & 1, e >> 12
        tx, ty = (t % 32) * 8, (t // 32) * 8
        for y in range(8):
            for x in range(8):
                ci = tp[tx + (7 - x if hf else x), ty + (7 - y if vf else y)] & 15
                if ci:
                    px[cx * 8 + x, cy * 8 + y] = tuple(pal[(b * 16 + ci) * 3:(b * 16 + ci) * 3 + 3])
    return im


def main():
    spa = narc_files(pb.fetch(NARC).read_bytes())[0]
    if "--spa" in sys.argv:
        for i, r in enumerate(plat_fx.spa_resources(spa)):
            print(i, r)
        return
    background().save(pb.OUT / "evo_bg.png")
    texs = plat_fx.spa_textures(spa)
    fx = ROOT / "assets" / "fx"
    for idx, name, how in TEX:
        im = plat_fx.mirror(texs[idx], how) if how else texs[idx]
        im.save(fx / f"{name}.png")
        print(name, im.size)
    print("evo_bg (256, 192)")


if __name__ == "__main__":
    main()
