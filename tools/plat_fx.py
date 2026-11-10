"""플래티넘 기술 연출의 파티클 텍스처를 게임용 PNG 로 뽑는다 (4단계, docs/plan-gen4.md) → assets/fx/

  python3 -I tools/plat_fx.py

4세대 기술 연출은 2D 스프라이트가 아니라 SPA(Nitro 파티클) 파일(res/graphics/battle/particles/*.spa)이고,
그 안에 텍스처(" TPS" 블록, A3I5/A5I3 형식)가 들어 있다. 움직임(이미터)은 못 옮기므로 텍스처만 꺼내 게임이 직접 움직인다.
  fire_fang.spa → fang_upper.png / fang_lower.png (64×64, 윗니·아랫니), fire_fang_flame.png (16×32 불길), fire_fang_puff.png (32×32 불덩이)
  g4_*.png     → 파이리 기술들(할퀴기·울음소리·불꽃세례·연막·용의분노·베어가르기·화염방사·회오리불꽃)의 흰 마스크 텍스처(게임에서 색을 입힘)
  g4_claw_strike.png / g4_scary_face.png → res/graphics/battle/moves 의 2D 스프라이트(메탈클로·겁나는얼굴; 이 둘의 .spa 는 빈 파일)
전부 Nintendo / Game Freak 저작물 — personal use 로만.
"""
import json
import struct
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "third_party" / "pokeplatinum" / "res" / "graphics" / "battle" / "particles"
OUT = ROOT / "assets" / "fx"
# spa 파일 → [(텍스처 번호, 출력 이름)]. 텍스처는 흰 알파 마스크(색은 이미터가 입힌다 → 게임에서 modulate).
WANT = {"fire_fang": [(0, "fire_fang_flame"), (1, "fire_fang_puff"), (2, "fang_lower"), (3, "fang_upper")],   # 2번은 이가 위로(아랫니), 3번은 이가 아래로(윗니) — 사용자 지적 2026-10-28
        "scratch": [(1, "g4_claw3")],                 # 세로 발톱 자국 셋 64×64
        "smoke_screen": [(0, "g4_smoke"), (1, "g4_smoke_blob"), (2, "g4_smoke_ring")],
        "slash": [(2, "g4_spark"), (3, "g4_streak")],  # 별 모양 타격 불꽃, 세로 줄
        "fire_spin": [(1, "g4_fire_puff")],
        # 상록숲 적 기술
        "harden": [(0, "g4_star64")],                       # 네 갈래 별 빛 64×64
        "poison_sting": [(1, "g4_bubble"), (3, "g4_needle")],  # 색 있는 거품 32×32, 바늘 32×32(위를 향함)
        "thunder_shock": [(0, "g4_bolt_a"), (1, "g4_bolt_b")],  # 번개 지그재그 두 장(세로)
        "horn_attack": [(2, "g4_horn")],                    # 뿔(원뿔, 검은 테) — 연속찌르기에 씀
        # 이상해씨·꼬북이 계열 기술(사용자 요청 2026-10-28). 색은 각 파일의 이미터 색(spa_resources)을 게임에서 입힌다.
        "leech_seed": [(1, "g4_sprout_a"), (3, "g4_sprout_b"), (5, "g4_sprout_c")],   # 싹(이미 초록)
        "bullet_seed": [(1, "g4_seedball")],                 # 씨앗 구슬(회색 → 씨앗색으로)
        "vine_whip": [(2, "g4_vine_arc")],                   # 채찍 자국 초승달
        "razor_leaf": [(0, "g4_leaf"), (1, "g4_leaf_b")],    # 잎(이미 초록)
        "sweet_scent": [(0, "g4_petal_pink"), (2, "g4_fog")],  # 꽃잎, 향기 안개(128×64)
        "double_edge": [(3, "g4_sparkles"), (5, "g4_star5")],
        "worry_seed": [(0, "g4_puff")],                      # 뭉게 구름
        "synthesis": [(1, "g4_ray")],                        # 빛줄기
        "solar_beam": [(2, "g4_beam_glow")],                 # 빔 마디(세로로 긴 빛)
        "petal_dance": [(1, "g4_petal_a"), (4, "g4_petal_b"), (5, "g4_petal_c")],
        "bubble": [(0, "g4_bubble_blue")],
        "withdraw": [(0, "g4_orb_cyan"), (2, "g4_ring_white"), (3, "g4_shell_l"), (4, "g4_shell_r")],
        "water_gun": [(1, "g4_splash"), (2, "g4_droplets")],
        "bite": [(1, "g4_jaw_low"), (2, "g4_jaw_up")],
        "rapid_spin": [(2, "g4_swirl"), (3, "g4_ring_open")],
        "hydro_pump": [(2, "g4_vortex")],
        "flash_cannon": [(1, "g4_flash_star"), (4, "g4_steel_bolt")],
        "rain_dance": [(0, "g4_raindrop")],
        "status_effect": [(4, "g4_duck"), (12, "g4_zzz")],   # 혼란 오리, 잠 Z
        # 회색체육관(웅·캠프보이 리암) 기술 — 트레이너 배틀(사용자 결정 2026-10-29)
        "rock_tomb": [(0, "g4_rock")],                       # 바위 덩어리(이미 회색)
        "defense_curl": [(0, "g4_orb_bubble"), (1, "g4_curl_c")],   # 몸을 감싸는 물방울 막, C 자 고리
        # 기술머신 기술(사용자 결정 2026-10-30, C안): 구멍파기·소금물·기가드레인·깨뜨리다·오물폭탄·객기
        "dig": [(0, "g4_dust"), (1, "g4_rock_chunk")],              # 흙먼지 64×64(흰 마스크), 바위 조각 32×32(이미 회색)
        "brine": [(1, "g4_water_drop"), (3, "g4_brine_splash")],   # 물기둥 64×64, 물보라 32×32
        "giga_drain": [(2, "g4_drain_star"), (3, "g4_drain_ring")],  # 별 16×16, 고리 32×32
        "brick_break": [(2, "g4_cube")],                             # 조각(정육면체) 32×32
        "sludge_bomb": [(1, "g4_sludge_bubble"), (3, "g4_sludge_blob")],   # 거품 32×32(하늘 → 보라로 물들임), 오물 덩이 64×64
        "facade": [(1, "g4_facade_burst"), (2, "g4_facade_dots")],  # 타격 별 32×32, 흰 점들 32×32
        # 최신 습득표로 들어온 기술(사용자 결정 2026-11-02, A안: 데이터는 최신·연출은 플래티넘 파티클)
        "dragon_breath": [(1, "g4_breath_a"), (2, "g4_breath_b")],        # 숨결 뭉치 16×16 둘(이미터 색 자홍 → 노랑)
        "thunder_wave": [(0, "g4_tw_ring"), (1, "g4_tw_bolt_a"), (2, "g4_tw_bolt_b"), (3, "g4_tw_arcs")],   # 고리 64, 번개 32 둘, 호 64
        "rollout": [(0, "g4_roll_dust"), (1, "g4_roll_rock")],            # 먼지 32, 바위 32
        "rock_polish": [(0, "g4_polish_star"), (1, "g4_polish_streak")],  # 별빛 64, 세로 빛줄기 16
        "bug_bite": [(0, "g4_bugbite_mark")],                            # 물린 자국 16
        "earthquake": [(0, "g4_quake_rock")],                            # 땅고르기(5세대, 플래티넘엔 없음)용 바위 32
        # 볼이 열릴 때(원작 pokeballs/open_poke_ball.spa — 내보내기·시작 연출의 볼, 사용자 지적 2026-10-30: 흰 원은 원작이 아니었다)
        "pokeballs/open_poke_ball": [(0, "g4_ballopen_spark"), (1, "g4_ballopen_glow"), (2, "g4_ballopen_ray")]}
