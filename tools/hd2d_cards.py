#!/usr/bin/env python3
"""HD-2D 2단계 시제품(사용자 요청 2026-11-02 태초마을): 지도에서 '서 있는' 칸을 골라 3D 로 세울 카드 아틀라스를 만든다.

  python3 tools/hd2d_cards.py [지도 이름 …]      # 기본 kanto_south

서 있는 칸 = 위층(top.png, 원작에서 캐릭터를 덮는 나무 윗부분·지붕)이 있는 칸, 또는 막힌 칸(나무 밑동·벽·울타리·표지판).
  물(막혔고 파란 픽셀이 대부분이며 위가 막히지 않았고 옆에 물이 붙은 칸)은 바닥에 그대로 둔다 — 창문 벽·표지판은 선다.
카드 하나 = 물체 한 줄(나무 한 그루, 집 한 채의 세로 한 줄): 세로로 이어진 서 있는 칸을 '위층이 시작되는 칸'에서 끊는다(아래 주석).
  그 묶음의 밑단(남쪽 가장자리)에 높이를 고정해 세운다(View3D) — 낮은 각도에서 물체가 우뚝 서고 뒤를 가린다.
카드 그림 = 아래층(막힌 칸만) + 위층. 나무 밑동처럼 풀밭 위에 선 칸은 이웃 풀밭 칸의 색을 투명하게 빼서 서 있는 카드에 풀이 붙지 않게
  (그림자도 나무 모양으로 진다). 길 위의 건물 벽은 빼지 않는다(풀색일 때만).
출력: assets/maps/<지도>/hd2d_atlas.png(폭 16px 띠, 같은 그림은 한 번) + hd2d_floor.png(세운 자리를 맨바닥으로 메운 바닥) + hd2d_cards.json
  {"tile", "cards": [[x, 맨 위 y, 칸 수, 아틀라스 x, 아틀라스 y, 지붕 칸 수, 높이 배율, 들어 올린 각도(꽃·수풀, °)], …]}
"""
import json
import os
import re
import struct
import sys
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
T = 16
CENTER_MAPS = {"viridian_center", "pewter_center", "cerulean_city_pokemon_center_1f", "vermilion_city_pokemon_center_1f", "saffron_city_pokemon_center_1f", "route4_pokemon_center_1f"}
MART_MAPS = {"viridian_mart", "pewter_mart", "cerulean_city_mart", "vermilion_city_mart", "saffron_city_mart"}


