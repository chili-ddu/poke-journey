"""트레이너 배틀 경기장(직사각형 필드) → assets/maps/<이름>/{bottom.png, top.png, map.json, preview.png}

  python3 -I tools/frlg_arena.py              모든 경기장
  python3 -I tools/frlg_arena.py arena_pewter_gym

사용자 결정 2026-10-29: 트레이너 배틀은 원작처럼 컷신 뒤 경기장으로 옮겨 싸운다. 원작 배틀 배경이 '배틀이 걸린 장소'로 바뀌듯
(플래티넘 지형 분류: 풀숲·평지·숲·동굴·건물 …), 경기장도 그 장소의 파이어레드 지도 타일로 짠다 — 필드와 그림체가 같다.
필드 FIELD_W×FIELD_H 칸(가운데는 비어 있음 — 원작 배틀처럼 평평), 가장자리는 그 장소의 벽:
  border  바깥 지도(숲): 원작 테두리 무늬(border.bin = 나무)를 RING 칸 두께로 두른다. 여백도 같은 무늬라 숲 한가운데처럼 보인다.
  room    건물 안(체육관): 원작 방을 넓힌다 — 위 벽 띠(top 행)는 원작 그대로 가운데 두고 양옆은 민무늬 벽 열로 늘이고,
          양옆 벽은 원작 왼·오른쪽 열, 아래는 원작 지도 밖(테두리 = 검정).
바닥은 원작 지도에서 걸을 수 있는 칸 중 가장 흔한 메타타일(숲 = 숲 바닥, 체육관 = 모래 바닥)로 채운다.
지도 굽기·테두리 채우기는 tools/frlg_map.py 의 것을 그대로 쓴다(원작 메타타일·팔레트·층 종류 그대로).
필드 위에 STRIP 줄 트레이너 자리를 둔다. 공통 필드에 surface 스타일을 적용한다:
  natural 도로·숲은 자연 지면 그대로, court 체육관만 코트선·몬스터볼 문양을 그린다.
map.json 에 arena: {player: [x, y], trainer: [x, y], field: [x, y, w, h]}(칸) — 플레이어는 필드 가운데에서 두 칸 아래,
트레이너는 필드 밖 위 가운데(싸움에 방해되지 않게, 사용자 결정 2026-10-29).
원작 자료는 Nintendo / Game Freak / Creatures — personal use 로만.
"""
import collections
import importlib.util
import json
import struct
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
spec = importlib.util.spec_from_file_location("fm", ROOT / "tools" / "frlg_map.py")
fm = importlib.util.module_from_spec(spec); spec.loader.exec_module(fm)

FIELD_W, FIELD_H = 10, 16      # 사용자 결정 2026-10-29: 22×14 는 너무 넓어 16×10 으로 줄였다가, 사천왕 방처럼 세로로 긴 코트(10×16, 위아래로 마주 봄)로
RING = 2
STRIP = 6                      # 트레이너 뒤의 빈 바닥과 코트 앞 여유를 포함한 대기 공간.
SIDE_APRON = 2                 # 코트 양옆의 빈 바닥. 화면 밖 나무가 도입 장면까지 붙지 않게 한다.
# Formal courts use pixel-art linework with a red/white ball emblem.
# Inspired by modern games' distinction between natural terrain and marked venues;
# this is an HD-2D adaptation, not a pixel-exact reproduction of an SV court.
COURT_R_OUT, COURT_R_IN = 40.0, 16.0
COURT_ALPHA = 0.8
ARENAS = {
    "arena_silph_rival": {"src":"SilphCo_7F","style":"room","surface":"natural","top":3,"side":1,"plain_col":2},
    "arena_lt_surge_gym": {"src":"VermilionCity_Gym","style":"room","surface":"court","top":3,"side":1,"plain_col":2,"court":((176,144,40),(246,232,162))},
    "arena_erika_gym": {"src":"CeladonCity_Gym","style":"room","surface":"court","top":3,"side":1,"plain_col":2,"court":((69,131,82),(215,233,184))},
    "arena_koga_gym": {"src":"FuchsiaCity_Gym","style":"room","surface":"court","top":3,"side":1,"plain_col":2,"court":((128,84,153),(232,210,237))},
    "arena_sabrina_gym": {"src":"SaffronCity_Gym","style":"room","surface":"court","top":3,"side":1,"plain_col":2,"court":((163,78,121),(242,210,228))},
    "arena_blaine_gym": {"src":"CinnabarIsland_Gym","style":"room","surface":"court","top":3,"side":1,"plain_col":2,"court":((185,82,44),(250,224,176))},
    "arena_giovanni_gym": {"src":"ViridianCity_Gym","style":"room","surface":"court","top":3,"side":1,"plain_col":2,"court":((139,110,68),(232,219,183))},
    "arena_cerulean_gym": {"src":"CeruleanCity_Gym", "style":"room", "surface":"court", "top":3, "side":1, "plain_col":2, "court":((62,132,191),(202,231,244))},
    "arena_mt_moon": {"src": "MtMoon_1F", "style": "border", "surface": "natural", "floor": 0x281, "border_tile": 0x2a3},
    # Natural arenas use the source terrain without painted sports markings.
    "arena_viridian_forest": {"src": "ViridianForest", "style": "border", "surface": "natural"},
    # 1번도로(라이벌 그린, 사용자 요청 2026-10-30): 숲과 같은 바깥 지도 — 테두리 나무와 자연 지면.
    # 바닥은 가장 흔한 칸(212, 노란 모래 줄무늬) 대신 원작 1번도로의 민 풀밭(메타타일 8)
    "arena_route1": {"src": "Route1", "style": "border", "surface": "natural", "floor": 8},
    "arena_pewter_gym": {"src": "PewterCity_Gym", "style": "room", "surface": "court", "top": 3, "side": 1, "plain_col": 2,
                         "court": ((191, 75, 67), (224, 226, 217))},
}