# 반쪽/사분면만 든 텍스처는 거울로 완성한다: (spa, 번호, 출력 이름, 방식)
MIRROR = [("ember", 0, "g4_flame", "lr"),           # 불꽃 왼쪽 반 16×32 → 32×32
          ("dragon_rage", 0, "g4_glow", "quad"),    # 빛 사분면 16×16 → 32×32
          ("growl", 1, "g4_ring", "quad"),          # 고리 사분면 32×32 → 64×64
          ("fury_attack", 1, "g4_hitburst", "quad"),  # 타격 터짐 사분면 32×32 → 64×64(몸통박치기·뿔·독침·전기쇼크 공통)
          ("status_effect", 10, "g4_shiny", "quad"),
          ("poison_powder", 1, "g4_powder", "quad"),       # 가루 한 알(사분면 빛) — 독가루·수면가루
          ("protect", 0, "g4_protect", "quad"),            # 방어 막
          ("water_pulse", 2, "g4_ring_q", "quad"),         # 물결 고리(사분면 → 원)
          ("take_down", 2, "g4_burst_q", "quad"),          # 들이받기 터짐(뾰족한 별)
          ("solar_beam", 1, "g4_solar_glow", "quad"),      # 솔라빔 모으는 빛
          ("seed_bomb", 0, "g4_smoke_q", "quad"),          # 씨폭탄 연기
          ("bind", 0, "g4_bind_ring", "quad")]             # 조이기 고리(사분면 → 원)          # 씨폭탄 연기  # 이로치 반짝임(common_anims/shiny.s 파티클 27번 이미터 0·1의 텍스처 10) → 네 갈래 빛 64×64