def native_fence_cells(j: dict) -> dict:
    """Keep General-tileset fence turns separate from building/cliff columns."""
    if not j.get("source", "").startswith("pret/pokefirered "):
        return {}
    import frlg_map as fm
    fence_ids = {0x0e7, 0x0ed, 0x0ee, 0x0ef, 0x0f4, 0x0f5, 0x0f6, 0x0f7}
    areas = {a["id"]: a for a in j.get("areas", [])}
    cells = {}
    for folder in re.findall(r"([A-Za-z][A-Za-z0-9_]*)\(\d", j["source"]):
        area = areas.get(fm.snake(folder))
        if area is None:
            continue
        layout = fm.layout_of(fm.map_json(folder)["layout"])
        # Metatile IDs are local to a tileset; indoor tiles with the same ID
        # must still participate in furniture/building grouping.
        if layout["primary_tileset"] != "gTileset_General":
            continue
        w, h = layout["width"], layout["height"]
        if (w, h) != (area["w"], area["h"]):
            continue
        blocks = struct.unpack(f"<{w*h}H", fm.fetch(layout["blockdata_filepath"]).read_bytes())
        cells.update({(area["x"] + i % w, area["y"] + i // w): block & 0x3ff
                      for i, block in enumerate(blocks) if block & 0x3ff in fence_ids})
    return cells


def center_objects(d, name, tables):
    """Promoted audited source assets; runtime never reads docs or tools."""
    if name not in CENTER_MAPS:
        return []
    source = ROOT / "assets/tiles/center_objects"
    im = Image.open(source / "counter.png").convert("RGBA")
    im.crop((0, 0, 112, 31)).save(d / "hd2d_table0_top.png")
    im.crop((0, 31, 112, 39)).save(d / "hd2d_table0_front.png")
    im.crop((40, 31, 41, 39)).save(d / "hd2d_table0_side.png")
    tables[0] = {"counter": True, "x0": 4.0, "x1": 11.0, "z0": 2.0625, "z1": 4.0,
                 "h": 0.5, "inner_z": 3.3125, "arm": 1.0, "tex": "hd2d_table0"}
    bounds = json.loads((source / "provenance.json").read_text())["bounds"]
    extra = []
    for name in ["vase_left", "vase_right", "counter_nameplate"]:
        sprite = Image.open(source / (name + ".png"))
        tex = "hd2d_table_" + name
        sprite.save(d / (tex + "_front.png"))
        x0, y0, x1, y1 = bounds[name]
        extra.append({"card": True, "x0": x0/T, "x1": x1/T, "z0": 4+(y1-55)/T,
                      "z1": 4+(y1-55)/T, "base": 0.5, "h": sprite.height/T, "tex": tex})
    # Nurse-facing inset plate lies flush with the counter, not upright.
    plate = extra[2]
    plate.update({"decal": True, "z0": 3.5, "z1": 3.9375, "base": 0.502})
    for vase in extra[:2]:
        path = d / (vase["tex"] + "_front.png")
        flowers = Image.open(path).convert("RGBA")
        flowers.crop((0,0,flowers.width,9)).save(path)
        vase.update({"base": 0.8125, "h": 9/T, "z0": 3.625, "z1": 3.625, "counter_vase": True})
    # Separate the original foliage from the pot; the latter is a tapered solid.
    plant_path = d / "hd2d_table2_front.png"
    plant = Image.open(plant_path).convert("RGBA")
    plant.crop((0,0,16,18)).save(plant_path)
    tables[2].update({"base": 0.5625, "h": 18/T, "z0": 2.375, "z1": 2.375,
                      "planter": True})
    # Machine has its own support inside the U; it must not float over the opening.
    machine = Image.open(source / "healing_device.png")
    # The device is a recessed tray: full top art, raised rim, crosses on both ends.
    machine.save(d / "hd2d_table3_top.png")
    edge = machine.crop((0, machine.height - 5, machine.width, machine.height))
    edge.save(d / "hd2d_table3_front.png")
    _side_tex(edge, 20, 3).save(d / "hd2d_table3_side.png")
    x0, y0, x1, y1 = bounds["healing_device"]
    tables[3] = {"box": True, "closed": True, "x0": x0/T, "x1": x1/T,
                 "z0": 2.0625, "z1": 3.3125, "base": 0.5,
                 "h": 6/T, "recess": 2/T, "tex": "hd2d_table3"}
    tex = "hd2d_table_machine_support"
    im.crop((40, 22, 72, 23)).resize((32, 12), Image.Resampling.NEAREST).save(d / (tex+"_top.png"))
    trim = im.crop((40, 31, 41, 39))
    trim.resize((32, 8), Image.Resampling.NEAREST).save(d / (tex+"_front.png"))
    trim.save(d / (tex+"_side.png"))
    extra.append({"box": True, "x0": 5.0, "x1": 7.0, "z0": 2.0625, "z1": 3.3125,
                  "h": 0.5, "tex": tex})
    for stool in tables[7:11]:
        stool["closed"] = True
    return extra


def _tile(im: Image.Image, x: int, y: int, pad: int = 0) -> Image.Image:
    return im.crop(((x + pad) * T, (y + pad) * T, (x + pad + 1) * T, (y + pad + 1) * T))


def _blue_ratio(tile: Image.Image) -> float:
    px = tile.get_flattened_data() if hasattr(tile, "get_flattened_data") else tile.getdata()
    return sum(1 for r, g, b, a in px if b > r + 30 and b > g + 5) / float(T * T)


# 빛·그림자 한 칸(바닥에 붙은 꽃·수풀이 솟아 보이게): 바탕(가장 흔한 색)이 아닌 픽셀 = 꽃잎·풀잎.
#   그림자: 잎 픽셀에서 3D 해 그림자 방향(화면 왼쪽 위, SHADOW_STEP)으로 한 칸 옆이 바탕이면 그 바탕을 어둡게(RELIEF_DARK).
#   빛: 해를 받는 쪽(오른쪽 아래) 이웃이 바탕인 잎 가장자리 픽셀은 밝게(RELIEF_LIT).
FLORA_TILT = 25                 # 꽃·수풀 판을 바닥에서 들어 올리는 각도(°)
SHADOW_STEP = (-1, -1)
RELIEF_DARK = 0.72
RELIEF_LIT = 1.18


def _relief(t: Image.Image) -> Image.Image:
    from collections import Counter
    src = t.convert("RGBA")
    px = src.load()
    base = Counter(src.getdata()).most_common(1)[0][0]
    out = src.copy()
    op = out.load()
    W, H = src.size
    leaf = [[px[x, y] != base and px[x, y][3] > 0 for x in range(W)] for y in range(H)]
    sx, sy = SHADOW_STEP
    for y in range(H):
        for x in range(W):
            if not leaf[y][x]:
                continue
            nx, ny = x + sx, y + sy
            if 0 <= nx < W and 0 <= ny < H and not leaf[ny][nx]:
                r, g, b, a = op[nx, ny]
                op[nx, ny] = (int(r * RELIEF_DARK), int(g * RELIEF_DARK), int(b * RELIEF_DARK), a)
            lx, ly = x - sx, y - sy
            if 0 <= lx < W and 0 <= ly < H and not leaf[ly][lx]:
                r, g, b, a = px[x, y]
                op[x, y] = (min(255, int(r * RELIEF_LIT)), min(255, int(g * RELIEF_LIT)), min(255, int(b * RELIEF_LIT)), a)
    return out


def _green(c) -> bool:
    r, g, b = c[:3]
    return g > r and g >= b


# ── 탁자 재구성(사용자 2026-11-02 오박사 연구소: '다리를 0.5 정도 축으로 만들고 위에 판을 평평하게') ──
# 원작 탁자 그림(비스듬히 내려다본 윗판 + 앞 띠 + 그 아래 다리·서랍)을 잘라 3D 탁자로: 다리 LEG_H(0.5m) 위에 평평한 판.
# 한 탁자 = 지도 안 픽셀 좌표(패딩 제외):
#   x0·x1 판의 가로(끝 제외) · top 윗판 첫 줄 · band 앞 띠 첫 줄(= 판 두께) · under 다리·서랍 첫 줄 · bottom 다리 끝 다음 줄
#   z0·z1 3D 바닥 위 깊이(칸) — 원래 막힌 칸 줄 안에 들어가게(벽 앞 책상은 벽에서 0.4칸: 앞에 선 포켓몬이 파묻히지 않게)
#   legs [[a, b), …] 다리 열 — 하나면 왼쪽 다리만(오른쪽은 서랍장) · pedestal [a, b) 서랍장 열(바닥까지 닿는 작은 상자)
#   apron  다리 사이 띠(판 밑에 매달린 틀)를 그릴지 · twin  같은 탁자가 dx 옆에 깨끗이 있으면 dx — 다른 픽셀(컴퓨터)은 판 위에 세운 카드로
#   floor_y  이 줄부터 바닥(위는 벽) · wall_x·wall_rows  지운 벽 자리를 메울 걸레받이 열과 줄 범위
LEG_H = 0.5
TABLES = {
    "oaks_lab": [
        {"x0": 128, "x1": 176, "top": 67, "band": 85, "under": 88, "bottom": 92, "z0": 4.0, "z1": 5.0,
         "legs": [[129, 134], [170, 175]], "apron": False, "floor_y": 0},
        {"x0": 32, "x1": 64, "top": 21, "band": 32, "under": 34, "bottom": 40, "z0": 2.0, "z1": 2.4,
         "legs": [[33, 37]], "pedestal": [52, 63], "apron": True, "twin": 32, "floor_y": 32, "wall_x": 100, "wall_rows": [26, 32]},
        {"x0": 64, "x1": 96, "top": 21, "band": 32, "under": 34, "bottom": 40, "z0": 2.0, "z1": 2.4,
         "legs": [[65, 69]], "pedestal": [84, 95], "apron": True, "floor_y": 32, "wall_x": 100, "wall_rows": [26, 32]},
        # 가운데 책장 두 줄(사용자 2026-11-02 '바닥이 꺾여 이상하다'): 원작 그림은 위층(7.6칸)부터 9.5칸까지라 2칸 상자로 세우면
        # 윗줄 책이 윗면으로 눕고 아랫단은 바닥에 깔렸다 → 윗면(top~front) + 선 앞면(front~bottom) 상자로. 메우기는 같은 열에서.
        {"kind": "box", "x0": 0, "x1": 80, "top": 121, "front": 134, "bottom": 152, "z1": 9.0, "fill": "column", "floor_y": 0, "shadow": 5},
        {"kind": "box", "x0": 128, "x1": 208, "top": 121, "front": 134, "bottom": 152, "z1": 9.0, "fill": "column", "floor_y": 0, "shadow": 5},
    ],
    # 주인공 방(사용자 2026-11-02 사물 마저): 막힌 칸이 바닥 넓이 — TV 는 (6,4) 위, 게임기는 (6,5) 위, 침대는 (2,6) 남쪽 끝까지.
    "players_house_2f": [
        {"kind": "box", "x0": 96, "x1": 112, "top": 61, "front": 64, "bottom": 88, "z1": 5.0, "floor_y": 0, "shadow": 1},     # TV(받침 포함)
        {"kind": "box", "x0": 97, "x1": 111, "top": 89, "front": 91, "bottom": 98, "z1": 6.0, "floor_y": 0, "shadow": 1},     # 게임기
        {"kind": "box", "x0": 28, "x1": 52, "top": 78, "front": 107, "bottom": 112, "z1": 7.0, "floor_y": 0, "shadow": 1},    # 침대(매트리스 = 윗면)
    ],
}
# 센터 원본 지우기 범위. 최종 카운터와 소품은 center_objects에서 검증 에셋으로 생성한다.
_CENTER = [{"kind": "box", "x0": 64, "x1": 176, "top": 32, "front": 55, "bottom": 64, "z1": 4.0, "floor_y": 0, "shadow": 2}]
# PC는 바닥까지 내려오는 독립 장비. 사선 벽의 높이 추정에 맡기면 윗부분만 잘린다.
_CENTER.append({"kind": "box", "x0": 176, "x1": 192, "top": 8, "front": 11, "bottom": 40,
                "z1": 2.4, "floor_y": 32, "wall_x": 160, "wall_rows": [8, 32], "shadow": 1})
_CENTER.extend([
    {"kind": "card", "x0": 16, "x1": 32, "top": 12, "bottom": 40, "z0": 2.0, "z1": 2.4, "floor_y": 32, "wall_x": 144, "wall_rows": [12, 32]},
    {"kind": "card", "x0": 80, "x1": 112, "top": 16, "bottom": 44, "z0": 2.6, "z1": 3.25, "base": 0.5, "height": 1.1, "floor_y": 32, "wall_x": 144, "wall_rows": [16, 32]},
])
# 벽걸이는 벽지에서 지우고 별도 판으로: 바닥 가구와 달리 벽 높이에 배치한다.
_CENTER.extend([
    {"kind": "card", "rect": True, "x0": 114, "x1": 140, "top": 9, "bottom": 24, "z0": 2.0, "z1": 2.02,
     "base": 0.75, "floor_y": 32, "wall_x": 144, "wall_rows": [9, 32], "shadow": 0},
    {"kind": "card", "rect": True, "x0": 196, "x1": 226, "top": 11, "bottom": 24, "z0": 2.0, "z1": 2.02,
     "base": 0.75, "floor_y": 32, "wall_x": 144, "wall_rows": [11, 32], "shadow": 0},
])
# Lounge table: horizontal glass top, separate rim and four solid legs,
# using the same construction as Oak's lab tables (original two-tile footprint).
_CENTER.append({"x0": 177, "x1": 207, "top": 97, "band": 121, "under": 124, "bottom": 127,
                "z0": 6.0625, "z1": 7.9375, "legs": [[178,182], [202,206]],
                "apron": False, "floor_y": 0, "keyed_top": True, "shadow": 1, "height_scale": 0.5})
# Low upholstered stools: cushion above a solid plinth, without exposed legs.
for sx, sy in [(177,80), (193,80), (225,96), (225,112)]:
    _CENTER.append({"kind": "box", "x0": sx, "x1": sx+14,
                    "top": sy, "front": sy+11, "bottom": sy+15,
                    "z1": (sy+14)/T, "depth": 14/T,
                    "floor_y": 0, "shadow": 1})
TABLES["viridian_center"] = _CENTER
TABLES["pewter_center"] = _CENTER

# Mart counters and glass cases: original top surface over a solid cabinet.
_MART = [
    {"kind":"box", "x0":0, "x1":48, "top":60, "front":72, "bottom":80,
     "z1":5.0, "depth":1.0, "floor_y":0, "shadow":0},
    {"kind":"box", "x0":48, "x1":64, "top":44, "front":72, "bottom":80,
     "z1":5.0, "depth":3.0, "floor_y":0, "shadow":0},
    {"kind":"card", "trim_left":True, "x0":49, "x1":63, "top":25, "bottom":44,
     "z0":2.1, "z1":2.75, "base":0.5, "height":0.75,
     "floor_y":32, "wall_x":68, "wall_rows":[25,32], "shadow":0},
    {"kind":"box", "x0":16, "x1":48, "top":92, "front":104, "bottom":112,
     "z1":7.0, "depth":1.0, "floor_y":0, "shadow":0},
]
for sx, sw in [(112,32), (160,16)]:
    _MART.append({"kind":"box", "x0":sx, "x1":sx+sw, "top":58,
                  "front":100, "bottom":110, "z1":7.0, "depth":3.0,
                  "floor_y":0, "shadow":2})
for gate in ["forest_gate_south", "forest_gate_north"]:
    TABLES[gate] = [
        {"x0":177,"x1":207,"top":sy,"band":sy+24,"under":sy+27,"bottom":sy+30,
         "z0":(sy)/T,"z1":(sy+30)/T,"legs":[[178,182],[202,206]],
         "apron":False,"floor_y":0,"keyed_top":True,"shadow":1,"height_scale":0.5}
        for sy in [65,113]]
TABLES["viridian_mart"] = _MART
TABLES["pewter_mart"] = _MART
for _city in ("cerulean_city", "vermilion_city", "saffron_city"):
    TABLES[_city+"_mart"] = _MART
    TABLES[_city+"_pokemon_center_1f"] = _CENTER
TABLES["route4_pokemon_center_1f"] = _CENTER

# 회색시티 박물관 1층(사용자 2026-11-02 사물 마저): 노란 줄 칸막이(ㄴ자) = 낮은 계산대 상자 셋 — 노란 띠 = 윗면, 아래 짧은 띠 = 앞면,
# 막힌 칸(15열 2~7행, 7행 15~17열, 17열 7~9행) 남쪽 끝에 선다. 계단 옆 칸막이(11열)는 띠 + 끝 기둥(크림색) 상자.
TABLES["pewter_museum_1f"] = [
    {"kind": "box", "x0": 240, "x1": 256, "top": 32, "front": 121, "bottom": 128, "z1": 8.0, "floor_y": 0, "shadow": 1},
    {"kind": "box", "x0": 256, "x1": 272, "top": 108, "front": 121, "bottom": 128, "z1": 8.0, "floor_y": 0, "shadow": 1},
    {"kind": "box", "x0": 272, "x1": 288, "top": 108, "front": 152, "bottom": 160, "z1": 10.0, "floor_y": 0, "shadow": 1},
    {"kind": "box", "x0": 176, "x1": 192, "top": 80, "front": 126, "bottom": 133, "z1": 8.0, "floor_y": 0, "shadow": 0},
    {"kind": "box", "x0": 176, "x1": 192, "top": 126, "front": 133, "bottom": 158, "z1": 10.0, "floor_y": 0, "shadow": 1},
    *[{"kind":"box","x0":48,"x1":112,"top":sy,"front":sy+18,"bottom":sy+28,
       "z1":zy,"depth":1.125,"floor_y":0,"shadow":0} for sy,zy in [(52,5.0),(100,8.0)]],
]

# Museum upstairs: preserve the display artwork on horizontal tops and solid fronts.
TABLES["pewter_museum_2f"] = [
    {"kind":"box","x0":32,"x1":96,"top":72,"front":112,"bottom":120,
     "z1":7.5,"depth":2.5,"floor_y":0,"shadow":0},
    {"kind":"box","x0":224,"x1":272,"top":64,"front":88,"bottom":96,
     "z1":6.0,"depth":1.5,"floor_y":0,"shadow":0},
    {"kind":"box","x0":128,"x1":144,"top":80,"front":126,"bottom":133,
     "z1":8.0,"floor_y":0,"shadow":0},
    {"kind":"box","x0":128,"x1":144,"top":126,"front":133,"bottom":158,
     "z1":10.0,"floor_y":0,"shadow":0},
]

# 집 식탁(깔개 위, 주인공·라이벌 집 x 97 / 회색시티 민가 x 81): 다리 0.5 위 평평한 판 — 식탁보 윗면(65~90행), 앞 띠(90~92행),
# 다리 열 둘. 막힌 칸 2×2(4~5행) 남쪽 끝에 선다. 색만 보는 누끼로는 식탁보가 깔개 색과 같아 비거나 깔개째 상자가 되었다.
def _dining(dx: int) -> list:
    return [{"x0": 97 + dx, "x1": 127 + dx, "top": 65, "band": 90, "under": 92, "bottom": 96, "z0": 4.0, "z1": 6.0,
             "legs": [[98 + dx, 102 + dx], [122 + dx, 126 + dx]], "apron": False, "floor_y": 0}]
TABLES["players_house_1f"] = _dining(0)
TABLES["rivals_house"] = _dining(0)
TABLES["pewter_house1"] = _dining(-16)
TABLES["pewter_house2"] = _dining(-16)

# Explicit home objects replace fragile automatic wall-component inference.
from home_object_specs import definitions as home_definitions, cutout as home_cutout
from home_stair_specs import definitions as stair_definitions
from home_seat_specs import definitions as seat_definitions, footprint as seat_footprint
for home_name in ["players_house_1f", "players_house_2f", "rivals_house", "pewter_house1", "pewter_house2"]:
    TABLES[home_name].extend(home_definitions(home_name) + stair_definitions(home_name) + seat_definitions(home_name))

# 원작 HOUSE1 공통 민가: 기존 HOUSE2와 같은 식탁/의자·주방 배치이며 벽지/창문은 별개다.
HOUSE1_MAPS = {"cerulean_city_house3", "cerulean_city_house4", "vermilion_city_house1", "vermilion_city_house2", "vermilion_city_house3"}
for _home in HOUSE1_MAPS:
    _objects = [dict(spec, wall_x=72) for spec in home_definitions("pewter_house1")
                if spec["object_id"] not in ("window", "map")]
    TABLES[_home] = _dining(-16) + _objects + seat_definitions("pewter_house1")
_base_seat_footprint = seat_footprint
def seat_footprint(name):
    return _base_seat_footprint("pewter_house1" if name in HOUSE1_MAPS else name)

# 바닥에 눕히는 칸(계단 구멍처럼 아래로 내려가는 것): 세우지 않고 바닥 그림에 그대로. px = 뒷벽 사물로 떼지 않을 가로 범위.
FLAT = {
    "players_house_1f": {"tiles": [(10,2),(10,3),(11,2),(11,3),(12,2),(12,3)], "px": (160,208)},
    # 계단 오른쪽 깔개(10열)도 바닥이다. 빠뜨리면 위 벽과 합쳐져 벽 한 줄이 앞으로 튀어나온다.
    "players_house_2f": {"tiles": [(8, 2), (9, 2), (10, 2), (8, 3), (9, 3), (10, 3)], "px": (124, 176)},
    # 연구소 왼쪽 띠의 모니터 판 둘: 바닥에 붙은 판(사용자 2026-11-02) — 띠처럼 지나다닌다
    "oaks_lab": {"tiles": [(0, 2), (0, 3), (0, 4)], "open": True},
}


def _fit_rows(im: Image.Image, n: int, head: int = 2, tail: int = 1) -> Image.Image:
    """도트 줄 수를 n 으로 — 위 head 줄·아래 tail 줄은 그대로, 가운데 줄을 반복하거나 덜어 낸다(늘여 뭉개지 않게)."""
    rows = [im.crop((0, y, im.width, y + 1)) for y in range(im.height)]
    head = min(head, len(rows))
    tail = min(tail, len(rows) - head)
    mid = rows[head:len(rows) - tail] or [rows[head - 1]]
    want = max(0, n - head - tail)
    if want <= len(mid):
        pick = [mid[len(mid) - want + i] for i in range(want)]          # 덜어 낼 땐 앞쪽 가운데 줄부터
    else:
        pick = [mid[min(len(mid) - 1, i * len(mid) // want)] for i in range(want)]
    out = Image.new("RGBA", (im.width, max(1, n)), (0, 0, 0, 0))
    for y, r in enumerate(rows[:head] + pick + rows[len(rows) - tail:]):
        if y < n:
            out.paste(r, (0, y))
    return out


def _side_tex(front: Image.Image, depth_px: int, col: int) -> Image.Image:
    """옆면: 앞면 col 열의 색을 깊이만큼 늘이고 앞뒤 끝은 앞면 가장자리(외곽선) 열."""
    fp = front.load()
    out = Image.new("RGBA", (max(1, depth_px), front.height), (0, 0, 0, 0))
    op = out.load()
    for y in range(front.height):
        for x in range(out.width):
            op[x, y] = fp[0, y] if x in (0, out.width - 1) else fp[col, y]
    return out


def build_tables(d: Path, name: str, bottom: Image.Image, top: Image.Image, pad: int, solid: list, w: int, h: int):
    """탁자 텍스처를 만들고, 바닥·벽 그림(카드·바닥용 사본)에서 탁자를 지운다. → (탁자 정의, 지운 bottom, 지운 top, 카드에서 뺄 칸)"""
    defs = TABLES.get(name, [])
    if not defs:
        return [], bottom, top, set()
    P = pad * T
    art = bottom.copy()
    art.alpha_composite(top, (P, P))         # 위층 그림은 패딩이 없다
    eb, et = bottom.copy(), top.copy()
    from collections import Counter
    floor_cols = Counter()
    for y in range(h):
        for x in range(w):
            if not solid[y][x]:
                floor_cols.update(_tile(bottom, x, y, pad).getdata())
    floor_keys = {c for c, n in floor_cols.most_common(4)}
    inside = lambda px, py: any(t["x0"] <= px < t["x1"] and min(t["top"], t.get("_dtop", t["top"])) <= py < t["bottom"] for t in defs)

    def keyed(im: Image.Image) -> Image.Image:
        out = im.copy()
        out.putdata([(0, 0, 0, 0) if c in floor_keys else c for c in im.getdata()])
        return out

    out, freed = [], set()
    for i, t in enumerate(defs):
        tex = "hd2d_home_" + t["object_id"] if t.get("source_mask") else "hd2d_table%d" % i
        if t.get("kind") == "card":
            img = art.crop((P + t["x0"], P + t["top"], P + t["x1"], P + t["bottom"]))
            if t.get("source_mask"):
                img = home_cutout(art, t, P)
            pixels = img.load()
            for yy in range(img.height):
                # 초록 잎/무채색 외곽선 사이만 남겨 벽·바닥이 판에 붙지 않게 한다.
                xs = [xx for xx in range(img.width) if (lambda c: (max(c[:3]) - min(c[:3]) < 35 and max(c[:3]) < 225) or (c[1] > c[0] + 20 and c[1] > c[2] + 15))(pixels[xx, yy])]
                for xx in range(img.width):
                    if not t.get("rect") and (not xs or xx < min(xs) or (xx > max(xs) and not t.get("trim_left"))):
                        pixels[xx, yy] = (0, 0, 0, 0)
            if t.get("placement") == "side":
                img = img.transpose(Image.Transpose.ROTATE_90)
            img.save(d / (tex + "_front.png"))
            t["under"] = t["bottom"]
            out.append({"card": True, "x0": t["x0"] / T, "x1": t["x1"] / T, "z0": t["z0"], "z1": t["z1"], "h": t.get("height", img.height / T), "base": t.get("base", 0.0), "tex": tex})
            placement = t.get("placement")
            if placement == "floor":
                out[-1].update(decal=True, z0=t["top"]/T, z1=t["bottom"]/T, base=0.012)
            elif placement == "side":
                out[-1].update(side_card=True, x0=128/T, x1=128/T, z0=25/T, z1=3.5)
            elif placement == "front":
                out[-1].update(z0=3.5, z1=3.5)
            continue
        if t.get("kind") == "box":
            # 상자 가구(책장): 윗면 = top~front 줄(깊이), 앞면 = front~bottom 줄(높이), 옆면 = 앞면 둘째 열 색
            crop = lambda a, b, c, e, im=art: im.crop((P + a, P + b, P + c, P + e))
            topi = crop(t["x0"], t["top"], t["x1"], t["front"])
            if t.get("source_mask"):
                cleaned = home_cutout(art, t, P)
                crop = lambda a, b, c, e: cleaned.crop((a-t["x0"], b-t["top"], c-t["x0"], e-t["top"]))
                topi = crop(t["x0"], t["top"], t["x1"], t["front"])
            front = crop(t["x0"], t["front"], t["x1"], t["bottom"])
            if name in CENTER_MAPS and i == 0:
                topi.paste(art.crop((P + 128, P + 32, P + 160, P + 44)), (16, 0))
            topi.save(d / (tex + "_top.png"))
            front.save(d / (tex + "_front.png"))
            _side_tex(front, topi.height, 1).save(d / (tex + "_side.png"))
            t["under"] = t["bottom"]
            out.append({"box": True, "x0": t["x0"] / T, "x1": t["x1"] / T, "z0": t["z1"] - t.get("depth", topi.height / T), "z1": t["z1"],
                        "h": front.height / T, "tex": tex})
            continue
        x0, x1, ty, band, under, bot = t["x0"], t["x1"], t["top"], t["band"], t["under"], t["bottom"]
        crop = lambda a, b, c, e, im=art: im.crop((P + a, P + b, P + c, P + e))
        dx = t.get("twin", 0)
        clean_top = crop(x0 + dx, ty, x1 + dx, band)
        if t.get("keyed_top"): clean_top = keyed(clean_top)
        depth_px = max(2, int(round((t["z1"] - t["z0"]) * T)))
        _fit_rows(clean_top, depth_px).save(d / (tex + "_top.png"))
        edge = crop(x0, band, x1, under)
        edge.save(d / (tex + "_edge.png"))
        _side_tex(edge, depth_px, 1).save(d / (tex + "_eside.png"))
        leg_px = int(round(LEG_H * T))
        legs = []
        for a, b in t.get("legs", []):
            legs.append([a / T, b / T])
        if t.get("legs"):
            a, b = t["legs"][0]
            lt = _fit_rows(keyed(crop(a, under, b, bot)), leg_px, head=2, tail=1)
            # 다리 끝 줄: 원작은 바닥 그림자·바닥색이 섞여 있어 판 밑에서 픽셀이 떠 보였다 — 다리 외곽선 색으로 막는다
            lp = lt.load()
            for xx in range(lt.width):
                lp[xx, lt.height - 1] = lp[0, 0]
            lt.save(d / (tex + "_leg.png"))
        ped = None
        if t.get("pedestal"):
            a, b = t["pedestal"]
            pf = _fit_rows(keyed(crop(a, under, b, bot)), leg_px, head=2, tail=1)
            pf.save(d / (tex + "_ped.png"))
            _side_tex(pf, depth_px, 1).save(d / (tex + "_pedside.png"))
            ped = [a / T, b / T]
        apron_h = 0.0
        if t.get("apron"):
            ap = keyed(crop(x0, under, x1, bot))
            apx = ap.load()
            # 다리 끝에서 서랍장(없으면 마지막 다리) 앞까지만
            lo = t["legs"][0][1] - x0 if t.get("legs") else 0
            hi = (t["pedestal"][0] if t.get("pedestal") else t["legs"][-1][0]) - x0
            for yy in range(ap.height):
                for xx in range(ap.width):
                    if not lo <= xx < hi:
                        apx[xx, yy] = (0, 0, 0, 0)
            # 매달린 틀만: 아래에서부터 투명 픽셀이 대부분인 줄은 잘라 낸다
            rows = ap.height
            while rows > 0 and sum(1 for xx in range(ap.width) if apx[xx, rows - 1][3] > 0) < ap.width * 0.4:
                rows -= 1
            if rows > 0:
                ap.crop((0, 0, ap.width, rows)).save(d / (tex + "_apron.png"))
                apron_h = rows / T
        decor = None
        if dx:
            # 판 위 물건(컴퓨터): 깨끗한 쌍둥이 탁자와 다른 픽셀 — 판 윗줄부터 위로, 다른 픽셀이 있는 줄까지
            a_img, b_img = crop(x0, 0, x1, band), crop(x0 + dx, 0, x1 + dx, band)
            ap, bp = a_img.load(), b_img.load()
            dec = Image.new("RGBA", a_img.size, (0, 0, 0, 0))
            dp = dec.load()
            for yy in range(a_img.height):
                for xx in range(a_img.width):
                    if ap[xx, yy] != bp[xx, yy]:
                        dp[xx, yy] = ap[xx, yy]
            bb = dec.getbbox()
            if bb:
                dec = dec.crop((0, bb[1], a_img.width, a_img.height))
                dec.save(d / (tex + "_decor.png"))
                decor = {"h": dec.height / T}
                t["_dtop"] = bb[1]
        out.append({"x0": x0 / T, "x1": x1 / T, "z0": t["z0"], "z1": t["z1"], "leg": LEG_H * t.get("height_scale", 1.0), "thick": (under - band) / T * t.get("height_scale", 1.0),
                    "legs": legs, "leg_w": (t["legs"][0][1] - t["legs"][0][0]) / T if t.get("legs") else 0.0,
                    "pedestal": ped, "apron": apron_h, "decor": decor, "tex": tex})
    # 지우기: 벽 줄(floor_y 위)은 벽색(그 줄의 가장 흔한 벽색, 걸레받이 줄은 wall_x 열), 바닥 줄은 가까운 맨바닥 칸의 같은 자리 픽셀.
    bp, tp = eb.load(), et.load()
    plain = [[not solid[y][x] and _tile(top, x, y).getbbox() is None for x in range(w)] for y in range(h)]
    for t in defs:
        y_from = min(t["top"], t.get("_dtop", t["top"]))
        wall_fill = Counter(bottom.crop((P, P + 8, P + w * T, P + 10)).getdata()).most_common(1)[0][0]
        for py in range(y_from, t["bottom"] + t.get("shadow", 1)):   # 원작이 바닥에 그린 그림자 줄까지(3D 는 해 그림자)
            for px in range(t["x0"], t["x1"] + 2):
                if px >= w * T:
                    continue
                if px >= t["x1"] and not t.get("erase_right") and not (t["x1"] <= px < t["x1"] + 2 and py >= t["under"]):
                    continue                     # 오른쪽 2열은 다리 그림자만
                if px < et.width and py < et.height:
                    tp[px, py] = (0, 0, 0, 0)
                if py < t.get("floor_y", 0):
                    wr = t.get("wall_rows")
                    bp[P + px, P + py] = bottom.getpixel((P + t["wall_x"], P + py)) if wr and wr[0] <= py < wr[1] else wall_fill
                else:
                    if t.get("floor_sample"):
                        fx, fy = t["floor_sample"]
                        bp[P + px, P + py] = bottom.getpixel((P + fx*T + px%T, P + fy*T + min(py%T, t.get("floor_sample_max_row",15))))
                        continue
                    tx, ty0 = px // T, py // T
                    best = None
                    if t.get("fill") == "column":
                        # 같은 열에서 가장 가까운(위층 없는, 가구 밖) 칸 — 왼쪽 벽 띠처럼 막힌 칸이어도 그 무늬를 잇는다
                        for r in range(1, h):
                            for ny in (ty0 - r, ty0 + r):
                                if best is None and 0 <= ny < h and _tile(top, tx, ny).getbbox() is None and not inside(tx * T, ny * T) \
                                        and not inside(tx * T, ny * T + T - 1):
                                    best = (tx, ny)
                            if best:
                                break
                    for r in range(1, 9 if best is None else 0):
                        cand = [(tx + ddx, ty0 + ddy) for ddy in range(-r, r + 1) for ddx in range(-r, r + 1)
                                if max(abs(ddx), abs(ddy)) == r and 0 <= tx + ddx < w and 0 <= ty0 + ddy < h and plain[ty0 + ddy][tx + ddx]
                                and not inside((tx + ddx) * T, (ty0 + ddy) * T)]
                        if cand:
                            best = min(cand, key=lambda c: (abs(c[1] - ty0), abs(c[0] - tx)))   # 같은 줄 먼저(벽 밑 그늘 띠가 이어지게)
                            break
                    if best:
                        bp[P + px, P + py] = bottom.getpixel((P + best[0] * T + px % T, P + best[1] * T + py % T))
        # 판·다리가 바닥 쪽에 걸친 칸은 카드로 세우지 않는다(벽 칸은 그대로 — 지운 벽이 선다)
        for ty0 in range(t["top"] // T, (t["bottom"] - 1) // T + 1):
            for tx in range(t["x0"] // T, (t["x1"] - 1) // T + 1):
                if ty0 * T >= t.get("floor_y", 0):
                    freed.add((tx, ty0))
    return out, eb, et, freed


# ── 나무 한 그루(사용자 2026-11-02: 나무 위에 나무가 있을 때 아랫부분을 잘라 표현했지만 이제 나무 하나를 통째로 그려 넣어야 자연스럽다) ──
# 원작 숲은 나무(가로 2칸 · 끝 1칸 + 몸통 2칸)가 2칸 간격으로 겹쳐, 아래 나무의 잎이 위 나무의 밑동을 덮는다. 줄 단위로 끊으면
# 카드마다 다음 나무의 밑동 조각이 붙었다. 홀로 선 나무(1번도로 14,174)를 본으로 잘라 두고, 합친 그림(아래층+위층)에서 나무 끝(위층의
# 뾰족한 잎) 픽셀이 80% 넘게 같은 자리마다 나무 한 그루를 세운다 — 막힌 2×2 칸의 남쪽 끝에 서고(블록 칸 = 물체 넓이), 왼쪽·오른쪽 반을
# 카드 두 장으로. 그 칸들은 일반 카드로 세우지 않는다.
# 나무 본(지도별): 위쪽 두 칸은 위가 깨끗한 나무(top), 나머지는 아래가 깨끗한 나무(bottom)에서 — 상록숲처럼 홀로 선 나무가 없으면
# 겹친 줄의 맨 위 나무 꼭대기 + 맨 아래 나무 밑동으로 짠다. x·y = 그 나무의 왼쪽 위 칸, w·h = 칸 수. 본은 그 지도 그림에서 자른다.
TREE_DEFS = {
	"saffron_city": {"map": "kanto_south", "x": 14, "y": 174, "bottom_y": 174, "w": 2, "h": 3},
    "kanto_rock_pass": {"map": "kanto_south", "x": 14, "y": 174, "bottom_y": 174, "w": 2, "h": 3},
    "arena_pikachu_rescue": {"map": "kanto_south", "x": 14, "y": 174, "bottom_y": 174, "w": 2, "h": 3},
    "kanto_south": {"x": 14, "y": 174, "bottom_y": 174, "w": 2, "h": 3},        # 1번도로 홀로 선 나무(뾰족한 나무 2×3)
    "arena_route1": {"map": "kanto_south", "x": 14, "y": 174, "bottom_y": 174, "w": 2, "h": 3},
    "viridian_forest": {"x": 3, "y": 43, "bottom_y": 51, "w": 3, "h": 4},       # 상록숲 둥근 나무(3×4), 2칸 간격으로 겹친 줄
    "arena_viridian_forest": {"map": "viridian_forest", "x": 3, "y": 43, "bottom_y": 51, "w": 3, "h": 4},
    "arena_forest_rescue": {"map": "viridian_forest", "x": 3, "y": 43, "bottom_y": 51, "w": 3, "h": 4},
}
for _region in ("kanto_north", "kanto_east", "route11"):
    TREE_DEFS[_region] = {"map": "kanto_south", "x": 14, "y": 174, "bottom_y": 174, "w": 2, "h": 3}
TREE_MATCH = 0.8
_tree_cache = {}


def _restore_tree_shading(cutout: Image.Image, source: Image.Image) -> Image.Image:
    """Recover native leaf shades also used by grass, inside the existing silhouette.

    Edge flood-fill cannot distinguish shared palette entries. Restore only colors
    already present on the tree, between surviving pixels on the same row. Exterior
    ground and grass stay transparent; every restored RGBA comes from the source.
    """
    result = cutout.copy()
    palette = {c for c in cutout.getdata() if c[3] > 0}
    for y in range(cutout.height):
        xs = [x for x in range(cutout.width) if cutout.getpixel((x, y))[3] > 0]
        if not xs:
            continue
        for x in range(xs[0], xs[-1] + 1):
            original = source.getpixel((x, y))
            if cutout.getpixel((x, y))[3] == 0 and original in palette:
                result.putpixel((x, y), original)
    return result


def _tree_template(name: str):
    """(본 그림 RGBA — 바닥 투명, 첫 칸 줄의 잎 픽셀 [(x, y, 색)], w, h) 또는 None"""
    if name in _tree_cache:
        return _tree_cache[name]
    td = TREE_DEFS.get(name)
    if td is None and (name.startswith("world_") or name.startswith("safari_zone_")):
        td={"map":"kanto_south","x":14,"y":174,"bottom_y":174,"w":2,"h":3}
    if td is None:
        _tree_cache[name] = None
        return None
    src = td.get("map", name)
    d = ROOT / "assets" / "maps" / src
    j = json.loads((d / "map.json").read_text())
    pad = j.get("pad", 0)
    P = pad * T
    b = Image.open(d / "bottom.png").convert("RGBA")
    t = Image.open(d / "top.png").convert("RGBA")
    comp = b.copy()
    comp.alpha_composite(t, (P, P))
    tx, ty, by, tw, th = td["x"], td["y"], td["bottom_y"], td["w"], td["h"]
    tpl = Image.new("RGBA", (tw * T, th * T), (0, 0, 0, 0))
    tpl.paste(comp.crop((P + tx * T, P + ty * T, P + (tx + tw) * T, P + (ty + 2) * T)), (0, 0))
    if th > 2:
        tpl.paste(comp.crop((P + tx * T, P + (by + 2) * T, P + (tx + tw) * T, P + (by + th) * T)), (0, 2 * T))
    # 바닥 색: 두 본 둘레의 맨땅·풀숲 칸(막히지 않고 위층 없음)
    ground = set()
    for yy0 in {ty, by}:
        for gy in range(yy0 - 2, yy0 + th + 2):
            for gx in range(tx - 3, tx + tw + 3):
                if not (0 <= gy < j["height"] and 0 <= gx < j["width"]):
                    continue
                if j["solid"][gy][gx] == "1" or t.crop((gx * T, gy * T, (gx + 1) * T, (gy + 1) * T)).getbbox() is not None:
                    continue
                ground |= set(b.crop(((gx + pad) * T, (gy + pad) * T, (gx + pad + 1) * T, (gy + pad + 1) * T)).getdata())
    # 누끼: 가장자리에서 바닥색 픽셀로만 번지는 영역만 뺀다(잎의 진한 초록이 풀 무늬 색과 같아 색만 보면 구멍이 났다)
    source_tree = tpl.copy()
    px = tpl.load()
    from collections import deque
    q = deque((x, y) for y in range(tpl.height) for x in range(tpl.width) if x in (0, tpl.width - 1) or y in (0, tpl.height - 1))
    seen = set(q)
    while q:
        x, y = q.popleft()
        if px[x, y][3] > 0 and px[x, y] not in ground:
            continue
        px[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if 0 <= nx < tpl.width and 0 <= ny < tpl.height and (nx, ny) not in seen:
                seen.add((nx, ny))
                q.append((nx, ny))
    tip = [(x, y, px[x, y]) for y in range(T) for x in range(tw * T) if px[x, y][3] > 0]
    # Preserve the original matching fingerprint: this fix must not change placement.
    tpl = _restore_tree_shading(tpl, source_tree)
    _tree_cache[name] = (tpl, tip, tw, th)
    return _tree_cache[name]


def find_trees(name: str, bottom: Image.Image, top: Image.Image, pad: int, w: int, h: int) -> list:
    """나무 왼쪽 위 칸 [(x, y)] — 합친 그림에서 본 나무 첫 칸 줄의 잎 픽셀이 TREE_MATCH 넘게 같은 곳."""
    tt = _tree_template(name)
    if tt is None:
        return []
    tpl, tip, tw, th = tt
    P = pad * T
    comp = bottom.copy()
    comp.alpha_composite(top, (P, P))
    C = comp.load()
    need = TREE_MATCH * len(tip)
    out = []
    for y in range(h - th + 1):
        for x in range(w - tw + 1):
            hit = miss = 0
            for (xx, yy, c) in tip:
                if C[P + x * T + xx, P + y * T + yy] == c:
                    hit += 1
                else:
                    miss += 1
                    if miss > len(tip) - need:
                        break
            if hit >= need:
                out.append((x, y))
    return out


def _is_plant(bottom: Image.Image, top: Image.Image, pad: int, x: int, y: int) -> bool:
    """원작 실내 화분 잎 칸(밝은 연두 164,255,180 + 진한 초록 106,197,106 이 25픽셀씩 넘음)."""
    from collections import Counter
    t = _tile(bottom, x, y, pad).copy()
    t.alpha_composite(_tile(top, x, y))
    c = Counter(p[:3] for p in t.getdata())
    return c[(164, 255, 180)] >= 25 and c[(106, 197, 106)] >= 25


def _indoor_maps() -> set:
    """DungeonDB 에서 "indoor": true 인 장소(건물 안)."""
    import re
    files=("dungeon_db.gd", "kanto_expansion.gd", "cerulean_progression.gd", "rock_pass.gd", "saffron_access.gd", "route11_diglett.gd", "kanto_world.gd")
    src = "\n".join((ROOT / "scripts" / "data" / f).read_text() for f in files if (ROOT / "scripts" / "data" / f).exists())
    return set(re.findall(r'"(\w+)":\s*\{[^{}]*?"indoor":\s*true', src))


WALLOBJ_D = 0.4                # 뒷벽 사물(책장·PC) 상자가 벽에서 나오는 깊이(칸)
INDOOR_BOX_COVER = 0.75        # 건물 안 가구의 위 칸이 이만큼 불투명하면 상자(윗면), 아니면 세운 판
FLOORLIKE = 0.9                 # 건물 안 막힌 칸이 바닥색으로 이만큼 칠해져 있으면 바닥 그림(세우지 않는다)


def build(name: str) -> None:
    if name == "vermilion_harbor":
        from vermilion_harbor import build as departed_harbor
        departed_harbor()
        return
    d = ROOT / "assets" / "maps" / name
    j = json.loads((d / "map.json").read_text())
    if name.endswith("pokemon_center_1f") and (j["width"],j["height"])==(15,10):
        CENTER_MAPS.add(name);TABLES.setdefault(name,_CENTER)
    if name.endswith("_mart") and (j["width"],j["height"])==(11,9):
        MART_MAPS.add(name);TABLES.setdefault(name,_MART)
    w, h, pad = j["width"], j["height"], j.get("pad", 0)
    bottom = Image.open(d / "bottom.png").convert("RGBA")
    top = Image.open(d / "top.png").convert("RGBA")
    solid = [[j["solid"][y][x] == "1" for x in range(w)] for y in range(h)]
    road_logs = []
    if name == "kanto_south":
        from collections import Counter
        for area in j.get("areas", []):
            if area["id"] not in ("route1", "route2"): continue
            for yy in range(area["y"],area["y"]+area["h"]):
                for xx in range(area["x"],area["x"]+area["w"]):
                    tile = _tile(bottom,xx,yy,pad).copy()
                    tile.alpha_composite(_tile(top,xx,yy))
                    colors = Counter(tile.getdata())
                    if colors[(90,57,65,255)]>=40 and colors[(123,74,74,255)]>=35 and colors[(222,197,164,255)]>=12 and colors[(115,205,164,255)]>=40:
                        road_logs.append((xx,yy))
    # 탁자는 따로 짓고(build_tables), 카드·바닥은 탁자를 지운 그림으로 만든다
    tables, bottom, top, freed = build_tables(d, name, bottom, top, pad, solid, w, h)
    # 가구 상자가 실제로 차지하는 칸(3D 바닥 넓이) — 그림이 걸친 칸이 아니라(책장 그림 아랫단이 걸친 줄까지 막혔다)
    import math
    table_freed = set()
    for t_ in tables:
        for zz in range(int(math.floor(t_["z0"])), int(math.ceil(t_["z1"]))):
            for xx in range(int(math.floor(t_["x0"])), int(math.ceil(t_["x1"]))):
                table_freed.add((xx, zz))
    has_top = [[_tile(top, x, y).getbbox() is not None for x in range(w)] for y in range(h)]
    # 물: 파란 픽셀이 대부분인 막힌 칸 중, 위 칸이 막히지 않았거나 물이고 옆(상하좌우)에 같은 칸이 붙은 것.
    # 파란 비율만 보면 창문이 큰 집 벽·표지판까지 물로 걸러져 서지 않았다(2026-11-02).
    ratio = [[_blue_ratio(_tile(bottom, x, y, pad)) if solid[y][x] else 0.0 for x in range(w)] for y in range(h)]
    blue = [[ratio[y][x] > 0.6 for x in range(w)] for y in range(h)]
    water = [[False] * w for _ in range(h)]
    # Native water masks also identify pools surrounded by solid cliffs. Those
    # pools have no open northern neighbour, so colour-only detection misses them.
    water_file=d/"water.json"
    if water_file.exists():
        water_rows=json.loads(water_file.read_text()).get("water",[])
        for y,row in enumerate(water_rows[:h]):
            for x,cell in enumerate(row[:w]):
                if cell=="1":water[y][x]=True
    for y in range(h):              # 위에서 아래로: 위 칸이 '물'인지(파란 벽이 아니라)를 본다
        for x in range(w):
            if water[y][x]:continue
            if not blue[y][x]:
                continue
            if y > 0 and solid[y - 1][x] and not water[y - 1][x]:
                continue
            water[y][x] = any(0 <= x + dx < w and 0 <= y + dy < h and blue[y + dy][x + dx] for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)])
    # 물가(물에 붙은, 파란 픽셀이 1/4 넘는 막힌 칸)도 물로 — 연못 테두리가 낮은 벽처럼 서지 않게.
    for _ in range(2):
        for y in range(h):
            for x in range(w):
                if solid[y][x] and not water[y][x] and ratio[y][x] > 0.25 and any(
                        0 <= x + dx < w and 0 <= y + dy < h and water[y + dy][x + dx] for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]):
                    water[y][x] = True
    # 건물 안: 막혔지만 그림은 바닥인 칸(양옆·아래 가장자리 띠, 보이지 않는 벽)은 바닥에 둔다(사용자 2026-11-02: 건물 안 양옆에
    # 벽이 생겼다 — 막힌 칸을 전부 세워 바닥 띠가 상자 벽으로 섰다). 바닥색 = 막히지 않은 칸들에 나오는 색. 화분·가구는 바닥색이 아니라 선다.
    flat_top = set()            # 바닥에 둔 칸 중 위층 그림(벽 띠)을 바닥 그림에 같이 칠할 칸
    edge_strip = set()          # 건물 안 양옆 바닥 띠 칸(충돌을 연다)
    rep_strip = set()           # 그중 같은 그림 되풀이로 찾은 칸
    indoor = bool(j.get("indoor",False)) or name in _indoor_maps()
    for ft in FLAT.get(name, {}).get("tiles", []):
        freed.add(tuple(ft))
        flat_top.add(tuple(ft))
        if FLAT[name].get("open"):
            edge_strip.add(tuple(ft))
    floor_pal = set()           # 건물 안 바닥색(막히지 않은 칸에 흔한 색) — 가구 카드에서 투명하게 뺀다
    floor_freq = {}
    if indoor:
        from collections import Counter
        fc = Counter()
        for y in range(h):
            for x in range(w):
                if not solid[y][x]:
                    fc.update(_tile(bottom, x, y, pad).getdata())
        total = sum(fc.values())
        floor_pal = {c for c, n in fc.items() if n >= total * 0.002}
        floor_freq = {c: n / float(total or 1) for c, n in fc.items()}
        for y in range(h):
            for x in range(w):
                if solid[y][x] and not has_top[y][x]:
                    px = list(_tile(bottom, x, y, pad).getdata())
                    if sum(1 for c in px if c in floor_pal) >= FLOORLIKE * len(px):
                        freed.add((x, y))
        # 가장자리 띠(왼쪽·오른쪽 열, 맨 아래 줄): 바닥과 색이 다른 어두운 띠도 있다 — 같은 그림이 그 줄에 3번 넘게 되풀이되면 띠로 본다
        # (모서리 화분·가구는 한 번뿐이라 그대로 선다).
        # 양옆 벽 띠는 위층(top.png)에 그려져 있고 맨 아래 줄은 검은 바깥이다 — 아래층+위층을 합친 그림으로 본다.
        def comp(x: int, y: int) -> Image.Image:
            t = _tile(bottom, x, y, pad).copy()
            t.alpha_composite(_tile(top, x, y))
            return t
        lines = [[(0, y) for y in range(2, h)], [(w - 1, y) for y in range(2, h)], [(x, h - 1) for x in range(w)]]
        for line in lines:
            cells = [(x, y) for (x, y) in line if solid[y][x]]
            seen = Counter(comp(x, y).tobytes() for (x, y) in cells)
            for (x, y) in cells:
                if seen[comp(x, y).tobytes()] >= 3:
                    if (x, y) not in table_freed and line is not lines[2] \
                            and sum(1 for c in comp(x, y).getdata() if c[:3] == (0, 0, 0)) < 0.5 * T * T:
                        edge_strip.add((x, y))      # 양옆 바닥 띠(지나다닐 수 있게 연다 — 아래). 검은 바깥은 빼고
                        rep_strip.add((x, y))
                    freed.add((x, y))
                    flat_top.add((x, y))
        for x in range(w):                       # 맨 아래 줄 = 바깥(출입구 매트 조각 포함) — 서면 화면 앞을 검은 판이 막는다
            if solid[h - 1][x]:
                freed.add((x, h - 1))
                flat_top.add((x, h - 1))
        # 띠 팔레트: 되풀이로 찾은 띠 칸들의 색 — 같은 열에서 이 색만 쓰는 칸도 띠(가구 그림을 지운 자리는 무늬가 조금 달라 빠졌다)
        strip_pal = set()
        for (ex, ey) in rep_strip:                  # 되풀이로 찾은 띠만(모니터 판 같은 눕힌 물건 색은 빼고 — 화분 칸이 띠로 잡혔다)
            strip_pal |= set(comp(ex, ey).getdata())
        if strip_pal:
            for ex in (0, w - 1):
                for ey in range(2, h - 1):
                    if solid[ey][ex] and (ex, ey) not in edge_strip and (ex, ey) not in table_freed \
                            and set(comp(ex, ey).getdata()) <= strip_pal:
                        edge_strip.add((ex, ey))
                        freed.add((ex, ey))
                        flat_top.add((ex, ey))
        for y in range(h):
            for x in range(w):
                if solid[y][x] and sum(1 for c in comp(x, y).getdata() if c[:3] == (0, 0, 0)) >= 0.95 * T * T:
                    freed.add((x, y))           # 검은 바깥
                    flat_top.add((x, y))
    if j.get("arena"):
        # The reserved trainer/side floor is solid only to constrain combat.
        # It is still flat ground, not a wall that should stand up and cast shadows.
        arena = j["arena"]
        side = int(arena["wall_rows"]) if arena["style"] == "border" else 1
        end = h - side if arena["style"] == "border" else h - 1
        freed.update((x, y) for y in range(int(arena["wall_rows"]), end)
                     for x in range(side, w - side))
    upright = [[(has_top[y][x] or solid[y][x]) and not water[y][x] and (x, y) not in freed for x in range(w)] for y in range(h)]

    # 꽃·수풀·문도 세운다(사용자 요청 2026-11-02). 꽃 = 걸을 수 있고 빨강·분홍 꽃잎 픽셀이 있는 칸, 수풀 = 지도의 풀숲 칸,
    # 문 = 출입구(warp) 칸 중 바로 위가 서 있는 칸(건물 벽)인 것 — 건물 줄에 이어 붙여 벽과 함께 선다.
    grass = [[j["grass"][y][x] == "1" for x in range(w)] for y in range(h)]

    def _base(t: Image.Image):
        from collections import Counter
        return Counter(t.getdata()).most_common(1)[0][0]

    def _petals(t: Image.Image) -> int:
        px = t.get_flattened_data() if hasattr(t, "get_flattened_data") else t.getdata()
        return sum(1 for r, g, b, a in px if r > 180 and g < 150 and b < 140)

    door = [[False] * w for _ in range(h)]
    warp_tiles = set()
    for wv in j.get("warps", []):
        x, y = int(wv["x"]), int(wv["y"])
        warp_tiles.add((x, y))
        # 명시적으로 눕힌 계단 출입구는 벽 문으로 다시 세우지 않는다.
        if 0 < y < h and 0 <= x < w and (x, y) not in flat_top and not upright[y][x] and upright[y - 1][x]:
            door[y][x] = True
            upright[y][x] = True
    # 꽃은 문을 정한 뒤에(빨간 문도 꽃잎 색이라 꽃으로 한 번 더 잡혔다). 출입구 칸은 꽃이 아니다.
    flower = [[not solid[y][x] and not upright[y][x] and not grass[y][x] and (x, y) not in warp_tiles
               and _petals(_tile(bottom, x, y, pad)) >= 6 and _green(_base(_tile(bottom, x, y, pad))) for x in range(w)] for y in range(h)]

    def ground_colors(x: int, y: int, every: bool = False) -> set:
        """이웃 바닥 칸의 색. 기본은 풀색만(건물 벽이 길 색과 겹쳐 뚫리지 않게), every 면 그 바닥 칸의 색 전부(작은 물체 누끼)."""
        if every:
            # 작은 물체(울타리 등): 둘레 8칸 바닥 색을 모두 — 첫 이웃 하나만 보면 울타리 밑 꽃밭 색만 빠지고 뒤의 마을 바닥이 남았다
            # (사용자 2026-11-02: 울타리에 누끼가 없어 어색).
            cols = set()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    nx, ny = x + dx, y + dy
                    if (dx or dy) and 0 <= nx < w and 0 <= ny < h and not upright[ny][nx] and not water[ny][nx]:
                        cols |= set(_tile(bottom, nx, ny, pad).getdata())
            return cols
        for dx, dy in [(0, 1), (-1, 0), (1, 0), (0, -1), (-1, 1), (1, 1)]:
            nx, ny = x + dx, y + dy
            if 0 <= nx < w and 0 <= ny < h and not upright[ny][nx] and not water[ny][nx]:
                cols = {c for c in _tile(bottom, nx, ny, pad).getdata()}
                return {c for c in cols if _green(c)}
        return set()

    # ── 물체 단위로 묶기(사용자 '각도 더 낮게' 2026-11-02): 칸마다 세우면 높이를 각도에 맞춰 줄여야 이어져 보여서 낮은 각도에서도
    # 물체가 서 보이지 않았다. 세로 줄마다 서 있는 칸이 이어진 묶음(run)을 만들고, '위층이 시작되는 칸'(나무 윗부분)에서 끊어
    # 나무 한 그루·집 한 줄을 카드 한 장으로. 옆 줄(같은 숲·건물)의 끊는 자리도 합친다(경계 숲의 오른쪽 반은 위층이 듬성듬성),
    # 그래도 없으면 6칸이 넘는 묶음만 아래에서부터 2칸씩 끊는다(집 한 채는 5칸이라 통째로).
    border_trees = (j.get("arena",{}).get("style")=="border" or name=="saffron_city") and name in TREE_DEFS
    if border_trees:
        # fill_borders flattens the padding into bottom.png. Detect the same source
        # trees across that full image, including trees straddling the map edge.
        expanded_top=Image.new("RGBA",bottom.size)
        expanded_top.alpha_composite(top,(pad*T,pad*T))
        trees=[(x-pad,y-pad) for x,y in find_trees(name,bottom,expanded_top,0,w+pad*2,h+pad*2)]
    else:
        trees = [] if indoor else find_trees(name, bottom, top, pad, w, h)
    tree_tt = _tree_template(name) if trees else None
    tw_, th_ = (tree_tt[2], tree_tt[3]) if tree_tt else (0, 0)
    tree_cells = {(x + dx, y + dy) for (x, y) in trees for dx in range(tw_) for dy in range(th_)}
    if border_trees and j.get("arena",{}).get("style")=="border":
        # Matching uses only the tree tip. Completing a tree at the rim must not
        # put its trunk into the open floor (or directly in front of the trainer).
        # Keep all detected cells above so the source tree pixels are still erased.
        rim = int(j["arena"]["wall_rows"])
        trees = [(x, y) for x, y in trees
                 if x + tw_ <= rim or x >= w - rim or y + th_ <= rim or y + th_ > h - rim]
    fences = {cell: metatile for cell, metatile in native_fence_cells(j).items()
              if upright[cell[1]][cell[0]] and cell not in tree_cells}
    fence_front = next((cell for cell, mid in fences.items() if mid == 0x0e7), None)
    if fence_front is None:
        fences = {} # Oriented panels require an intact native front texture.
    standing = [[upright[y][x] and (x, y) not in tree_cells and (x, y) not in fences for x in range(w)] for y in range(h)]

    def runs_of(x: int) -> list:
        out, y = [], 0
        while y < h:
            if standing[y][x]:
                y0 = y
                while y < h and standing[y][x]:
                    y += 1
                out.append((y0, y - 1))
            else:
                y += 1
        return out

    def tops_in(x: int, y0: int, y1: int) -> set:
        """그 줄에서 위층이 새로 시작되는 칸(바로 위 칸엔 위층이 없음)."""
        return {y for y in range(y0 + 1, y1 + 1) if has_top[y][x] and not has_top[y - 1][x]}

    all_runs = [runs_of(x) for x in range(w)]
    chunks = []          # (x, y0, y1)
    for x in range(w):
        for (y0, y1) in all_runs[x]:
            cuts = tops_in(x, y0, y1)
            # 옆 줄의 끊는 자리는 그 줄의 묶음이 우리 묶음을 통째로 품을 때만 빌린다(같은 숲·같은 건물) —
            # 집 옆 우체통처럼 짧은 이웃에게서 빌리면 집 벽이 중간에서 끊겼다.
            for nx in (x - 1, x + 1):
                if 0 <= nx < w and any(a <= y0 and y1 <= b for (a, b) in all_runs[nx]):
                    cuts |= tops_in(nx, y0, y1)
            if not cuts and y1 - y0 + 1 > 6:
                cuts = set(range(y1 - 1, y0, -2))
            starts = sorted({y0} | cuts)
            for i, a in enumerate(starts):
                b = (starts[i + 1] - 1) if i + 1 < len(starts) else y1
                chunks.append((x, a, b, "solid"))

    # 건물 안 가구가 아래 걸을 수 있는 칸까지 그려져 있으면(원작 비스듬한 그림 — 책장 아랫단·탁자 다리) 그 칸을 앞면에 이어 붙인다
    # (사용자 2026-11-02: 바닥에 깔려 꺾여 보였다). 카드는 여전히 막힌 칸 남쪽 끝에 서고(ovf 칸만큼 아래로 길어짐), 바닥은 그 자리를 메운다.
    lf_cache = {}
    def local_floor(x: int, y: int) -> set:
        """그 칸 둘레(가까운 것부터)의 맨바닥 칸 색 — 깔개 위 탁자는 깔개 색, 마루 위 화분은 마루 색만 뺀다(방 전체 바닥색을 빼면
        벽·탁자 윗면이 뚫렸다)."""
        if (x, y) in lf_cache:
            return lf_cache[(x, y)]
        cols = set()
        for r in (1, 2):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    nx, ny = x + dx, y + dy
                    if max(abs(dx), abs(dy)) == r and 0 <= nx < w and 0 <= ny < h and ny >= 2 and not upright[ny][nx] \
                            and not solid[ny][nx] and _tile(top, nx, ny).getbbox() is None:
                        cols |= set(_tile(bottom, nx, ny, pad).getdata())
            if cols:
                break
        lf_cache[(x, y)] = cols & floor_pal
        return lf_cache[(x, y)]

    # 누끼 바탕(건물 안): 깨끗한 바닥 칸(모든 픽셀이 바닥색, 위층 없음)에서 출발해 바닥색 픽셀로만 번지는 영역. 물체 외곽선에서
    # 막히므로 외곽선 안쪽의 같은 색(깔개 색 식탁보, 유리 탁자)은 남는다 — 색만 보고 빼면 탁자 윗면이 뚫렸다(2026-11-02).
    # 바깥도 같은 방식(사용자 2026-11-02: 누끼 딴 사물 안쪽까지 뚫린 것이 있다 — 바깥 작은 물체는 이웃 바닥 색을 통째로 빼서
    # 표지판·울타리 안쪽의 같은 색이 뚫렸다). 바깥 바탕색 = 깨끗한 맨땅 칸(막히지 않고 위층·물 아님)에 흔한 색.
    bg = set()
    pass_pal = floor_pal
    y_from = 2 if indoor else 0
    if not indoor:
        from collections import Counter
        gc = Counter()
        for y in range(h):
            for x in range(w):
                if not solid[y][x] and not upright[y][x] and not water[y][x] and _tile(top, x, y).getbbox() is None:
                    gc.update(_tile(bottom, x, y, pad).getdata())
        tot = sum(gc.values()) or 1
        pass_pal = {c for c, n in gc.items() if n >= tot * 0.001}
        # 바깥도 드문 어두운 색(외곽선)은 바닥이 아니다 — 표지판 외곽선 색이 언덕·밑동 색으로 바닥 목록에 들어가 표지판이 통째로 뚫렸다
        pass_pal = {c for c in pass_pal if (c[0] * 3 + c[1] * 6 + c[2]) / 10 >= 100 or gc[c] >= tot * 0.02}
    else:
        # 지나다니게 연 양옆 띠도 바닥(그 위 화분 둘레 띠 색이 남았다 — 사용자 2026-11-02)
        pass_pal = set(floor_pal)
        for (ex, ey) in edge_strip:
            pass_pal |= set(_tile(bottom, ex, ey, pad).getdata())
    # 아주 어두운 색(외곽선)은 바닥이 아니다 — 책장 아랫단 외곽선이 바닥색 목록에 섞여 누끼가 아랫단을 먹었다
    if indoor:
        # 바닥 무늬에 흔한 어두운 색(마루 줄눈 등, 바닥 픽셀의 2% 이상)은 남긴다 — 다 빼면 마루 칸이 바닥으로 안 잡혀 누끼가 사라졌다
        pass_pal = {c for c in pass_pal if (c[0] * 3 + c[1] * 6 + c[2]) / 10 >= 100 or floor_freq.get(c, 0.0) >= 0.02}
    if True:
        from collections import deque
        bp0 = bottom.load()
        q = deque()
        for y in range(y_from, h):
            for x in range(w):
                if ((solid[y][x] and (x, y) not in edge_strip) or upright[y][x] or (not indoor and water[y][x])
                        or (_tile(top, x, y).getbbox() is not None and (x, y) not in edge_strip)):
                    continue
                cols = set(_tile(bottom, x, y, pad).getdata())
                if cols <= pass_pal:
                    for yy in range(T):
                        for xx in range(T):
                            pnt = ((x + pad) * T + xx, (y + pad) * T + yy)
                            if pnt not in bg:
                                bg.add(pnt)
                                q.append(pnt)
        # 칸마다 지나갈 수 있는 색 = 그 칸 둘레 깨끗한 바닥 칸의 색(∩ 바탕색) — 방 전체 바닥색으로 번지면 매트·깔개의 흰색·하늘색을 타고
        # 외곽선 틈으로 화분·유리 탁자·진열대 안까지 뚫렸다(사용자 2026-11-02).
        def clean(x: int, y: int) -> bool:
            if not (0 <= x < w and y_from <= y < h):
                return False
            if (x, y) in edge_strip:
                return True
            return not solid[y][x] and not upright[y][x] and not (not indoor and water[y][x]) and _tile(top, x, y).getbbox() is None
        lp_cache = {}
        def local_pass(tx: int, ty: int) -> set:
            if (tx, ty) not in lp_cache:
                cols = set()
                for r in (0, 1, 2):
                    for dy in range(-r, r + 1):
                        for dx in range(-r, r + 1):
                            if max(abs(dx), abs(dy)) == r and clean(tx + dx, ty + dy):
                                cols |= set(_tile(bottom, tx + dx, ty + dy, pad).getdata())
                    if cols:
                        break
                lp_cache[(tx, ty)] = cols & pass_pal
            return lp_cache[(tx, ty)]
        x_lo, x_hi, y_lo, y_hi = pad * T, (pad + w) * T, (pad + y_from) * T, (pad + h) * T
        while q:
            X, Y = q.popleft()
            for nX, nY in ((X + 1, Y), (X - 1, Y), (X, Y + 1), (X, Y - 1)):
                if x_lo <= nX < x_hi and y_lo <= nY < y_hi and (nX, nY) not in bg \
                        and bp0[nX, nY] in local_pass(nX // T - pad, nY // T - pad):
                    bg.add((nX, nY))
                    q.append((nX, nY))

    def is_bg(x: int, y: int, xx: int, yy: int) -> bool:
        return ((x + pad) * T + xx, (y + pad) * T + yy) in bg

    def non_floor(x: int, y: int) -> int:
        return sum(1 for yy in range(T) for xx in range(T) if not is_bg(x, y, xx, yy))
    ovf_of = {}
    overflow = set()
    if indoor:
        for i, (x, a, b, kind) in enumerate(chunks):
            yb = b + 1
            if yb < h and not upright[yb][x] and not solid[yb][x] and (x, yb) not in freed and non_floor(x, yb) >= 6:
                chunks[i] = (x, a, yb, kind)
                ovf_of[(x, a)] = 1
                overflow.add((x, yb))

    # 꽃·수풀(사용자 2026-11-02): 세우지 않고, 칸의 남쪽 가장자리를 바닥에 붙여 북쪽으로 FLORA_TILT° 만큼만 들어 올린 판으로 —
    # 캐릭터가 그 칸에 서면 발 앞은 낮아 보이고 뒤쪽 잎은 몸 뒤로 서서 꽃밭·풀숲 위를 헤치고 지나가는 느낌. 판 그림은 빛·그림자 한 칸
    # 처리(_relief) 뒤 바탕 풀색을 뺀 꽃잎·풀잎, 바닥은 바탕색으로 메운다. (한때 한 칸짜리 낮은 카드로 세웠고, 그다음 바닥에 붙였다.)
    LOW = {"flower": 1.0, "grass": 1.0}
    # A north/south run is a sequence of low fence panels, never a tall wall
    # with a roof. In particular, do not merge a corner with nearby shrubs.
    chunks.extend((x, y, y, "fence") for x, y in sorted(fences))
    for y in range(h):
        for x in range(w):
            if flower[y][x]:
                chunks.append((x, y, y, "flower"))
            elif grass[y][x] and not upright[y][x]:
                chunks.append((x, y, y, "grass"))

    def keyed(t: Image.Image) -> Image.Image:
        """가장 흔한 색(바탕 풀색)과 이웃 바닥 색을 투명하게 — 꽃잎·풀잎만 남는다."""
        px = list(t.getdata())
        from collections import Counter
        base = Counter(px).most_common(1)[0][0]
        out = Image.new("RGBA", (T, T))
        out.putdata([(0, 0, 0, 0) if c == base else c for c in px])
        return out

    # 카드 그림: 칸마다 아래층(막힌 칸·문, 풀색 빼기) + 위층을 세로로 이어 붙인 띠(16 × 16n).
    wall_override = {}
    def tile_img(x: int, y: int, small: bool = False) -> Image.Image:
        if (x, y) in wall_override:
            return wall_override[(x, y)].copy()
        img = Image.new("RGBA", (T, T), (0, 0, 0, 0))
        if grass[y][x] and not upright[y][x]:
            raw = _tile(bottom,x,y,pad).copy()
            # FRLG pale lawn palette is background; dark olive pixels are blades.
            lawn = {(115,205,164),(65,180,139),(164,230,197),(24,164,106)}
            raw.putdata([(0,0,0,0) if c[:3] in lawn else c for c in raw.getdata()])
            return raw
        if flower[y][x]:
            img.alpha_composite(keyed(_relief(_tile(bottom, x, y, pad))))   # 빛·그림자 한 칸 뒤 바탕 빼기(그림자 픽셀은 남는다)
            return img
        if solid[y][x] or door[y][x] or (x, y) in overflow:
            base = _tile(bottom, x, y, pad)
            # 누끼(사용자 2026-11-02: 모든 사물은 누끼 — 바닥 타일이 위로 올라올 일은 없다): 건물 안은 방 바닥색, 바깥 작은 물체
            # (3칸 이하 — 표지판·울타리·말뚝)는 이웃 바닥 칸의 색 전부, 건물·나무는 풀색만.
            px = list(base.getdata())
            base = Image.new("RGBA", (T, T))
            base.putdata([(0, 0, 0, 0) if is_bg(x, y, i % T, i // T) else c for i, c in enumerate(px)])
            key = set()
            if key:
                px = [(0, 0, 0, 0) if c in key else c for c in base.getdata()]
                base = Image.new("RGBA", (T, T))
                base.putdata(px)
            img.alpha_composite(base)
        img.alpha_composite(_tile(top, x, y))
        return img

    # Lab machine: its white glass shares the floor palette. Restore enclosed
    # cutout holes from the original composite, keeping exterior floor transparent.
    if name == "oaks_lab":
        from collections import deque
        cutout = Image.new("RGBA", (2 * T, 3 * T))
        original = Image.new("RGBA", cutout.size)
        for dy in range(3):
            for dx in range(2):
                x, y = 1 + dx, 3 + dy
                cutout.alpha_composite(tile_img(x, y), (dx * T, dy * T))
                raw = _tile(bottom, x, y, pad)
                raw.alpha_composite(_tile(top, x, y))
                original.alpha_composite(raw, (dx * T, dy * T))
        cw, ch = cutout.size
        outside = set()
        queue = deque((x, y) for y in range(ch) for x in range(cw)
                      if (x in (0, cw-1) or y in (0, ch-1)) and cutout.getpixel((x, y))[3] < 128)
        while queue:
            x, y = queue.popleft()
            if (x, y) in outside:
                continue
            outside.add((x, y))
            for nx, ny in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
                if 0 <= nx < cw and 0 <= ny < ch and (nx, ny) not in outside and cutout.getpixel((nx, ny))[3] < 128:
                    queue.append((nx, ny))
        for y in range(ch):
            for x in range(cw):
                if cutout.getpixel((x,y))[3] < 128 and (x,y) not in outside:
                    cutout.putpixel((x,y), original.getpixel((x,y)))
        for dy in range(3):
            for dx in range(2):
                wall_override[(1+dx,3+dy)] = cutout.crop((dx*T,dy*T,(dx+1)*T,(dy+1)*T))

    # 짧은 충돌 열도 위벽 그림은 두 줄이다. 시계 아래 열린 칸 때문에 벽이 뒤로 꺾이지 않게.
    wall_maps = CENTER_MAPS | { "players_house_1f", "players_house_2f", "rivals_house", "pewter_house1", "pewter_house2"}
    if name in wall_maps:
        for idx, (x, a, b, kind) in enumerate(chunks):
            if kind == "solid" and a == 0 and b == 0:
                chunks[idx] = (x, a, 1, kind)
                upright[1][x] = True
                wall_override[(x, 1)] = _tile(bottom, x, 1, pad)
                wall_override[(x, 1)].alpha_composite(_tile(top, x, 1))

    # 건물 안 뒷벽 = 벽지 + 사물(사용자 2026-11-02: 상단 벽은 벽지와 사물로 나눠야 한다). 원작은 책장·PC·TV 를 벽 그림에 같이 그려
    # 벽 판에 붙어 납작했다. 줄마다 가장 흔한 벽 칸 그림 = 벽지, 벽지와 다른 픽셀 = 사물. 바닥 선까지 닿는 사물(책장·PC·기둥)은 벽에서
    # WALLOBJ_D 만큼 나온 상자로 따로 세우고 그 자리 벽은 벽지로, 바닥에 안 닿는 것(창문·포스터·시계)은 벽지에 그대로 둔다.
    wallobjs = []
    if indoor:
        from collections import Counter, deque
        backc = [(i, x, a, b) for i, (x, a, b, kind) in enumerate(chunks) if kind == "solid" and a == 0]
        rows_of = {x: b + 1 - ovf_of.get((x, a), 0) for (i, x, a, b) in backc}
        backc = [bc for bc in backc if rows_of[bc[1]] <= 3]            # 옆벽처럼 길게 이어진 줄은 빼고
        if backc:
            R = max(rows_of[x] for (_, x, _, _) in backc)
            ref = {}
            for r in range(R):
                cnt = Counter(tile_img(x, r).tobytes() for (_, x, _, _) in backc if rows_of[x] > r)
                if cnt:
                    ref[r] = Image.frombytes("RGBA", (T, T), cnt.most_common(1)[0][0])
            full = Image.new("RGBA", (w * T, (R + 1) * T), (0, 0, 0, 0))
            mask = set()
            cols = {x for (_, x, _, _) in backc}
            for (_, x, a, b) in backc:
                nr = rows_of[x]
                for r in range(nr):
                    t = tile_img(x, r)
                    full.paste(t, (x * T, r * T))
                    rp, tp2 = ref[r].load(), t.load()
                    for yy in range(T):
                        for xx in range(T):
                            if tp2[xx, yy] != rp[xx, yy] and tp2[xx, yy][3] > 0:
                                mask.add((x * T + xx, r * T + yy))
                if ovf_of.get((x, a), 0) and nr < R + 1:
                    t = tile_img(x, nr)
                    full.paste(t, (x * T, nr * T))
                    tp2 = t.load()
                    for yy in range(T):
                        for xx in range(T):
                            if tp2[xx, yy][3] > 0:
                                mask.add((x * T + xx, nr * T + yy))
            if name in CENTER_MAPS:
                # 센터 벽의 주황 무늬는 물건끼리 연결된다. 바닥 가구만 개별 범위로 추출하고
                # 벽걸이 화면·지도·사선 벽은 벽 판에 남긴다.
                bounds = [(34, 11, 64, 40)]
                mask = {(X, Y) for X, Y in mask if any(a <= X < b and c <= Y < d for a, c, b, d in bounds)}
            seen = set()
            standing = set()
            fp = full.load()
            for start in sorted(mask):
                if start in seen:
                    continue
                comp = []
                q = deque([start])
                seen.add(start)
                while q:
                    X, Y = q.popleft()
                    comp.append((X, Y))
                    for dX in (-1, 0, 1):
                        for dY in (-1, 0, 1):
                            nb = (X + dX, Y + dY)
                            if nb in mask and nb not in seen:
                                seen.add(nb)
                                q.append(nb)
                ys = [Y for _, Y in comp]
                xs = [X for X, _ in comp]
                ccols = {X // T for X in xs if X // T in rows_of}
                floor_rows = min(rows_of[c] for c in ccols) if ccols else R
                fpx = FLAT.get(name, {}).get("px")
                if fpx and min(xs) < fpx[1] and max(xs) >= fpx[0]:
                    continue                    # 눕힌 계단 위쪽 난간 등은 벽에 그대로
                if max(ys) < floor_rows * T - 3 or len(comp) < 24:
                    continue                    # 바닥에 안 닿는 것(창문·포스터)·부스러기는 벽지에 남긴다
                # 바닥 선까지 내려오는 열끼리만 한 사물(옆 포스터·액자처럼 픽셀이 닿아 붙은 걸이 물건은 벽지에 남긴다)
                low = {}
                for (X, Y) in comp:
                    low[X] = max(low.get(X, -1), Y)
                reach = sorted(X for X in low if low[X] >= floor_rows * T - 3)
                runs, cur = [], []
                for X in reach:
                    if cur and X != cur[-1] + 1:
                        runs.append(cur)
                        cur = []
                    cur.append(X)
                if cur:
                    runs.append(cur)
                for run in runs:
                    if len(run) < 6:
                        continue
                    rx0, rx1 = run[0], run[-1] + 1
                    part = [(X, Y) for (X, Y) in comp if rx0 <= X < rx1]
                    pys = [Y for _, Y in part]
                    x0p, x1p, y0p, y1p = rx0, rx1, min(pys), max(pys) + 1
                    img = Image.new("RGBA", (x1p - x0p, y1p - y0p), (0, 0, 0, 0))
                    iq = img.load()
                    for (X, Y) in part:
                        iq[X - x0p, Y - y0p] = fp[X, Y]
                        standing.add((X, Y))
                    # 윗면/앞면 나누기: 위에서부터 처음 나오는 '가로로 꽉 찬 어두운 외곽선 줄' 위 = 윗면(책장 윗판·책상 윗면),
                    # 아래 = 앞면. 통째로 앞면이면 벽 높이만 한 판이 되어 벽처럼 보였다(사용자 2026-11-02: 아래 책상처럼 하나 두고 뒤로 벽지).
                    split = 0
                    for yy in range(2, int(img.height * 0.6)):
                        op = [iq[xx, yy] for xx in range(img.width) if iq[xx, yy][3] > 0]
                        dark = sum(1 for c in op if (c[0] * 3 + c[1] * 6 + c[2]) / 10 < 110)
                        if len(op) >= 0.7 * img.width and dark >= 0.6 * len(op):
                            split = yy
                            break
                    center_shelf = name in CENTER_MAPS and 34 <= x0p < 64
                    if center_shelf:
                        # Audited rectangular source: interior gray is cabinet art, not background.
                        y0p, y1p = 11, 40
                        original_bottom = Image.open(d / "bottom.png").convert("RGBA")
                        original_top = Image.open(d / "top.png").convert("RGBA")
                        img = original_bottom.crop((x0p+pad*T, y0p+pad*T, x1p+pad*T, y1p+pad*T))
                        img.alpha_composite(original_top.crop((x0p,y0p,x1p,y1p)))
                        split = 1  # only the top trim bends onto the horizontal cap
                        standing.update((X,Y) for X in range(x0p,x1p) for Y in range(y0p,y1p))
                    tex = "hd2d_wallobj%d" % len(wallobjs)
                    front = img.crop((0, split, img.width, img.height))
                    front.save(d / (tex + "_front.png"))
                    depth = max(WALLOBJ_D, split / T) if split else WALLOBJ_D
                    depth_px = max(2, int(round(depth * T)))
                    _side_tex(front, depth_px, min(1, front.width - 1)).save(d / (tex + "_side.png"))
                    if split:
                        _fit_rows(img.crop((0, 0, img.width, split)), depth_px).save(d / (tex + "_top.png"))
                    else:
                        topi = Image.new("RGBA", (front.width, depth_px), (0, 0, 0, 0))
                        for yy in range(depth_px):
                            topi.paste(front.crop((0, 0, front.width, 1)), (0, yy))
                        topi.save(d / (tex + "_top.png"))
                    wallobjs.append({"box": True, "x0": x0p / T, "x1": x1p / T, "z0": float(floor_rows), "z1": floor_rows + depth,
                                     "h": front.height / T, "tex": tex})
                    if center_shelf:
                        wallobjs[-1]["closed"] = True
            # 벽 판: 세운 사물 자리는 벽지로
            for (_, x, a, b) in backc:
                for r in range(rows_of[x]):
                    t = tile_img(x, r)
                    tp2, rp = t.load(), ref[r].load()
                    hit = False
                    for yy in range(T):
                        for xx in range(T):
                            if (x * T + xx, r * T + yy) in standing:
                                tp2[xx, yy] = rp[xx, yy]
                                hit = True
                    if hit:
                        wall_override[(x, r)] = t
            # 아래 칸까지 그린 사물은 상자가 되었으니 벽 판은 원래 줄 수로
            for idx, (i, x, a, b) in enumerate(backc):
                o = ovf_of.get((x, a), 0)
                if o:
                    xx_, aa_, bb_, kk_ = chunks[i]
                    chunks[i] = (xx_, aa_, bb_ - o, kk_)
                    ovf_of[(x, a)] = 0

    # 건물 안 뒷벽(맨 위 줄부터 선 카드): 위로 한 칸 더 세워 모두 같은 높이로(사용자 2026-11-02: 상단에 한 칸을 더 늘려야 사물을 그려 넣을
    # 칸이 생겨 깨지지 않는다). 가구가 아래 칸까지 그려진 줄(ovf)은 한 칸 길어져 벽 위로 삐죽 솟았다 — 나머지 줄에 위로 벽을 덧대
    # 높이를 맞추고, 맨 위 몰딩(trim)은 덧댄 칸 꼭대기로 옮겨 줄마다 몰딩 높이가 같게.
    raise_of = {}
    wall_trim = 0
    wall_body = None
    if indoor:
        back = [(x, a, b) for (x, a, b, kind) in chunks if kind == "solid" and a == 0]
        if back:
            from collections import Counter
            wall_body = Counter(c for (x, a, b) in back for c in _tile(bottom, x, 0, pad).getdata()).most_common(1)[0][0]
            if name in CENTER_MAPS:
                wall_body = (230, 139, 98, 255)
            # 몰딩 줄 수 = 맨 윗칸에서 처음으로 한 줄 전부가 벽 바탕색인 줄
            for (x, a, b) in back:
                t0 = _tile(bottom, x, 0, pad)
                rows = [r for r in range(T) if all(t0.getpixel((xx, r)) == wall_body for xx in range(T))]
                if rows:
                    wall_trim = rows[0]
                    break
            # 목표 높이 = 가장 흔한 벽 줄 수 + 1(문·계단처럼 한 줄만 긴 줄에 맞추면 벽 전체가 한 칸 더 솟았다)
            target = Counter(b - a + 1 - ovf_of.get((x, a), 0) for (x, a, b) in back).most_common(1)[0][0] + 1
            if name in CENTER_MAPS:
                target -= 1  # 센터는 원본 벽 높이 유지: 높이 확장 없음
            for (x, a, b) in back:
                if b - a + 1 < target:
                    raise_of[(x, a)] = target - (b - a + 1)

    def raised_top(x: int, extra: int) -> Image.Image:
        """뒷벽 위로 덧댈 칸들(extra 칸): 맨 위에 그 줄의 몰딩, 아래는 벽 바탕색."""
        im = Image.new("RGBA", (T, T * extra), wall_body or (0, 0, 0, 0))
        t0 = _tile(bottom, x, 0, pad)
        im.paste(t0.crop((0, 0, T, wall_trim)), (0, 0))
        return im

    strips: list = []
    index: dict = {}
    cards = []
    kind_of = {}
    fence_img = tile_img(*fence_front, small=True) if fences else None
    for (x, a, b, kind) in chunks:
        n = b - a + 1
        extra = raise_of.get((x, a), 0)
        img = Image.new("RGBA", (T, T * (n + extra)), (0, 0, 0, 0))
        if extra:
            img.alpha_composite(raised_top(x, extra), (0, 0))
        for i in range(n):
            # Side metatiles depict a top-down rail. Rotate the intact front
            # artwork in 3D instead of stretching that rail into tall posts.
            ti = fence_img if kind == "fence" else tile_img(x, a + i, small=(kind == "solid" and n <= 3))
            if extra and a + i == 0 and wall_trim:
                # 원래 몰딩 자리는 벽 바탕색으로(몰딩은 덧댄 칸 꼭대기로 옮겼다)
                tp_ = ti.load()
                for yy in range(wall_trim):
                    for xx in range(T):
                        tp_[xx, yy] = wall_body
            img.alpha_composite(ti, (0, (i + extra) * T))
        if extra:
            ovf_of[(x, a - extra)] = ovf_of.pop((x, a), 0)
            a -= extra
            n += extra
        if img.getbbox() is None:
            continue
        k = (n, img.tobytes())
        if k not in index:
            index[k] = len(strips)
            strips.append(img)
        cards.append([x, a, n, index[k]])
        kind_of[(x, a)] = kind
    # Viridian public buildings: tile-layer boundaries must not split one roof
    # into upright columns. All strips share a continuous roof/front division.
    if name in ("kanto_south", "viridian_forest"):
        buildings = [(26,15,4,4),(12,12,7,5),(34,136,4,4),(33,126,6,5),(14,86,8,6),(14,54,8,5),(28,82,5,5)] if name == "kanto_south" else [(0,0,11,10)]
        for bx, by, bw, bh in buildings:
            tails = []
            for c in cards:
                if bx <= c[0] < bx+bw and c[1] < by+bh and c[1]+c[2] > by+bh:
                    count = c[1]+c[2]-(by+bh)
                    tail = strips[c[3]].crop((0,(by+bh-c[1])*T,T,c[2]*T))
                    if name == "viridian_forest":
                        # Below the gate, only the brown fence poles stand upright.
                        tail.putdata([color if color[0]>color[1]+5 and color[0]>color[2]+5 else (0,0,0,0) for color in tail.getdata()])
                    tails.append([c[0],by+bh,count,len(strips)])
                    strips.append(tail)
                    kind_of[(c[0],by+bh)] = "solid"
            cards = [c for c in cards if not (bx <= c[0] < bx+bw and c[1] < by+bh and c[1]+c[2] > by)]
            cards.extend(tails)
            for xx in range(bx,bx+bw):
                strip = Image.new("RGBA", (T,bh*T), (0,0,0,0))
                for yy in range(bh):
                    source_tile = _tile(bottom,xx,by+yy,pad).copy()
                    source_tile.alpha_composite(_tile(top,xx,by+yy))
                    strip.alpha_composite(source_tile, (0,yy*T))
                cards.append([xx,by,bh,len(strips)])
                strips.append(strip)
                kind_of[(xx,by)] = "solid"
                ovf_of[(xx,by)] = 0
    # 나무: 본 그림의 왼쪽·오른쪽 반을 띠 두 장으로(한 번만), 나무마다 카드 두 장
    tree_cards = []
    if trees:
        tpl = tree_tt[0]
        halves = []
        for col in range(tw_):
            im = tpl.crop((col * T, 0, (col + 1) * T, th_ * T))
            k = (th_, im.tobytes())
            if k not in index:
                index[k] = len(strips)
                strips.append(im)
            halves.append(index[k])
        for (x, y) in trees:
            for col in range(tw_):
                tree_cards.append([x + col, y, th_, halves[col]])
    # 띠를 높이별로 선반에 쌓는다(가로 64장).
    cols = 64
    order = sorted(range(len(strips)), key=lambda i: -strips[i].height)
    rects = {}
    sx = sy = shelf_h = 0
    for i in order:
        im = strips[i]
        if sx + T > cols * T:
            sx = 0
            sy += shelf_h
            shelf_h = 0
        rects[i] = (sx, sy)
        sx += T
        shelf_h = max(shelf_h, im.height)
    atlas_h = sy + shelf_h
    atlas = Image.new("RGBA", (cols * T, max(T, atlas_h)), (0, 0, 0, 0))
    for i, im in enumerate(strips):
        atlas.paste(im, rects[i])
    atlas.save(d / "hd2d_atlas.png")

    # 바닥 그림(사용자 지적 2026-11-02: 세운 물체 아래 바닥에 원래 도트가 남아 비쳤다): 세운 칸·꽃·수풀·문 자리를 메운다.
    # 꽃·수풀은 그 칸의 바탕 풀색으로, 나머지는 가장 가까운 맨바닥 칸(서 있지 않고 물·꽃·수풀이 아닌 칸) 그림을 그대로 옮겨 온다.
    flr = bottom.copy()
    plain = [[not upright[y][x] and not water[y][x] and not flower[y][x] and not grass[y][x]
              and j.get('ledge', ['0' * w] * h)[y][x] == '0' for x in range(w)] for y in range(h)]
    from collections import Counter
    def nearest_plain(x: int, y: int):
        for r in range(1, 9):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and plain[ny][nx]:
                        return nx, ny
        return None
    base_of = {}
    def base_color(x: int, y: int):
        """칸의 바탕색 — 그 색이 80% 넘는 '깨끗한' 칸만(경계 칸은 길·풀이 섞여 옮기면 옅은 띠가 생겼다). 아니면 None."""
        if (x, y) not in base_of:
            c, n = Counter(_tile(bottom, x, y, pad).getdata()).most_common(1)[0]
            base_of[(x, y)] = c if n >= 0.8 * T * T else None
        return base_of[(x, y)]
    def nearest_plain_with(x: int, y: int, color):
        for r in range(1, 9):
            for dy in range(-r, r + 1):
                for dx in range(-r, r + 1):
                    if max(abs(dx), abs(dy)) != r:
                        continue
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and plain[ny][nx] and base_color(nx, ny) == color:
                        return nx, ny
        return None
    for y in range(h):
        for x in range(w):
            if flower[y][x] or (grass[y][x] and not upright[y][x]):
                # 꽃·수풀 자리 바닥은 가장 가까운 맨 잔디 칸을 옮겨 온다(사용자 2026-11-02: 수풀이 너무 진하다 — 칸의 바탕색(진한 풀색)으로
                # 칠했더니 풀숲이 통째로 어두웠다. 지도의 잔디 바닥을 깔면 판 사이로 밝은 잔디가 보인다). 없으면 바탕색.
                src = None
                for r in range(1, 12):
                    cand = [(x + dx, y + dy) for dy in range(-r, r + 1) for dx in range(-r, r + 1)
                            if max(abs(dx), abs(dy)) == r and 0 <= x + dx < w and 0 <= y + dy < h and plain[y + dy][x + dx]
                            and base_color(x + dx, y + dy) is not None
                            and base_color(x + dx,y + dy)[1] - base_color(x + dx,y + dy)[0] >= 16
                            and base_color(x + dx,y + dy)[1] - base_color(x + dx,y + dy)[2] >= 8]
                    if cand:
                        src = min(cand, key=lambda c: abs(c[0] - x) + abs(c[1] - y))
                        break
                if src:
                    flr.paste(_tile(bottom, src[0], src[1], pad), ((x + pad) * T, (y + pad) * T))
                else:
                    base = Counter(_tile(bottom, x, y, pad).getdata()).most_common(1)[0][0]
                    flr.paste(Image.new("RGBA", (T, T), base), ((x + pad) * T, (y + pad) * T))
            elif upright[y][x]:
                # 그 칸 그림에서 물체 둘레에 비치는 바닥색(이웃 맨바닥 칸들에도 있는 색 중 가장 흔한 것)을 읽고, 바탕색이 그 색인
                # 가장 가까운 맨바닥 칸을 옮겨 온다. 없으면 그 색으로 칠하고, 그것도 없으면 가장 가까운 맨바닥 칸.
                # (그냥 가장 가까운 칸이면 우체통 자리가 옆의 밝은 길 칸으로 메워져 색이 달라졌다 — 사용자 지적 2026-11-02)
                own = Counter(_tile(bottom, x, y, pad).getdata())
                near_cols = set()
                for dx, dy in [(1, 0), (-1, 0), (0, 1), (0, -1)]:
                    nx, ny = x + dx, y + dy
                    if 0 <= nx < w and 0 <= ny < h and plain[ny][nx]:
                        near_cols |= set(_tile(bottom, nx, ny, pad).getdata())
                ground = next((c for c, _ in own.most_common() if c in near_cols), None)
                src = nearest_plain_with(x, y, ground) if ground is not None else None
                if src is not None:
                    flr.paste(_tile(bottom, src[0], src[1], pad), ((x + pad) * T, (y + pad) * T))
                elif ground is not None:
                    flr.paste(Image.new("RGBA", (T, T), ground), ((x + pad) * T, (y + pad) * T))
                else:
                    src = nearest_plain(x, y)
                    if src is not None:
                        flr.paste(_tile(bottom, src[0], src[1], pad), ((x + pad) * T, (y + pad) * T))
    for (x, y) in overflow:
        # 가구가 걸친 바닥 칸: 바닥색이 아닌 픽셀만 같은 줄(없으면 가까운) 맨바닥 칸의 같은 자리 픽셀로
        src = None
        for r in range(1, w):
            for nx in (x - r, x + r):
                if src is None and 0 <= nx < w and plain[y][nx] and (nx, y) not in overflow:
                    src = (nx, y)
            if src:
                break
        src = src or nearest_plain(x, y)
        if src:
            fp = flr.load()
            for yy in range(T):
                for xx in range(T):
                    X, Y = (x + pad) * T + xx, (y + pad) * T + yy
                    if not is_bg(x, y, xx, yy):
                        fp[X, Y] = bottom.getpixel(((src[0] + pad) * T + xx, (src[1] + pad) * T + yy))
    for (x, y) in flat_top:
        flr.alpha_composite(_tile(top, x, y), ((x + pad) * T, (y + pad) * T))
    if seat_footprint(name):
        # Home corner pots used a flat palette fill. Restore actual adjacent floor rows.
        pot_y = 8 if name == "rivals_house" else 7
        left = 1 if name == "players_house_1f" else 0
        for px, donor_x in [(left,left+1),(w-1,w-2)]:
            for py in [pot_y-1,pot_y]:
                flr.paste(_tile(bottom,donor_x,py,pad),((px+pad)*T,(py+pad)*T))
    if name in CENTER_MAPS:
        # Remove the old flat plant base beneath the new solid pot.
        flr.paste(_tile(bottom, 3, 4, pad), ((1+pad)*T, (2+pad)*T))
        # Unused link-room stairs removed; restore continuous lobby flooring.
        for sy in range(5, 8):
            for sx in range(2):
                flr.paste(_tile(bottom, 3, sy, pad), ((sx+pad)*T, (sy+pad)*T))
        flr.paste(_tile(bottom, 0, 8, pad), (pad*T, (8+pad)*T))
    if name in ("forest_gate_south", "forest_gate_north"):
        for xx in [1,2]:
            for yy in [4,5,7,8]:
                flr.paste(_tile(bottom,3,yy,pad),((xx+pad)*T,(yy+pad)*T))
        for xx,yy in [(10,4),(10,5),(13,5),(13,8)]:
            flr.paste(_tile(bottom,9,yy,pad),((xx+pad)*T,(yy+pad)*T))
        for xx in [1,5,9,13]:
            flr.paste(_tile(bottom,4,3,pad),((xx+pad)*T,(2+pad)*T))
    if name == "pewter_museum_1f":
        # Source art is preserved on explicit objects; the floor contains no copies.
        for xx in [9,10]:
            for yy in range(6,10):
                flr.paste(_tile(bottom,8,3,pad),((xx+pad)*T,(yy+pad)*T))
        for xx,yy in [(0,2),(0,8),(0,9),(16,8),(16,9),(24,8),(24,9),(25,8),(25,9),(16,3),(16,5),(26,4),(26,7),(22,3),(22,4),(27,3),(27,4),(27,6),(27,7)]:
            flr.paste(_tile(bottom,20,5,pad),((xx+pad)*T,(yy+pad)*T))
    if name == "pewter_museum_2f":
        for xx,yy in [(x,y) for x in [0,1,17,18] for y in [8,9]] + [(0,2),(18,2)] + [(x,y) for x in [9,10] for y in [7,8,9]]:
            flr.paste(_tile(bottom,7,4,pad),((xx+pad)*T,(yy+pad)*T))
    if name == "pewter_gym":
        for xx,yy in [(5,3),(7,3),(4,5),(8,5),(3,7),(5,7),(7,7),(9,7),(1,8),(11,8),(4,9),(8,9),(1,10),(11,10)]:
            donor=(3,3) if yy==3 else (2,6)
            flr.paste(_tile(bottom,*donor,pad),((xx+pad)*T,(yy+pad)*T))
        for xx in [4,8]:
            for yy in [11,12]: flr.paste(_tile(bottom,6,12,pad),((xx+pad)*T,(yy+pad)*T))
    if j.get("arena",{}).get("style")=="room":
        arena=j["arena"]; rows=arena["wall_rows"]; fx,fy,_,_=arena["field"]
        clean=_tile(bottom,fx+1,fy+1,pad)
        for yy in range(fy):
            for xx in range(w): flr.paste(clean,((xx+pad)*T,(yy+pad)*T))
        # Side strips must not inherit duplicated centre-line pixels from floor donors.
        for yy in range(fy,h):
            for xx in [0,w-1]: flr.paste(clean,((xx+pad)*T,(yy+pad)*T))
        # Low arena shots see past the map edge; continue the room floor rather
        # than exposing the black source-map padding beside the trainer.
        for yy in range(-pad,h+pad):
            for xx in range(-pad,w+pad):
                if not (0<=xx<w and 0<=yy<h):
                    flr.paste(clean,((xx+pad)*T,(yy+pad)*T))
    if name in MART_MAPS:
        flr.paste(_tile(bottom,4,5,pad), (pad*T,(3+pad)*T))
    if name == "kanto_south":
        # No old facade pixels may remain on the ground under unified buildings.
        for bx, by, bw, bh, gx, gy in [(26,15,4,4,25,17),(12,12,7,5,11,14),(34,136,4,4,33,138),(33,126,6,5,32,128),(14,86,8,6,14,93),(14,54,8,5,22,59),(28,82,5,5,29,88)]:
            lawn_tile = _tile(bottom,gx,gy,pad)
            for yy in range(by,by+bh):
                for xx in range(bx,bx+bw):
                    flr.paste(lawn_tile,((xx+pad)*T,(yy+pad)*T))
    if name == "viridian_forest":
        # Rear ground layer must not duplicate the unified north gate facade.
        for yy in range(10):
            for xx in range(11):
                flr.paste(Image.new("RGBA",(T,T),(115,205,164,255)),((xx+pad)*T,(yy+pad)*T))
    if name == "viridian_forest":
        for yy in range(10,13):
            for xx in range(11):
                base = _tile(bottom,13,7,pad) if 4 <= xx <= 6 else Image.new("RGBA",(T,T),(115,205,164,255))
                flr.paste(base,((xx+pad)*T,(yy+pad)*T))
    if border_trees:
        if name=="saffron_city":
            ground=_tile(bottom,31,0,pad)
        else:
            fx,fy,_,_=j["arena"]["field"]
            ground=_tile(bottom,fx+1,fy+1,pad)
        # Every padding pixel is scenery, never a flat copy of a tree canopy.
        for yy in range(-pad,h+pad):
            for xx in range(-pad,w+pad):
                if not(0<=xx<w and 0<=yy<h) or (xx,yy) in tree_cells:
                    flr.paste(ground,((xx+pad)*T,(yy+pad)*T))
    for xx,yy in road_logs:
        flr.paste(Image.new("RGBA",(T,T),(115,205,164,255)),((xx+pad)*T,(yy+pad)*T))
    if trees and not border_trees:
        from terrain_ground import green, surface_palette, restore_tree_floor
        ground_tiles = {(x,y):_tile(bottom,x,y,pad) for y in range(h) for x in range(w) if plain[y][x] and (x,y) not in tree_cells and base_color(x,y) is not None}
        lawn = {xy:im for xy,im in ground_tiles.items() if green(base_color(*xy))}
        if lawn:restore_tree_floor(j,bottom,flr,tree_cells,lawn,surface_palette(ground_tiles.values()))
    flr.save(d / "hd2d_floor.png")
    # 지붕(사용자 '각도 더 낮게' 2026-11-02): 원작 그림은 지붕이 벽과 한 장이라 통째로 세우면 낮은 각도에서 지붕이 벽처럼 선다.
    # 4칸 넘는 묶음(건물)은 아래 두 칸만 벽으로 세우고 그 위는 뒤로 눕힌다(View3D). 지붕 칸 수 = 같은 건물(맨 위 y 가 같은 이웃 줄)의
    # 가장 긴 묶음 − 2 — 문 줄은 문 칸이 바닥에 남아 묶음이 한 칸 짧아도 옆 줄과 같은 높이에서 꺾인다.
    top_of = {}
    for (x, y0, n, i) in cards:
        if kind_of.get((x, y0), "solid") == "solid":
            top_of.setdefault((x, y0), n)
    def building_n(x: int, y0: int) -> int:
        best = top_of[(x, y0)]
        for step in (-1, 1):
            nx = x + step
            while (nx, y0) in top_of and top_of[(nx, y0)] >= 4:
                best = max(best, top_of[(nx, y0)])
                nx += step
        return best
    # 건물 안 2~3칸 가구: 위 칸(들)이 꽉 찬 판(탁자·선반·계산대 윗면)일 때만 상자 — 잎이 듬성한 화분·의자는 세운 판
    # (사용자 2026-11-02: 화분이 상자가 되어 잎이 윗면으로 눕고 옆면이 바닥색이었다).
    def top_cover(i: int, r: int) -> float:
        im = strips[i]
        a = [im.getpixel((xx, yy))[3] > 0 for yy in range(r * T) for xx in range(T)]
        return sum(a) / float(len(a)) if a else 0.0
    out = []
    for (x, y0, n, i) in cards:
        kind = kind_of.get((x, y0), "solid")
        ovf = ovf_of.get((x, y0), 0)
        ns = n - ovf
        roof = max(0, building_n(x, y0) - 2) if n >= 4 and kind == "solid" and not (indoor and y0 <= 1) else 0
        if name.startswith("mt_moon") and kind == "solid" and n >= 3:
            roof = n - 2
        if name == "kanto_south" and ((14 <= x < 22 and y0 == 86) or (14 <= x < 22 and y0 == 54) or (28 <= x < 33 and y0 == 82)):
            roof = 3
        if name == "viridian_forest" and 0 <= x < 11 and y0 == 0 and n == 10:
            roof = 7
        if indoor and kind == "solid" and 2 <= ns <= 3 and y0 > 1:
            roof = ns - 1 if top_cover(i, ns - 1) >= INDOOR_BOX_COVER else 0
            if roof and _is_plant(bottom, top, pad, x, y0):
                roof = 0                 # 화분은 늘 세운 판(잎이 윗면으로 누우면 안 된다)
        out.append([x, y0, n, rects[i][0], rects[i][1], min(roof, n - 1), LOW.get(kind, 1.0), FLORA_TILT if kind in LOW else 0, ovf])
        if kind == "fence":
            out[-1].extend([5, fences[(x, y0)]])
    for (x, y0, n, i) in tree_cards:
        out.append([x, y0, n, rects[i][0], rects[i][1], 0, 1.0, 0, 0, 1])        # 10번째 값 1 = 나무(칸이 겹칠 수 있다)
    # 화분 충돌 1×1(사용자 2026-11-02): 건물 안 2칸짜리 세운 판(상자 아님) 중 위 칸이 잎(초록 픽셀 20개 넘음)이면 그 칸을 연다.
    opened = []
    if indoor:
        from collections import Counter
        def obj_px(x: int, y: int) -> list:
            t_ = _tile(bottom, x, y, pad).copy()
            t_.alpha_composite(_tile(top, x, y))
            tp_ = t_.load()
            return [tp_[xx, yy] for yy in range(T) for xx in range(T) if not is_bg(x, y, xx, yy) and tp_[xx, yy][3] > 0]
        is_green = lambda p_: p_[1] > p_[0] + 25 and p_[1] > p_[2]
        for (x, y0) in [(x, y) for y in range(2, h - 1) for x in range(w)]:
            if not (solid[y0][x] and solid[y0 + 1][x]):
                continue                 # 잎 칸·화분 칸이 둘 다 막힌 것만
            # 원작 실내 화분 팔레트: 잎 = 밝은 연두(164,255,180) + 진한 초록(106,197,106), 화분 = (180,180,164)
            # (초록 비율로 고르면 깔개 위 탁자·계산대가 섞이고, 바닥 띠 칸의 화분은 빠졌다)
            lt = _tile(bottom, x, y0, pad).copy()
            lt.alpha_composite(_tile(top, x, y0))
            pt = _tile(bottom, x, y0 + 1, pad).copy()
            pt.alpha_composite(_tile(top, x, y0 + 1))
            lc = Counter(p_[:3] for p_ in lt.getdata())
            pc = Counter(p_[:3] for p_ in pt.getdata())
            if lc[(164, 255, 180)] >= 25 and lc[(106, 197, 106)] >= 25 and pc[(180, 180, 164)] >= 8:
                opened.append([x, y0])
    # 건물 안 양옆 띠(사용자 2026-11-02: 오박사네 좌우측은 아직도 못 지나다닌다): 바닥으로 눕힌 띠 칸은 지나갈 수 있게 연다.
    # 검은 바깥·맨 아래 줄·뒷벽 줄·가구 상자 자리(build_tables 가 비운 칸)는 그대로 막는다.
    for (x, y) in sorted(edge_strip):
        if 2 <= y <= h - 2 and (x, y) not in table_freed and [x, y] not in opened:
            opened.append([x, y])
    patch_path = d / "collision_patch.json"
    blocked = seat_footprint(name)
    if name in CENTER_MAPS:
        blocked += [[11,5], [12,5], [14,6], [14,7]]
    if name in ("forest_gate_south", "forest_gate_north"):
        blocked += [[10,4],[10,5],[13,5],[13,8]]
    if opened or blocked:
        patch_path.write_text(json.dumps({"open": [p for p in opened if p not in blocked], "block": blocked}))
    elif patch_path.exists():
        patch_path.unlink()
    houses, out = build_houses(d, out, tile_img, w, h)
    props, out = build_props(d, out, tile_img) if not j.get("indoor", False) else ([], out)
    center_extras = center_objects(d, name, tables)
    metadata = {"tile": T, "cards": out, "houses": houses, "props": props, "tables": tables + wallobjs + center_extras}
    if name in CENTER_MAPS:
        metadata["cards"] = [c for c in out if (c[0], c[1]) not in ((0,5), (1,5), (0,8))]
        # Preserve existing object order; keep the machine support last.
        metadata["tables"] = tables[:6] + wallobjs + center_extras[:-1] + tables[6:] + center_extras[-1:]
        # Actual chamfered corners share the rear wall's z=2 edge and height.
        clean = next(c for c in out if c[0] == 3 and c[1] == 0)
        metadata["corner_walls"] = [
            {"column": 0, "a": [0, 3], "b": [1, 2], "h": 2, "atlas": [clean[3], clean[4], T, 2*T]},
            {"column": 14, "a": [14, 2], "b": [15, 3], "h": 2, "atlas": [clean[3], clean[4], T, 2*T]},
        ]
    if name in MART_MAPS:
        raw = Image.open(d / "preview.png").convert("RGBA")
        P = pad*T
        def source(rect):
            a,b,c,e = rect
            return raw.crop((P+a,P+b,P+c,P+e))
        for index, sx, sw in [(4,112,32),(5,160,16)]:
            tex = "hd2d_table%d" % index
            # Merchandise faces the aisles; the end panel carries only cabinet trim.
            side = Image.new("RGBA", (48,20), (112,112,105,255))
            for panel, sy in enumerate([65,85]):
                side.paste(source((sx+3,sy,sx+10,sy+14)).resize((22,16),Image.Resampling.NEAREST),(1+24*panel,2))
            side.save(d / (tex+"_side.png"))
            source((sx+6,101,sx+7,110)).resize((sw,20),Image.Resampling.NEAREST).save(d / (tex+"_front.png"))
            source((sx+11,60,sx+14,63)).resize((sw,48),Image.Resampling.NEAREST).save(d / (tex+"_top.png"))
            tables[index]["display_rack"] = True
            tables[index]["h"] = 0.875
            tables[index]["closed"] = True
        tables[2].update({"thickness": 0.125, "base": 0.5625})
        # Discard diagonal-wall fragments misidentified as tall furniture.
        metadata["tables"] = [t for t in metadata["tables"] if t["tex"] != "hd2d_wallobj0"]
        for obj in metadata["tables"]:
            if obj["tex"] == "hd2d_wallobj1":
                plant = source((17,20,31,47))
                plant.putdata([(0,0,0,0) if b > r+35 and b > g else (r,g,b,a) for r,g,b,a in plant.getdata()])
                plant.crop((0,0,plant.width,18)).save(d / "hd2d_wallobj1_front.png")
                obj.clear(); obj.update({"card":True,"x0":17/T,"x1":31/T,"z0":2.5,"z1":2.875,"h":18/T,"base":0.5625,"planter":True,"tex":"hd2d_wallobj1"})
            elif obj["tex"] == "hd2d_wallobj2":
                source((112,14,160,20)).save(d / "hd2d_wallobj2_top.png")
                front = source((112,20,160,40))
                front.save(d / "hd2d_wallobj2_front.png")
                _side_tex(front,8,1).save(d / "hd2d_wallobj2_side.png")
                obj.update({"x1":10.0,"z1":2.5,"h":1.25,"closed":True})
        # Use clean wallpaper for actual chamfers, not baked diagonal wall cards.
        wall = Image.new("RGBA", (16,48))
        for y in range(48):
            sy = y if y < 8 else (12 if y < 45 else 29)
            color = raw.getpixel((P+60 if y < 45 else P+47,P+sy))
            wall.paste(color,(0,y,16,y+1))
        old = Image.open(d / "hd2d_atlas.png").convert("RGBA")
        expanded = Image.new("RGBA", (old.width,old.height+48))
        expanded.paste(old,(0,0)); expanded.paste(wall,(0,old.height))
        expanded.save(d / "hd2d_atlas.png")
        metadata["corner_walls"] = [
            {"column":0,"a":[0,3],"b":[1,2],"h":3,"atlas":[0,old.height,16,48]},
            {"column":1,"a":[1,2],"b":[2,2],"h":3,"atlas":[0,old.height,16,48]},
            {"column":10,"a":[10,2],"b":[11,3],"h":3,"atlas":[0,old.height,16,48]},
        ]
    if name in ("forest_gate_south", "forest_gate_north"):
        # Explicit wall fixtures replace automatic floor-box extraction.
        metadata["tables"] = tables
        raw = Image.open(d / "preview.png").convert("RGBA")
        P = pad*T
        for label, rect, base in [("window_left",(34,9,62,24),1.0),("window_right",(178,9,206,24),1.0),("door",(96,8,144,32),0.0)]:
            a,b,c,e = rect
            tex = "hd2d_gate_"+label
            raw.crop((P+a,P+b,P+c,P+e)).save(d/(tex+"_front.png"))
            metadata["tables"].append({"card":True,"x0":a/T,"x1":c/T,"z0":2.005,"z1":2.005,"base":base,"h":(e-b)/T,"tex":tex})
        foliage = Image.open(ROOT/"assets/maps/viridian_mart/hd2d_wallobj1_front.png").convert("RGBA")
        foliage.putdata([(0,0,0,0) if c[:3] in {(246,238,148),(213,197,106)} else c for c in foliage.getdata()])
        foliage.save(d/"hd2d_gate_foliage_front.png")
        for xx in [1,5,9,13]:
            metadata["tables"].append({"card":True,"planter":True,"x0":xx+0.0625,"x1":xx+0.9375,
                "z0":2.875,"z1":2.875,"base":0.5625,"h":18/T,"tex":"hd2d_gate_foliage"})
        for xx,zz in [(1,5.5),(2,5.5),(1,8.5),(2,8.5)]:
            metadata["tables"].append({"card":True,"planter":True,"x0":xx+0.0625,"x1":xx+0.9375,
                "z0":zz,"z1":zz,"base":0.5625,"h":18/T,"tex":"hd2d_gate_foliage"})
        for xx,yy in [(10,4),(10,5),(13,5),(13,8)]:
            metadata["tables"].append({"chair":True,"side":"left" if xx==10 else "right",
                "x0":xx+0.0625,"x1":xx+0.9375,"z0":yy+0.0625,"z1":yy+0.9375,
                "tex":"hd2d_gate_chair"})
        metadata["floor_decor"] = [{"id":"central_carpet","bounds":[98,48,142,144]},
                                   {"id":"exit_mat","bounds":[106,164,134,176]}]
        metadata["cards"] = [c for c in metadata["cards"] if not(c[0] in [1,2] and c[1] in [4,7])]
        # A shared rear plane prevents fixture columns from shifting wall depth/height.
        old = Image.open(d/"hd2d_atlas.png").convert("RGBA")
        expanded = Image.new("RGBA",(old.width,old.height+32))
        expanded.paste(old,(0,0))
        wall = Image.new("RGBA",(16,32))
        for yy in range(32):
            color = raw.getpixel((P+4*T+8,P+yy))
            for xx in range(16): wall.putpixel((xx,yy),color)
        expanded.paste(wall,(0,old.height))
        expanded.save(d/"hd2d_atlas.png")
        metadata["cards"] = [c for c in metadata["cards"] if c[1]>0]
        metadata["cards"] += [[xx,0,2,0,old.height,0,1.0,0,0] for xx in range(1,14)]
    if name == "pewter_museum_1f":
        raw = Image.open(d/"preview.png").convert("RGBA")
        P = pad*T
        def museum_crop(rect):
            a,b,c,e = rect
            return raw.crop((P+a,P+b,P+c,P+e))
        from collections import deque
        floor_colors = set(museum_crop((320,80,336,96)).getdata())
        def museum_cutout(image):
            pixels = image.load()
            queue = deque((x,y) for y in range(image.height) for x in range(image.width)
                          if x in (0,image.width-1) or y in (0,image.height-1))
            seen = set()
            while queue:
                x,y = queue.popleft()
                if (x,y) in seen or not(0<=x<image.width and 0<=y<image.height): continue
                seen.add((x,y))
                if pixels[x,y] not in floor_colors: continue
                pixels[x,y] = (0,0,0,0)
                queue.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
            return image
        metadata["tables"] = list(tables)
        for obj in metadata["tables"]:
            if obj.get("box"): obj["closed"] = True
        def museum_card(label,rect,z,base=0.0,height=None,cutout=False):
            a,b,c,e=rect
            image=museum_crop(rect)
            if cutout: image=museum_cutout(image)
            tex="hd2d_museum_"+label
            image.save(d/(tex+"_front.png"))
            obj={"card":True,"x0":a/T,"x1":c/T,"z0":z,"z1":z,"base":base,"h":(e-b)/T if height is None else height,"tex":tex}
            metadata["tables"].append(obj)
            return obj
        for label,x0 in [("window_left",48),("window_right",112)]:
            museum_card(label,(x0,8,x0+16,27),2.005,base=5/T)
        for index,x0 in enumerate([176,208]):
            museum_card("plaque%d"%index,(x0,12,x0+16,24),2.005,base=0.5)
        for index,x0 in enumerate([16,80,144]):
            tex="hd2d_museum_pillar%d"%index
            museum_crop((x0,0,x0+16,2)).save(d/(tex+"_top.png"))
            front=museum_crop((x0,2,x0+16,32))
            front.save(d/(tex+"_front.png")); _side_tex(front,3,1).save(d/(tex+"_side.png"))
            metadata["tables"].append({"box":True,"closed":True,"x0":x0/T,"x1":x0/T+1,"z0":2.0,"z1":2.1875,"h":30/T,"tex":tex})
        for index,x0 in enumerate([272,384]):
            tex="hd2d_museum_shelf%d"%index
            museum_crop((x0,10,x0+64,20)).save(d/(tex+"_top.png"))
            front=museum_crop((x0,20,x0+64,40)); front.save(d/(tex+"_front.png"))
            _side_tex(front,8,1).save(d/(tex+"_side.png"))
            metadata["tables"].append({"box":True,"closed":True,"x0":x0/T,"x1":(x0+64)/T,"z0":2.0,"z1":2.5,"h":1.25,"tex":tex})
        foliage=Image.open(ROOT/"assets/maps/forest_gate_south/hd2d_gate_foliage_front.png").convert("RGBA")
        foliage.save(d/"hd2d_museum_foliage_front.png")
        for xx,zz in [(0,2.75),(0,9.5),(16,9.5),(24,9.5),(25,9.5)]:
            metadata["tables"].append({"card":True,"planter":True,"x0":xx+0.0625,"x1":xx+0.9375,"z0":zz,"z1":zz,"base":0.5625,"h":18/T,"tex":"hd2d_museum_foliage"})
        for index,(xx,yy) in enumerate([(16,3),(16,5),(26,4),(26,7)]):
            obj=museum_card("stool%d"%index,(xx*T,yy*T,(xx+1)*T,(yy+1)*T),yy+1,base=0.125,cutout=True)
            obj.update({"decal":True,"z0":float(yy),"z1":float(yy+1)})
        museum_card("office_chair",(352,48,368,80),4.0,height=1.0,cutout=True)
        for index,sy in enumerate([48,96]):
            tex="hd2d_museum_device%d"%index
            museum_crop((432,sy,448,sy+8)).save(d/(tex+"_top.png"))
            front=museum_crop((432,sy+8,448,sy+32)); front.save(d/(tex+"_front.png"));_side_tex(front,8,1).save(d/(tex+"_side.png"))
            metadata["tables"].append({"box":True,"closed":True,"x0":27,"x1":28,"z0":(sy+24)/T,"z1":(sy+32)/T,"h":1.5,"tex":tex})
        metadata["museum_stairs"]={"x0":9.0,"x1":11.0,"z0":7.0,"z1":9.5,"height":1.0,"steps":6}
        metadata["cards"]=[c for c in metadata["cards"] if c[1]>0 and not((c[0] in [9,10] and c[1] in [6,7]) or (c[0]==27 and c[1] in [3,6]) or (c[0] in [0,16,24,25] and c[1]==8))]
        old=Image.open(d/"hd2d_atlas.png").convert("RGBA")
        atlas=Image.new("RGBA",(old.width,old.height+32));atlas.paste(old,(0,0))
        wall=Image.new("RGBA",(16,32))
        for yy in range(32):
            for xx in range(16):wall.putpixel((xx,yy),raw.getpixel((P+40,P+yy)))
        atlas.paste(wall,(0,old.height));atlas.save(d/"hd2d_atlas.png")
        metadata["cards"] += [[xx,0,2,0,old.height,0,1.0,0,0] for xx in range(w)]
    if name == "pewter_museum_2f":
        raw = Image.open(d/"preview.png").convert("RGBA")
        P = pad*T
        def upstairs_crop(rect):
            a,b,c,e=rect
            return raw.crop((P+a,P+b,P+c,P+e))
        metadata["tables"] = list(tables)
        for obj in metadata["tables"]: obj["closed"] = True
        for index,x0 in enumerate([16,80,144,208,272]):
            tex="hd2d_museum_pillar%d"%index
            upstairs_crop((x0,0,x0+16,2)).save(d/(tex+"_top.png"))
            front=upstairs_crop((x0,2,x0+16,32))
            front.save(d/(tex+"_front.png")); _side_tex(front,3,1).save(d/(tex+"_side.png"))
            metadata["tables"].append({"box":True,"closed":True,"x0":x0/T,"x1":x0/T+1,"z0":2.0,"z1":2.1875,"h":30/T,"tex":tex})
        for index,x0 in enumerate([48,112,176,240]):
            tex="hd2d_museum_window%d"%index
            upstairs_crop((x0,8,x0+16,27)).save(d/(tex+"_front.png"))
            metadata["tables"].append({"card":True,"x0":x0/T,"x1":x0/T+1,"z0":2.005,"z1":2.005,"base":5/T,"h":19/T,"tex":tex})
        foliage=Image.open(ROOT/"assets/maps/forest_gate_south/hd2d_gate_foliage_front.png").convert("RGBA")
        foliage.save(d/"hd2d_museum_foliage_front.png")
        for xx,zz in [(0,2.75),(18,2.75),(0,9.5),(1,9.5),(17,9.5),(18,9.5)]:
            metadata["tables"].append({"card":True,"planter":True,"x0":xx+0.0625,"x1":xx+0.9375,"z0":zz,"z1":zz,"base":0.5625,"h":18/T,"tex":"hd2d_museum_foliage"})
        # Downstairs opening stays on the floor, rather than standing like a wall.
        upstairs_crop((144,120,176,160)).save(d/"hd2d_museum_downstairs_front.png")
        metadata["tables"].append({"card":True,"decal":True,"x0":9.0,"x1":11.0,"z0":7.5,"z1":10.0,"base":0.012,"h":2.5,"tex":"hd2d_museum_downstairs"})
        old=Image.open(d/"hd2d_atlas.png").convert("RGBA")
        atlas=Image.new("RGBA",(old.width,old.height+32));atlas.paste(old,(0,0))
        wall=Image.new("RGBA",(16,32))
        for yy in range(32):
            for xx in range(16): wall.putpixel((xx,yy),raw.getpixel((P+40,P+yy)))
        atlas.paste(wall,(0,old.height));atlas.save(d/"hd2d_atlas.png")
        metadata["cards"]=[[xx,0,2,0,old.height,0,1.0,0,0] for xx in range(w)]
    if name == "pewter_gym":
        raw=Image.open(d/"preview.png").convert("RGBA"); P=pad*T
        def gym_crop(rect):
            a,b,c,e=rect
            return raw.crop((P+a,P+b,P+c,P+e))
        from collections import deque
        def gym_cutout(im,colors):
            queue=deque((x,y) for y in range(im.height) for x in range(im.width) if x in [0,im.width-1] or y in [0,im.height-1])
            seen=set(); px=im.load()
            while queue:
                x,y=queue.popleft()
                if (x,y) in seen or not(0<=x<im.width and 0<=y<im.height): continue
                seen.add((x,y))
                if px[x,y][:3] not in colors: continue
                px[x,y]=(0,0,0,0)
                queue.extend([(x-1,y),(x+1,y),(x,y-1),(x,y+1)])
            return im
        metadata["tables"]=[]
        rocks=[(5,3),(7,3),(4,5),(8,5),(3,7),(5,7),(7,7),(9,7),(1,8),(11,8),(4,9),(8,9),(1,10),(11,10)]
        for index,(xx,yy) in enumerate(rocks):
            tex="hd2d_gym_rock%d"%index
            # The back row includes a wall-shadow strip above the rock silhouette.
            start=3 if yy==3 else 0
            im=gym_crop((xx*T,yy*T+start,(xx+1)*T,(yy+1)*T))
            gym_cutout(im,{(197,189,139),(164,139,115),(172,172,172),(131,106,82)}).save(d/(tex+"_front.png"))
            metadata["tables"].append({"card":True,"x0":xx,"x1":xx+1,"z0":yy+1,"z1":yy+1,"base":0.0,"h":im.height/T,"tex":tex})
        for index,xx in enumerate([4,8]):
            tex="hd2d_gym_statue%d"%index
            # Original statue silhouette stands on its own solid inscribed pedestal.
            im=gym_crop((xx*T,176,(xx+1)*T,194))
            gym_cutout(im,{(197,189,139),(164,139,115),(172,172,172),(131,106,82)}).save(d/(tex+"_front.png"))
            metadata["tables"].append({"card":True,"x0":xx,"x1":xx+1,"z0":12.75,"z1":12.75,"base":0.875,"h":18/T,"tex":tex})
            tex="hd2d_gym_pedestal%d"%index
            gym_crop((xx*T,194,(xx+1)*T,196)).save(d/(tex+"_top.png"))
            front=gym_crop((xx*T,194,(xx+1)*T,208));front.save(d/(tex+"_front.png"));_side_tex(front,8,1).save(d/(tex+"_side.png"))
            metadata["tables"].append({"box":True,"closed":True,"x0":xx,"x1":xx+1,"z0":12.5,"z1":13.0,"h":14/T,"tex":tex})
        # Uniform back wall: decoration no longer gets inferred as giant cabinets.
        old=Image.open(d/"hd2d_atlas.png").convert("RGBA")
        atlas=Image.new("RGBA",(old.width,old.height+32));atlas.paste(old,(0,0))
        atlas.paste(gym_crop((32,16,48,48)),(0,old.height));atlas.save(d/"hd2d_atlas.png")
        metadata["cards"]=[c for c in metadata["cards"] if c[1]>=12]
        metadata["cards"] += [[xx,1,2,0,old.height,0,1.0,0,0] for xx in range(1,12)]
        for index,xx in enumerate([4,5,7,8]):
            tex="hd2d_gym_plaque%d"%index
            gym_crop((xx*T+5,23,xx*T+11,34)).save(d/(tex+"_front.png"))
            metadata["tables"].append({"card":True,"x0":xx+5/T,"x1":xx+11/T,"z0":3.005,"z1":3.005,"base":14/T,"h":11/T,"tex":tex})
        tex="hd2d_gym_emblem"
        gym_crop((98,7,110,18)).save(d/(tex+"_front.png"))
        metadata["tables"].append({"card":True,"x0":98/T,"x1":110/T,"z0":3.005,"z1":3.005,"base":1.875,"h":11/T,"tex":tex})
        for index,x0 in enumerate([16,184]):
            tex="hd2d_gym_pillar%d"%index
            gym_crop((x0,24,x0+8,26)).save(d/(tex+"_top.png"))
            front=gym_crop((x0,26,x0+8,48));front.save(d/(tex+"_front.png"));_side_tex(front,3,1).save(d/(tex+"_side.png"))
            metadata["tables"].append({"box":True,"closed":True,"x0":x0/T,"x1":(x0+8)/T,"z0":3.0,"z1":3.1875,"h":22/T,"tex":tex})
    if j.get("arena",{}).get("style")=="room":
        # Room-style arenas share one unbroken upright source wall, with no roof folds.
        rows=int(j["arena"]["wall_rows"]); P=pad*T
        raw=Image.open(d/"preview.png").convert("RGBA")
        old=Image.open(d/"hd2d_atlas.png").convert("RGBA")
        atlas=Image.new("RGBA",(max(old.width,w*T),old.height+rows*T));atlas.paste(old,(0,0))
        for xx in range(w):
            # Source corner columns contain black outside pixels. Once the wall
            # continues past the map, use a plain column at those former corners.
            donor = min(max(xx,2),w-3)
            atlas.paste(raw.crop((P+donor*T,P,P+(donor+1)*T,P+rows*T)),(xx*T,old.height))
        atlas.save(d/"hd2d_atlas.png")
        metadata["cards"]=[c for c in metadata["cards"] if c[1]>=rows]
        metadata["cards"] += [[xx,0,rows,xx*T,old.height,0,1.0,0,0] for xx in range(w)]
        # Continue plain wall columns into the decorative padding so the
        # shifted introduction camera never reveals a black wedge at its edge.
        metadata["cards"] += [[xx,0,rows,2*T,old.height,0,1.0,0,0]
                              for xx in list(range(-pad,0))+list(range(w,w+pad))]
        metadata["tables"]=[t for t in metadata["tables"] if not t["tex"].startswith("hd2d_wallobj")]
    if border_trees:
        # Render-only bounds; movement and collision stay in map.json's field.
        metadata["scenery_bounds"]=[-pad,-pad,w+pad*2,h+pad*2]
    if name in ("viridian_forest", "kanto_south"):
        # Objectize the original post artwork without redesigning its silhouette.
        origin = ROOT/"assets/maps/kanto_south"
        source_map = json.loads((origin/"map.json").read_text())
        source_pad = source_map.get("pad",0)*T
        source_bottom = Image.open(origin/"bottom.png").convert("RGBA")
        source_top = Image.open(origin/"top.png").convert("RGBA")
        post = source_bottom.crop((source_pad+14*T,source_pad+92*T,source_pad+15*T,source_pad+93*T))
        post.alpha_composite(source_top.crop((14*T,92*T,15*T,93*T)))
        lawn = {(115,205,164),(65,180,139),(164,230,197),(24,164,106)}
        post.putdata([(0,0,0,0) if color[:3] in lawn else color for color in post.getdata()])
        single = Image.new("RGBA",(16,16),(0,0,0,0))
        single.paste(post.crop((1,2,8,16)),(4,2))
        single.save(d/"hd2d_log_front.png")
        for obsolete in ["hd2d_log_side.png","hd2d_log_top.png"]:
            (d/obsolete).unlink(missing_ok=True)
        if name == "viridian_forest":
            # Source: two narrow lanes of three posts, staggered by one tile;
            # the opposite entrance side mirrors the lateral arrangement.
            metadata["log_fences"] = []
            for label,early_x,late_x in [("left",2.75,3.25),("right",7.25,6.75)]:
                positions = [[early_x,9.5+i*0.5] for i in range(3)] + [[late_x,10.5+i*0.5] for i in range(3)]
                metadata["log_fences"].append({"id":"north_gate_"+label,"posts":positions,"height":1.0,"radius":0.28})
            metadata["cards"] = [c for c in metadata["cards"] if not(c[0] in [3,7] and c[1]==10)]
        else:
            # Connected segments remain editable placement groups.
            remaining = set(road_logs)
            groups = []
            while remaining:
                start = min(remaining)
                remaining.remove(start)
                posts, queue = [start], [start]
                for xx,yy in queue:
                    for neighbor in [(xx-1,yy),(xx+1,yy),(xx,yy-1),(xx,yy+1)]:
                        if neighbor in remaining:
                            remaining.remove(neighbor); posts.append(neighbor); queue.append(neighbor)
                groups.append({"id":"road_%d"%len(groups),"posts":[list(p) for p in sorted(posts)],"height":1.0,"radius":0.28,"offsets":[-0.25,0.25]})
            # Retain all source variants, including staggered end pieces.
            variants = {}
            for group in groups:
                group["source_cells"] = []
                for xx,yy in group["posts"]:
                    sprite = source_bottom.crop((source_pad+xx*T,source_pad+yy*T,source_pad+(xx+1)*T,source_pad+(yy+1)*T))
                    sprite.alpha_composite(source_top.crop((xx*T,yy*T,(xx+1)*T,(yy+1)*T)))
                    sprite.putdata([(0,0,0,0) if color[:3] in lawn else color for color in sprite.getdata()])
                    key = sprite.tobytes()
                    if key not in variants:
                        tex = "hd2d_road_log_%d"%len(variants)
                        variants[key] = tex
                        sprite.save(d/(tex+".png"))
                    group["source_cells"].append({"tile":[xx,yy],"tex":variants[key]})
            metadata["log_fences"] = groups
            removed = set(road_logs)
            kept = []
            for card in metadata["cards"]:
                if len(card)>9 and card[9]==1:
                    kept.append(card); continue
                offset = 0
                while offset<card[2]:
                    if (card[0],card[1]+offset) in removed:
                        offset += 1; continue
                    start = offset
                    while offset<card[2] and (card[0],card[1]+offset) not in removed: offset += 1
                    part = list(card)
                    part[1] += start; part[2] = offset-start; part[4] += start*T
                    part[5] = max(0,min(part[2]-1,card[5]-start))
                    if offset<card[2]: part[8] = 0
                    kept.append(part)
            metadata["cards"] = kept
            print("road log posts:",len(road_logs),"groups:",len(groups))
    if name == "kanto_north":
        from north_terrain import build as north_terrain
        metadata = north_terrain(d, j, metadata)
    if name.startswith(("mt_moon","rock_tunnel","digletts_cave","seafoam_islands","victory_road","cerulean_cave")) or name == "arena_mt_moon":
        from cave_cards import build as cave_terrain
        metadata = cave_terrain(d, j)
    from city_facility_objects import MAPS as facility_maps, build as facility_objects
    if name in facility_maps:
        metadata = facility_objects(d, j, name)
    from special_house_objects import MAPS as special_houses, specifications as special_house_specs
    if name in special_houses:
        metadata = facility_objects(d, j, name, special_house_specs(name))
    if name == "route25_sea_cottage":
        from bill_cottage_objects import specifications as bill_cottage_specs
        metadata = facility_objects(d, j, name, bill_cottage_specs())
    from underground_facilities import ENTRANCES, TUNNEL, GATES, entrance, tunnel, gate, road_facilities
    if name in ENTRANCES:
        metadata = entrance(d, j, name)
    elif name == TUNNEL:
        metadata = tunnel(d, j)
    elif name in GATES:
        metadata = gate(d, j, name)
    elif name in ("kanto_north", "kanto_east"):
        metadata = road_facilities(d, j, name, metadata)
    if name in ("kanto_north", "kanto_east", "saffron_city"):
        from city_exteriors import build as city_exteriors
        metadata = city_exteriors(d, j, name, metadata)
    if name == "saffron_city":
        from saffron_exteriors import build as saffron_exteriors
        metadata = saffron_exteriors(d, j, metadata)
    if name in ("kanto_north", "kanto_east"):
        from city_outdoor_props import build as city_outdoor_props
        metadata = city_outdoor_props(d, j, name, metadata)
    if name == "kanto_east":
        from vermilion_harbor import city_pier
        metadata = city_pier(d, j, metadata)
    if name in ("route11_east_entrance_1f", "route11_east_entrance_2f"):
        from route11_diglett import gate_stairs
        metadata = gate_stairs(d, j, metadata)
    (d / "hd2d_cards.json").write_text(json.dumps(metadata, separators=(",", ":")))
    atlas_tiles = strips
    print(f"{name}: 카드 {len(cards)}(서 있는 칸 {sum(c[2] for c in cards)}), 띠 그림 {len(atlas_tiles)} → {atlas.size}")


# ── 집 도트 재구성(사용자 2026-11-02 시범: 카드에 억지로 x·y 를 주니 어색 — 3D 면마다 맞는 도트를 원작 팔레트로 새로 짠다) ──
# 대상: 태초마을형 집(가로 5칸·묶음 5칸·지붕 3칸, 빨강 지붕). 원작 지붕은 모임지붕(왼쪽 밝은 띠·오른쪽 어두운 띠가 양옆 경사면)이라
# 3D 는 상자 + 평평한 지붕판(View3D._build_houses — 모임지붕도 해 봤지만 평평한 쪽으로, 사용자 2026-11-02). 면 그림:
#   front  원작 앞면(창문·문) 그대로 — 지붕 칸 바로 아래부터(양 끝 바닥이 비치는 열은 외곽선 색으로)
#   side   옆벽 — 앞면을 복사해 짠다(사용자 2026-11-02): 앞면의 모서리 테두리·사이딩 줄·윗띠·걸레받이를 그대로, 가운데에 앞면 창 하나
#   back   뒷벽 — 앞면의 사이딩 줄만 이어서(창 없음)
#   rooftop 평평한 지붕판 윗면 — 원작 지붕 그림 그대로(사용자 2026-11-02: 삼각으로 올리지 않고 평평하게)
#   roof   (모임지붕 시범 때 쓴 경사면 그림 — 원작 지붕 색으로 기와 줄을 고른 간격으로. 지금은 안 씀)
HOUSE_SIZE = (5, 5, 3)          # 가로 칸, 묶음 칸, 지붕 칸


def _red(c) -> bool:
    """빨강·주황 지붕 색(태초마을 집 바탕 238,148,115 포함)."""
    return c[3] > 0 and c[0] > 180 and c[0] - c[1] > 50 and c[0] - c[2] > 70


def build_houses(d: Path, cards: list, tile_img, w: int, h: int):
    from collections import Counter
    W, N, R = HOUSE_SIZE
    col = {}
    for c in cards:
        col[(c[0], c[1])] = c
    used = set()
    houses = []
    made = {}
    for c in cards:
        x, y0, n, ax, ay, roof = c[0], c[1], c[2], c[3], c[4], c[5]
        if (x, y0) in used or n != N or roof != R or (x - 1, y0) in col and col[(x - 1, y0)][2] == N and col[(x - 1, y0)][5] == R:
            continue
        run = [x + i for i in range(W) if (x + i, y0) in col and col[(x + i, y0)][2] == N and col[(x + i, y0)][5] == R]
        if len(run) != W or (x + W, y0) in col and col[(x + W, y0)][2] == N and col[(x + W, y0)][5] == R:
            continue
        art = Image.new("RGBA", (W * T, N * T), (0, 0, 0, 0))
        for i in range(W):
            for r in range(N):
                art.alpha_composite(tile_img(x + i, y0 + r), (i * T, r * T))
        roof_px = [p for p in art.crop((0, 0, W * T, R * T)).getdata() if p[3] > 0]
        if sum(1 for p in roof_px if _red(p)) < 0.35 * max(1, len(roof_px)):
            continue
        key = art.tobytes()
        if key not in made:
            made[key] = "hd2d_house%d" % len(made)
            _house_textures(d, made[key], art, R)
        houses.append({"x": x, "z": y0 + N, "w": W, "d": R, "tex": made[key]})
        for i in range(W):
            used.add((x + i, y0))
    rest = [c for c in cards if (c[0], c[1]) not in used]
    return houses, rest


def _house_textures(d: Path, name: str, art: Image.Image, R: int) -> None:
    from collections import Counter
    W = art.width
    top = R * T                                               # 앞면은 지붕 칸 바로 아래부터(처마 띠는 3D 지붕이 덮는다)
    front = art.crop((0, top, W, art.height))
    fh = front.height
    fp = front.load()
    # 양 끝 바깥 1~2열은 바닥(풀)이 비친다 — 벽 외곽선 열(2, W−3)의 색으로 메운다
    for y in range(fh):
        for x in (0, 1):
            fp[x, y] = fp[2, y]
        for x in (W - 2, W - 1):
            fp[x, y] = fp[W - 3, y]
    front.save(d / (name + "_front.png"))
    # 사이딩 한 줄(세로 색 줄): 창이 없는 맨 사이딩 열 — 모서리 테두리(앞 9px) 바로 안쪽
    plain_x = 11
    siding = [fp[plain_x, y] for y in range(fh)]
    def wall(width: int, with_window: bool) -> Image.Image:
        im = Image.new("RGBA", (width, fh))
        p = im.load()
        for x in range(width):
            for y in range(fh):
                p[x, y] = siding[y]
        # 양 끝 모서리 테두리: 앞면 왼쪽 끝 9열·오른쪽 끝 9열을 그대로
        im.paste(front.crop((0, 0, 9, fh)), (0, 0))
        im.paste(front.crop((W - 9, 0, W, fh)), (width - 9, 0))
        if with_window:
            # 앞면 윗줄 왼쪽 창 한 칸(창틀까지만 — 아래 문틀이 딸려 오지 않게)을 같은 높이 가운데에
            win = front.crop((16, 0, 29, 12))
            im.paste(win, ((width - win.width) // 2, 0))
        return im
    wall(R * T, True).save(d / (name + "_side.png"))
    wall(W, False).save(d / (name + "_back.png"))
    # 지붕 윗면(평지붕, 사용자 2026-11-02: 삼각으로 올리지 않고 평평하게): 원작 지붕 그림(불투명한 부분만)을 그대로.
    roof = art.crop((0, 0, W, R * T))
    bb = roof.getbbox()
    rt = (roof.crop(bb) if bb else roof).copy()
    # 원작 지붕의 둥근 뒤 모서리(투명)를 줄마다 양 끝 색으로 채워 네모 판으로 — 비어 있으면 그 자리로 옆벽·뒷벽 위가 뒤로 삐져나왔다
    # (사용자 2026-11-02: 집 양옆 그림이 뒤로 살짝 삐져나온다).
    # 줄 끝 색(외곽선)으로 옆으로 채웠더니 뒤 모서리가 회색 덩어리가 되었다(사용자 2026-11-02 캡처) → 같은 열 아래쪽 지붕 색을 위로
    # 이어(경사면 줄무늬가 뒤 끝까지) 채우고, 맨 윗줄만 원래 외곽선 색으로 가로질러 긋는다.
    rp = rt.load()
    outline = next((rp[xx, 0] for xx in range(rt.width) if rp[xx, 0][3] > 0), None)
    for xx in range(rt.width):
        below = next((rp[xx, yy] for yy in range(rt.height) if rp[xx, yy][3] > 0), None)
        if below is None:
            continue
        for yy in range(rt.height):
            if rp[xx, yy][3] > 0:
                break
            rp[xx, yy] = below
    # 원작 모임지붕의 뒤 모서리 계단(회색·남색 외곽선 픽셀)도 지운다: 줄마다 가장 바깥의 지붕 색(따뜻한 색) 픽셀을 바깥으로 늘인다.
    warm = lambda c: c[3] > 0 and c[0] > c[2] + 30
    for yy in range(1, rt.height):
        xs = [xx for xx in range(rt.width) if warm(rp[xx, yy])]
        if not xs:
            continue
        for xx in range(0, xs[0]):
            rp[xx, yy] = rp[xs[0], yy]
        for xx in range(xs[-1] + 1, rt.width):
            rp[xx, yy] = rp[xs[-1], yy]
    if outline is not None:
        for xx in range(rt.width):
            rp[xx, 0] = outline
    rt.save(d / (name + "_rooftop.png"))
    # 지붕 경사면(모임지붕 시범 때 쓴 것 — 지금은 안 씀): 원작 지붕 색으로 기와 줄을 8px 간격으로
    cnt = Counter(p[:3] for p in roof.getdata() if p[3] > 0 and p[0] > p[1])
    base = cnt.most_common(1)[0][0]
    darker = sorted([c for c, _ in cnt.most_common(8) if sum(c) < sum(base) and c[0] > 150], key=lambda c: -cnt[c])[:2]
    line_dark = min(darker, key=sum) if darker else (base[0] - 40, base[1] - 60, base[2] - 40)
    line_mid = max(darker, key=sum) if len(darker) > 1 else line_dark
    eave = min((c for c, _ in cnt.most_common(12)), key=sum)
    rh = 40
    rf = Image.new("RGBA", (W + 16, rh), base + (255,))
    rp = rf.load()
    for y in range(rh):
        for x in range(rf.width):
            if y in (0, 1):
                rp[x, y] = line_dark + (255,)                 # 용마루 마감
            elif y >= rh - 3:
                rp[x, y] = (eave if y < rh - 1 else (90, 90, 115)) + (255,)   # 처마 마감
            elif (y - 4) % 8 == 0:
                rp[x, y] = line_dark + (255,)
            elif (y - 4) % 8 == 1:
                rp[x, y] = line_mid + (255,)
    rf.save(d / (name + "_roof.png"))


# ── 작은 물체(우체통) 도트 재구성(사용자 2026-11-02: 우체통도 집과 같은 구조로) ──
# 바깥의 2칸짜리 회색 물체(초록이 적은 — 나무가 아닌) = 우체통. 그림의 불투명한 폭에 맞춘 작은 상자:
#   top   위쪽 40% 줄(위에서 본 뚜껑, 둥근 모서리는 채워 네모로)을 수평으로, front 몸통 줄(투입구)을 세우고, side 는 앞면을 복사
#   (테두리 + 가장자리 안쪽 열). 원작의 바닥 그림자 줄은 빼고(3D 해 그림자가 대신), 기둥은 따로 가는 기둥(post)으로 — 몸통을 그만큼 띄운다.
def build_props(d: Path, cards: list, tile_img):
    props = []
    made = {}
    keep = []
    for c in cards:
        x, y0, n, roof = c[0], c[1], c[2], c[5]
        if n != 2 or roof != 0 or (len(c) > 6 and c[6] != 1.0):
            keep.append(c)
            continue
        art = Image.new("RGBA", (T, 2 * T), (0, 0, 0, 0))
        art.alpha_composite(tile_img(x, y0), (0, 0))
        art.alpha_composite(tile_img(x, y0 + 1), (0, T))
        px = [p for p in art.getdata() if p[3] > 0]
        green = sum(1 for p in px if p[1] > p[0] + 20 and p[1] > p[2])
        bb = art.getbbox()
        if not px or green > 0.25 * len(px) or bb is None or bb[2] - bb[0] > 14:
            keep.append(c)
            continue
        bx0, by0, bx1, by1 = bb
        split = by0 + int(round((by1 - by0) * 0.4))
        key = art.tobytes()
        # 앞면 아래쪽에 원작이 그려 둔 바닥 그림자·기둥 줄: 몸통 바깥 테두리(외곽선 줄)가 끝나는 줄 아래는 몸통이 아니다.
        # 몸통 끝 = 아래에서부터 처음으로 '가로 전체가 외곽선 색'인 줄(우체통 8행). 그 아래 기둥 폭은 외곽선 색 열로.
        frontfull = art.crop((bx0, split, bx1, by1))
        ffp = frontfull.load()
        fw0, fh0 = frontfull.size
        outline = ffp[0, 0]
        body_end = fh0
        for yy in range(fh0 - 1, -1, -1):
            if all(ffp[xx, yy][:3] == outline[:3] for xx in range(fw0)):
                body_end = yy + 1
                break
        post_cols = [xx for xx in range(fw0) if body_end < fh0 and ffp[xx, body_end][:3] == outline[:3]]
        if key not in made:
            name = "hd2d_prop%d" % len(made)
            made[key] = name
            front = frontfull.crop((0, 0, fw0, body_end))
            front.save(d / (name + "_front.png"))
            # 뚜껑(윗면): 둥글게 비어 있는 모서리를 줄마다 양 끝 색으로 채워 몸통과 같은 네모로(옆면 위 모서리가 튀어나와 보였다)
            top = art.crop((bx0, by0, bx1, split))
            tp = top.load()
            for yy in range(top.height):
                xs = [xx for xx in range(top.width) if tp[xx, yy][3] > 0]
                if not xs:
                    continue
                for xx in range(top.width):
                    if tp[xx, yy][3] == 0:
                        tp[xx, yy] = tp[xs[0], yy] if xx < xs[0] else tp[xs[-1], yy]
            top.save(d / (name + "_top.png"))
            # 옆면: 위아래 테두리 한 줄씩 + 앞면 가장자리 안쪽 열의 색(투입구 검은 줄은 넣지 않는다), 양 끝 세로 테두리
            depth = top.height
            fp = front.load()
            side = Image.new("RGBA", (depth, body_end), (0, 0, 0, 0))
            sp = side.load()
            inner = fw0 - 2
            for yy in range(body_end):
                for sx in range(depth):
                    if yy == 0 or yy == body_end - 1 or sx == 0 or sx == depth - 1:
                        sp[sx, yy] = outline
                    else:
                        sp[sx, yy] = fp[inner, yy]
            side.save(d / (name + "_side.png"))
            # 기둥: 외곽선 색 테두리 + 가운데 밝은 줄
            pw = max(2, len(post_cols))
            post = Image.new("RGBA", (pw, 4), outline)
            pp = post.load()
            for yy in range(4):
                for xx in range(1, pw - 1):
                    pp[xx, yy] = ffp[post_cols[0] + 1, body_end] if post_cols and post_cols[0] + 1 < fw0 else outline
            post.save(d / (name + "_post.png"))
        post_x0 = (bx0 + (post_cols[0] if post_cols else fw0 // 2 - 1)) / T
        post_x1 = (bx0 + (post_cols[-1] + 1 if post_cols else fw0 // 2 + 1)) / T
        post_h = (fh0 - body_end) / T
        props.append({"x0": x + bx0 / T, "x1": x + bx1 / T, "z": y0 + by1 / T, "d": (split - by0) / T, "h": body_end / T,
                      "post": post_h, "px0": x + post_x0, "px1": x + post_x1, "tex": made[key]})
    return props, keep


if __name__ == "__main__":
    # 인자가 없으면 지도 전부(건물 안·숲·경기장 포함 — 사용자 2026-11-02: 건물 안도 HD-2D)
    names = sys.argv[1:] or sorted(p.name for p in (ROOT / "assets" / "maps").iterdir() if (p / "map.json").exists())
    for n in names:
        build(n)