def blocks_of(lay: dict) -> list:
    w, h = lay["width"], lay["height"]
    return list(struct.unpack(f"<{w * h}H", fm.fetch(lay["blockdata_filepath"]).read_bytes()))


def floor_block(lay: dict, blocks: list) -> int:
    """걸을 수 있는(통행 0) 칸 중 가장 흔한 메타타일. 풀숲은 뺀다(경기장엔 풀숲 흔들림이 필요 없다)."""
    pri, sec = fm.tileset_dir(lay["primary_tileset"]), fm.tileset_dir(lay["secondary_tileset"])
    attrs = {}
    for base, d in ((0, pri), (fm.PRIMARY_METATILES, sec)):
        ab = fm.fetch(f"{d}/metatile_attributes.bin").read_bytes()
        for i in range(len(ab) // 4):
            attrs[base + i] = struct.unpack("<I", ab[i * 4:i * 4 + 4])[0]
    count = collections.Counter()
    for b in blocks:
        mid, coll = b & 0x3FF, (b >> 10) & 3
        beh = attrs.get(mid, 0) & 0x1FF
        if coll == 0 and beh != fm.MB_TALL_GRASS and beh not in fm.BLOCKED_BEHAVIORS and beh not in fm.LEDGE_BEHAVIORS:
            count[mid] += 1
    return count.most_common(1)[0][0]


def border_blocks(lay: dict) -> tuple:
    bw, bh = int(lay.get("border_width") or 2), int(lay.get("border_height") or 2)
    bb = struct.unpack(f"<{bw * bh}H", fm.fetch(lay["border_filepath"]).read_bytes()[:bw * bh * 2])
    return bb, bw, bh


def compose(cfg: dict, lay: dict) -> tuple:
    """경기장 칸 배열 [u16](원작 map.bin 형식: 메타타일 | 통행<<10) → (W, H, blocks, player, trainer)."""
    src = blocks_of(lay)
    sw, sh = lay["width"], lay["height"]
    floor = int(cfg["floor"]) if "floor" in cfg else floor_block(lay, src)
    bb, bw, bh = border_blocks(lay)
    if "border_tile" in cfg:
        bb, bw, bh = [cfg["border_tile"]], 1, 1
    solid = lambda mid: (mid & 0x3FF) | (1 << 10)
    if cfg["style"] == "border":
        W, H = FIELD_W + 2 * (RING + SIDE_APRON), STRIP + FIELD_H + 2 * RING
        out = []
        for y in range(H):
            for x in range(W):
                inside = RING <= x < W - RING and RING <= y < H - RING
                fight = RING + SIDE_APRON <= x < W - RING - SIDE_APRON and RING + STRIP <= y < H - RING
                out.append((floor if fight else solid(floor)) if inside else solid(bb[(x % bw) + (y % bh) * bw]))
        top = RING
    else:
        top, side, plain = cfg["top"], cfg["side"], cfg["plain_col"]
        W, H = FIELD_W + 2 * (side + SIDE_APRON), top + STRIP + FIELD_H + 1
        off = (W - sw) // 2                      # 원작 방을 가운데에
        at = lambda x, y: src[x + y * sw]
        out = []
        for y in range(H):
            for x in range(W):
                if y < top:
                    if x < side:
                        b = at(x, y)
                    elif x >= W - side:
                        b = at(sw - (W - x), y)
                    elif side + 1 <= x - off < sw - side - 1:     # 원작 위 벽의 가운데(창·문장). 안쪽 모서리 열(바위 장식)은 뺀다
                        b = at(x - off, y)
                    else:
                        b = at(plain, y)
                    out.append(b)
                elif y < H - 1:
                    if x < side:
                        out.append(at(x, top + 1))
                    elif x >= W - side:
                        out.append(at(sw - (W - x), top + 1))
                    else:
                        fight = side + SIDE_APRON <= x < W - side - SIDE_APRON and y >= top + STRIP
                        out.append(floor if fight else solid(floor))
                else:
                    out.append(solid(bb[(x % bw) + (y % bh) * bw]))
    # 필드는 트레이너 자리 아래. 트레이너는 뒤쪽 빈 바닥을 두고 코트에서 두 줄 물러나 선다.
    fx0, fy0 = (W - FIELD_W) // 2, top + STRIP
    player = (W // 2, fy0 + FIELD_H // 2 + 3)
    trainer = (W // 2, top + STRIP - 2)
    return W, H, out, player, trainer, (fx0, fy0)


def draw_court(img: Image.Image, x0: int, y0: int, w: int, h: int, colors: tuple):
    """Formal court markings on the common battle field (source pixel units)."""
    import math
    px = img.load()
    white = (255, 255, 255, 255)

    def put(x, y, c, a=1.0):
        if 0 <= x < img.width and 0 <= y < img.height:
            r, g, b, _ = px[x, y]
            px[x, y] = (round(r + (c[0] - r) * a), round(g + (c[1] - g) * a), round(b + (c[2] - b) * a), 255)

    cx, cy = x0 + w / 2.0 - 0.5, y0 + h / 2.0 - 0.5
    # The formal gym court keeps its rectangular painted boundary.
    for x in range(x0,x0+w):
        for d in (0,1):
            put(x,y0+d,white)
            put(x,y0+h-1-d,white)
    for y in range(y0,y0+h):
        for d in (0,1):
            put(x0+d,y,white)
            put(x0+w-1-d,y,white)
    # Centre line outside the ball emblem.
    for x in range(x0, x0 + w):
        if abs(x - cx) > COURT_R_OUT:
            for d in (0, 1): put(x, round(cy) + d - 1, white)
    # 몬스터볼 원: 위 반쪽·아래 반쪽 반투명, 바깥·구멍 테두리 흰 2px
    for y in range(int(cy - COURT_R_OUT) - 2, int(cy + COURT_R_OUT) + 3):
        for x in range(int(cx - COURT_R_OUT) - 2, int(cx + COURT_R_OUT) + 3):
            r = math.hypot(x - cx, y - cy)
            if COURT_R_OUT - 2 <= r <= COURT_R_OUT or COURT_R_IN <= r <= COURT_R_IN + 2:
                put(x, y, white)
            elif COURT_R_IN + 2 < r < COURT_R_OUT - 2:
                put(x, y, colors[0] if y < cy else colors[1], COURT_ALPHA)
    # White centre band joins the court line to the ball, leaving its centre open.
    for x in range(int(cx-COURT_R_OUT),int(cx+COURT_R_OUT)+1):
        if abs(x-cx)>=COURT_R_IN:
            for dy in [-1,0]: put(x,round(cy)+dy,white)


def bake(name: str):
    cfg = ARENAS[name]
    info = fm.map_json(cfg["src"])
    src_lay = fm.layout_of(info["layout"])
    W, H, blocks, player, trainer, field0 = compose(cfg, src_lay)
    rel = f"generated/{name}.bin"
    dst = fm.TP / rel
    dst.parent.mkdir(parents=True, exist_ok=True)
    dst.write_bytes(struct.pack(f"<{W * H}H", *blocks))
    lay = dict(src_lay, width=W, height=H, blockdata_filepath=rel)
    b = fm.bake_layout(lay)
    PAD = fm.PAD
    bottom = Image.new("RGBA", ((W + 2 * PAD) * 16, (H + 2 * PAD) * 16), (0, 0, 0, 255))
    bottom.alpha_composite(b["bottom"], (PAD * 16, PAD * 16))
    top = b["top"]
    fm.fill_borders(bottom, top, [(0, 0, W, H, b["border"])], W, H)
    if cfg["surface"] == "court":
        draw_court(bottom, (PAD + field0[0]) * 16, (PAD + field0[1]) * 16, FIELD_W * 16, FIELD_H * 16, cfg["court"])
    solid = b["solid"]
    for x in range(W):
        solid[0][x] = solid[H - 1][x] = 1
    for y in range(H):
        solid[y][0] = solid[y][W - 1] = 1
    out = ROOT / "assets" / "maps" / name
    out.mkdir(parents=True, exist_ok=True)
    bottom.save(out / "bottom.png")
    top.save(out / "top.png")
    data = {"width": W, "height": H, "tile": 16, "pad": PAD,
            "solid": ["".join(str(v) for v in r) for r in solid], "grass": ["0" * W for _ in range(H)], "ledge": ["0" * W for _ in range(H)],
            "start": [player[0] * 16 + 8, player[1] * 16 + 8], "areas": [{"id": name, "x": 0, "y": 0, "w": W, "h": H}], "warps": [],
            "arena": {"surface": cfg["surface"], "style": cfg["style"], "wall_rows": int(cfg.get("top",RING)), "player": list(player), "trainer": list(trainer), "field": [field0[0], field0[1], FIELD_W, FIELD_H]},
            "source": f"pret/pokefirered {cfg['src']} 의 타일로 짠 경기장({cfg['style']}, tools/frlg_arena.py)"}
    (out / "map.json").write_text(json.dumps(data, ensure_ascii=False, indent=0) + "\n")
    preview = bottom.copy()
    preview.alpha_composite(top, (PAD * 16, PAD * 16))
    preview.save(out / "preview.png")
    print(name, W, H, "player", player, "trainer", trainer)


def main():
    names = sys.argv[1:] or list(ARENAS)
    for n in names:
        bake(n)


if __name__ == "__main__":
    main()