MOVES = ROOT / "third_party" / "pokeplatinum" / "res" / "graphics" / "battle" / "moves"


def bgr555(v: int) -> tuple:
    return ((v & 31) * 8, ((v >> 5) & 31) * 8, ((v >> 10) & 31) * 8)


def spa_textures(data: bytes) -> list:
    """SPA 안의 텍스처들을 RGBA 이미지로. 블록: ' TPS' + info(형식·크기) + 데이터 크기 + 팔레트 오프셋 + 팔레트 크기 …"""
    out, off = [], 0
    while True:
        k = data.find(b" TPS", off)
        if k < 0:
            return out
        info, dsize, poff, psize = struct.unpack("<4I", data[k + 4:k + 20])
        fmt = info & 0xF
        w, h = 8 << ((info >> 4) & 0xF), 8 << ((info >> 8) & 0xF)
        tex = data[k + 32:k + 32 + dsize]
        pal = data[k + poff:k + poff + psize]
        cols = [bgr555(struct.unpack("<H", pal[i:i + 2])[0]) for i in range(0, len(pal) - 1, 2)]
        im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        px = im.load()
        for i, b in enumerate(tex):
            if fmt == 1:        # A3I5: 아래 5비트 색, 위 3비트 알파
                idx, a = b & 31, (b >> 5) * 255 // 7
            elif fmt == 6:      # A5I3
                idx, a = b & 7, (b >> 3) * 255 // 31
            else:
                idx, a = b, 255
            c = cols[idx] if idx < len(cols) else (255, 0, 255)
            px[i % w, i // w] = c + (a,)
        out.append(im)
        off = k + 4


def spa_resources(data: bytes) -> list:
    """SPA 의 이미터(SPLResourceHeader, lib/spl/include/spl_resource.h) 요약: 텍스처 번호·색·색 변화·개수·수명·크기.
    애니메이션 블록(크기 12·색 12·투명도 8·텍스처 12·자식 20)과 동작 블록(중력 8·무작위 8·자석 16·회전 4·충돌면 8·수렴 16)을 건너뛰며 읽는다."""
    import struct as st
    rc = st.unpack("<H", data[8:10])[0]
    c5 = lambda v: ((v & 31) * 8, ((v >> 5) & 31) * 8, ((v >> 10) & 31) * 8)
    off, out = 0x20, []
    for _ in range(rc):
        h = data[off:off + 88]
        flags = st.unpack("<I", h[:4])[0]
        r = {"emit": flags & 15, "tex": h[71], "color": c5(st.unpack("<H", h[34:36])[0]),
             "count": st.unpack("<i", h[16:20])[0] / 4096, "radius": st.unpack("<i", h[20:24])[0] / 4096,
             "vel": st.unpack("<i", h[36:40])[0] / 4096, "scale": st.unpack("<i", h[44:48])[0] / 4096,
             "plife": st.unpack("<H", h[62:64])[0], "elife": st.unpack("<H", h[60:62])[0]}
        o = off + 88
        if (flags >> 8) & 1:
            r["scale3"] = tuple(v / 4096 for v in st.unpack("<hhh", data[o:o + 6])); o += 12
        if (flags >> 9) & 1:
            a2, b2 = st.unpack("<HH", data[o:o + 4]); r["color_anim"] = (c5(a2), c5(b2)); o += 12
        if (flags >> 10) & 1:
            o += 8
        if (flags >> 11) & 1:
            r["tex_anim"] = list(data[o:o + data[o + 8]]) if data[o + 8] <= 8 else list(data[o:o + 8]); o += 12
        if (flags >> 16) & 1:
            r["child_tex"] = data[o + 15]; r["child_color"] = c5(st.unpack("<H", data[o + 10:o + 12])[0]); o += 20
        o += sum(((flags >> b) & 1) * n for b, n in zip(range(24, 30), (8, 8, 16, 4, 8, 16)))
        out.append(r)
        off = o
    return out


def dump(out_dir: Path):
    """조사용: particles 폴더의 모든 .spa 텍스처를 <이름>_<번호>.png 와 ×4 미리보기 시트로."""
    import sys
    out_dir.mkdir(parents=True, exist_ok=True)
    for spa in sorted(SRC.glob("*.spa")):
        texs = spa_textures(spa.read_bytes())
        if not texs:
            continue
        w = sum(t.width * 4 + 8 for t in texs); h = max(t.height * 4 for t in texs) + 8
        sheet = Image.new("RGBA", (w, h), (40, 120, 80, 255)); x = 4
        for i, t in enumerate(texs):
            t.save(out_dir / f"{spa.stem}_{i}.png")
            sheet.alpha_composite(t.resize((t.width * 4, t.height * 4), Image.NEAREST), (x, 4)); x += t.width * 4 + 8
        sheet.save(out_dir / f"{spa.stem}_sheet.png")
        print(spa.stem, [(t.width, t.height) for t in texs])


def mirror(im: Image.Image, how: str) -> Image.Image:
    """lr: 오른쪽에 좌우 거울. quad: 오른쪽·아래·대각에 거울(사분면 → 전체)."""
    w, h = im.size
    if how == "lr":
        out = Image.new("RGBA", (w * 2, h), (0, 0, 0, 0)); out.paste(im, (0, 0)); out.paste(im.transpose(Image.FLIP_LEFT_RIGHT), (w, 0))
        return out
    out = Image.new("RGBA", (w * 2, h * 2), (0, 0, 0, 0))
    out.paste(im, (0, 0)); out.paste(im.transpose(Image.FLIP_LEFT_RIGHT), (w, 0))
    out.paste(im.transpose(Image.FLIP_TOP_BOTTOM), (0, h)); out.paste(im.transpose(Image.ROTATE_180), (w, h))
    return out


def jasc(path: Path) -> list:
    lines = path.read_text().split("\n"); n = int(lines[2])
    return [tuple(int(v) for v in l.split()) for l in lines[3:3 + n]]


def indexed(path: Path, pal: list) -> Image.Image:
    im = Image.open(path); out = Image.new("RGBA", im.size, (0, 0, 0, 0)); px = out.load()
    for y in range(im.height):
        for x in range(im.width):
            i = im.getpixel((x, y))
            if i:
                px[x, y] = pal[i % len(pal)] + (255,)
    return out


def row_groups(im: Image.Image) -> list:
    """내용이 있는 행 덩어리들 [(y0, y1)]."""
    rows = [y for y in range(im.height) if im.crop((0, y, im.width, y + 1)).getbbox()]
    groups, start, prev = [], None, None
    for y in rows:
        if start is None:
            start = y
        elif y != prev + 1:
            groups.append((start, prev + 1)); start = y
        prev = y
    if start is not None:
        groups.append((start, prev + 1))
    return groups


def scary_face_sprite():
    """Rebuild the original OAM cells: one mouth, two mirrored eyes.

    mappingType 1 = 64-byte OBJ tile address units; 4bpp = 128 pixels/unit.
    Keep the 64x64 blocks and their original origins, never trim alpha bounds.
    """
    src = Image.open(MOVES / "scary_face.png")
    pal = [tuple(src.getpalette()[i*3:i*3+3]) for i in range(16)]
    face = indexed(MOVES / "scary_face.png", pal)
    data = json.loads((MOVES / "scary_face_cell.json").read_text())
    assert data["mappingType"] == 1 and data["cellCount"] == 4
    fw, fh = 128, 100
    out = Image.new("RGBA", (fw, fh*4), (0,0,0,0))
    for k, cell in enumerate(data["cells"]):
        assert cell["oamCount"] == 3
        for obj in reversed(cell["OAM"]):
            a0, a1, a2 = obj["Attr0"], obj["Attr1"], obj["Attr2"]
            assert a0["Shape"] == 0 and a1["Size"] == 3 and not a0["Rotation"]
            top = a2["CharName"] * 128 // face.width
            piece = face.crop((0,top,64,top+64))
            flags = a1["RotationScaling"]
            if flags & 8: piece = piece.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
            if flags & 16: piece = piece.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
            out.alpha_composite(piece,(a1["XCoordinate"]+64,k*fh+a0["YCoordinate"]+40))
    out.save(OUT / "g4_scary_face.png")
    print("g4_scary_face",out.size,"original OAM: mouth x1, eyes x2")


def sprites():
    """파티클이 아닌 2D 스프라이트 연출: 발톱(claw.png, 5프레임 64×64 세로) · 겁나는얼굴(scary_face.png, 4프레임: 이빨 띠 + 눈 → 거울로 얼굴)."""
    claw = indexed(MOVES / "claw.png", jasc(MOVES / "claw.pal"))
    # 시트는 64×64 프레임 다섯 장 사이에 1px 구분선이 있다(324 = 5×64 + 4).
    frames = [claw.crop((0, i * 65, 64, i * 65 + 64)) for i in range(5)]
    sheet = Image.new("RGBA", (64, 64 * len(frames)), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        sheet.paste(f, (0, i * 64))
    sheet.save(OUT / "g4_claw_strike.png"); print("g4_claw_strike", sheet.size)
    scary_face_sprite()
    # 실뿜기: moves/string_shot.png — 64×64 에 휘어진 실 가닥 여덟 줄(8px 간격). 그대로 쓴다(게임이 가닥을 늘려 그림).
    th = Image.open(MOVES / "string_shot.png")
    indexed(MOVES / "string_shot.png", [tuple(th.getpalette()[i * 3:i * 3 + 3]) for i in range(16)]).save(OUT / "g4_thread.png")
    print("g4_thread", th.size)


def main():
    import sys
    if "--dump" in sys.argv:
        dump(Path(sys.argv[sys.argv.index("--dump") + 1]))
        return
    OUT.mkdir(parents=True, exist_ok=True)
    for spa, items in WANT.items():
        texs = spa_textures((SRC / f"{spa}.spa").read_bytes())
        for idx, name in items:
            texs[idx].save(OUT / f"{name}.png")
            print(name, texs[idx].size, "bbox", texs[idx].getbbox())
    for spa, idx, name, how in MIRROR:
        im = mirror(spa_textures((SRC / f"{spa}.spa").read_bytes())[idx], how)
        im.save(OUT / f"{name}.png"); print(name, im.size)
    sprites()


if __name__ == "__main__":
    main()
