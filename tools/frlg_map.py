"""FRLG(pret/pokefirered) 지도를 게임용으로 굽는다 → assets/maps/<이름>/{bottom.png, top.png, map.json, preview.png}

  지도 한 장:   python3 -I tools/frlg_map.py <지도 폴더> <출력 이름> [--start X,Y]
                예) python3 -I tools/frlg_map.py PalletTown_ProfessorOaksLab oaks_lab --start 6,8
  이어 붙이기: python3 -I tools/frlg_map.py --region <출력 이름> <지도 폴더> <지도 폴더> ... [--start X,Y]
                예) python3 -I tools/frlg_map.py --region kanto_south PalletTown Route1 ViridianCity
                첫 지도가 원점. 나머지는 map.json 의 connections(up/down/left/right + offset)대로 붙는다(원작처럼 로딩 없이 걷게).
<지도 폴더> 는 pret 의 data/maps/<폴더>(map.json: layout, connections, warp_events). 필요한 파일은 raw.githubusercontent.com 에서
third_party/pokefirered/ 로 받는다(이미 있으면 건너뜀).

형식(pokefirered)
  map.bin               칸마다 u16: 0~9 메타타일 번호, 10~11 통행(0 이면 지나감), 12~15 높이
  metatiles.bin         메타타일마다 u16 ×8: 아래층 4타일 + 위층 4타일. 0~9 타일 번호, 10 좌우 뒤집기, 11 상하 뒤집기, 12~15 팔레트
  metatile_attributes   메타타일마다 u32: 0~8 behavior(2 = 풀숲; 물·문·워프는 막힌 칸으로), 29~30 층 종류(0 NORMAL, 1 COVERED, 2 SPLIT)
  tiles.png             4bpp 인덱스, 폭 128(한 줄 16타일), 1차 640타일·2차는 640번부터
  palettes/NN.pal       JASC, 1차 00~06, 2차 07~12
층 종류 → 그림: NORMAL 은 아래층→bottom·위층→top(포켓몬 위), COVERED 는 둘 다 bottom, SPLIT 은 아래층→bottom·위층→top.
map.json: width, height, tile 16, solid·grass(행 문자열), start(원본 px), areas[{id, x, y, w, h}](어느 원작 지도의 칸인지 — 출현표 구역),
          warps[{x, y, map, index, to, to_warp}](문: 그 칸에 서면 to 지도의 to_warp 번째 문으로), source.
          워프 칸은 통행 가능으로 둔다(문에 들어가야 하므로). 지도 바깥 가장자리는 막는다.
          pad: bottom.png 는 사방으로 PAD 칸 더 크다(원작 테두리 border.bin 무늬로 채움 — 화면이 지도보다 넓을 때 검게 비지 않게).
          어느 원작 지도에도 안 속한 안쪽 빈 칸(이어 붙인 지도의 옆)도 가장 가까운 지도의 테두리로 채운다(아래층→bottom, 위층→top).
          top.png 는 여백 없이 width×height.
원작 자료는 Nintendo / Game Freak / Creatures — personal use 로만.
"""
import json
import re
import struct
import sys
import urllib.request
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PAD = 10   # bottom.png 사방 여백(칸). 시야 최대 576×324(24px 칸)에서 13칸짜리 건물도 양옆이 채워지는 폭.
TP = ROOT / "third_party" / "pokefirered"
RAW = "https://raw.githubusercontent.com/pret/pokefirered/master/"
PRIMARY_METATILES = 640
PRIMARY_TILES = 640
TILE = 8
MB_TALL_GRASS = 0x02
# 언덕(MB_JUMP_*): 원작은 그 방향으로만 뛰어내릴 수 있고 걸어서는 못 지난다. 게임에선 걸어 내려가면 자동 점프, 점프로는 올라갈 수도 있다(사용자 결정 2026-10-28).
LEDGE_BEHAVIORS = {0x38: "e", 0x39: "w", 0x3A: "n", 0x3B: "s"}
# 통행 비트가 0 이어도 걸어서 못 가는 칸(include/constants/metatile_behaviors.h): 물(파도타기 전용)과 문·사다리·워프.
BLOCKED_BEHAVIORS = set(range(0x10, 0x1C)) - {0x17} | set(range(0x60, 0x72))


def fetch(rel: str) -> Path:
    dst = TP / rel
    if not dst.exists():
        dst.parent.mkdir(parents=True, exist_ok=True)
        with urllib.request.urlopen(RAW + rel, timeout=60) as r:
            dst.write_bytes(r.read())
    return dst


def snake(folder: str) -> str:
    """pret 상수 이름과 같은 꼴로: PalletTown_ProfessorOaksLab → pallet_town_professor_oaks_lab, Route1 → route1, PlayersHouse_1F → players_house_1f."""
    return re.sub(r"(?<=[a-z])([A-Z])", r"_\1", folder).lower()


def map_const(folder: str) -> str:
    return "MAP_" + snake(folder).upper()


def tileset_dir(name: str) -> str:
    """gTileset_General → data/tilesets/primary/general, gTileset_PalletTown → data/tilesets/secondary/pallet_town."""
    base = name.replace("gTileset_", "")
    sn = "".join(("_" + c.lower()) if c.isupper() and i else c.lower() for i, c in enumerate(base))
    sn = re.sub(r"([a-z])(\d)", r"\1_\2", sn)   # GenericBuilding1 → generic_building_1
    for kind in ("primary", "secondary"):
        rel = f"data/tilesets/{kind}/{sn}/metatiles.bin"
        try:
            fetch(rel)
            return f"data/tilesets/{kind}/{sn}"
        except Exception:
            continue
    raise SystemExit("타일셋을 못 찾음 " + name)


_tileset_files = {}

def tileset_files(name: str) -> dict:
    """Resolve shared native graphics/palettes independently from metatiles.

    For example Silph Co has its own metatiles but uses Condominiums graphics.
    The tileset header is authoritative; folder-name guesses lose those maps.
    """
    if name in _tileset_files:return _tileset_files[name]
    headers=fetch('src/data/tilesets/headers.h').read_text()
    graphics=fetch('src/data/tilesets/graphics.h').read_text()+'\n'+fetch('src/graphics.c').read_text()
    block=re.search(r'const struct Tileset '+re.escape(name)+r'\s*=\s*\{(.*?)\};',headers,re.S)[1]
    tile_symbol=re.search(r'\.tiles\s*=\s*(\w+)',block)[1]
    palette_symbol=re.search(r'\.palettes\s*=\s*(\w+)',block)[1]
    tile=re.search(r'\b'+re.escape(tile_symbol)+r'\[\]\s*=\s*INCBIN_U32\("([^"]+)"\)',graphics)[1]
    palette_block=re.search(r'\b'+re.escape(palette_symbol)+r'\[\]\[16\]\s*=\s*\{(.*?)\};',graphics,re.S)[1]
    palettes=[value.replace('.gbapal','.pal') for value in re.findall(r'INCBIN_U16\("([^"]+)"\)',palette_block)]
    result=dict(metatiles=tileset_dir(name),tiles=tile.replace('.4bpp.lz','.png'),palettes=palettes)
    _tileset_files[name]=result
    return result


def jasc(path: Path) -> list:
    lines = path.read_text().splitlines()
    n = int(lines[2])
    return [tuple(int(v) for v in l.split()) for l in lines[3:3 + n]]


def load_tiles(png: Path) -> list:
    im = Image.open(png)
    cols = im.width // TILE
    tiles = []
    for t in range((im.height // TILE) * cols):
        x0, y0 = (t % cols) * TILE, (t // cols) * TILE
        tiles.append([im.getpixel((x0 + i % TILE, y0 + i // TILE)) for i in range(64)])
    return tiles


_layouts = None


def layout_of(layout_id: str) -> dict:
    global _layouts
    if _layouts is None:
        _layouts = json.loads(fetch("data/layouts/layouts.json").read_text())["layouts"]
    return next(l for l in _layouts if l.get("id") == layout_id)


def map_json(folder: str) -> dict:
    return json.loads(fetch(f"data/maps/{folder}/map.json").read_text())


def bake_layout(lay: dict) -> dict:
    """지도 한 장을 그린다: {w, h, bottom, top, solid[[...]], grass[[...]]}."""
    w, h = lay["width"], lay["height"]
    blocks = struct.unpack(f"<{w * h}H", fetch(lay["blockdata_filepath"]).read_bytes())
    primary,secondary=tileset_files(lay["primary_tileset"]),tileset_files(lay["secondary_tileset"])
    pri,sec=primary['metatiles'],secondary['metatiles']
    pals = [jasc(fetch(primary['palettes'][i])) for i in range(7)] + [jasc(fetch(secondary['palettes'][i])) for i in range(7, 13)]
    while len(pals) < 16:
        pals.append([(0, 0, 0)] * 16)
    tiles = load_tiles(fetch(primary['tiles']))
    tiles = tiles[:PRIMARY_TILES] + [[0] * 64] * max(0, PRIMARY_TILES - len(tiles)) + load_tiles(fetch(secondary['tiles']))
    meta, attrs = {}, {}
    for base, d in ((0, pri), (PRIMARY_METATILES, sec)):
        mb = fetch(f"{d}/metatiles.bin").read_bytes()
        ab = fetch(f"{d}/metatile_attributes.bin").read_bytes()
        for i in range(len(mb) // 16):
            meta[base + i] = struct.unpack("<8H", mb[i * 16:i * 16 + 16])
        for i in range(len(ab) // 4):
            attrs[base + i] = struct.unpack("<I", ab[i * 4:i * 4 + 4])[0]
    bottom = Image.new("RGBA", (w * 16, h * 16), (0, 0, 0, 0))
    top = Image.new("RGBA", (w * 16, h * 16), (0, 0, 0, 0))
    bp, tp = bottom.load(), top.load()

    def draw_metatile(mid: int, x0: int, y0: int, bdst, tdst):
        m = meta.get(mid)
        if m is None:
            return
        layer_type = (attrs.get(mid, 0) >> 29) & 3
        for k in range(8):
            dst = bdst if (k < 4 or layer_type == 1) else tdst
            blit(dst, m[k], x0 + (k % 2) * 8, y0 + ((k // 2) % 2) * 8)

    def blit(dst, entry: int, x0: int, y0: int):
        t = entry & 0x3FF
        hf, vf, pal = (entry >> 10) & 1, (entry >> 11) & 1, entry >> 12
        if t >= len(tiles):
            return
        src = tiles[t]
        for i in range(64):
            ci = src[i]
            if ci == 0:
                continue
            x, y = i % 8, i // 8
            if hf:
                x = 7 - x
            if vf:
                y = 7 - y
            dst[x0 + x, y0 + y] = pals[pal][ci] + (255,)

    solid = [[0] * w for _ in range(h)]
    grass = [[0] * w for _ in range(h)]
    ledge = [["0"] * w for _ in range(h)]
    for n, b in enumerate(blocks):
        mid, coll = b & 0x3FF, (b >> 10) & 3
        mx, my = (n % w) * 16, (n // w) * 16
        m = meta.get(mid)
        if m is None:
            continue
        layer_type = (attrs.get(mid, 0) >> 29) & 3
        for k in range(8):
            dst = bp if (k < 4 or layer_type == 1) else tp
            blit(dst, m[k], mx + (k % 2) * 8, my + ((k // 2) % 2) * 8)
        beh = attrs.get(mid, 0) & 0x1FF
        # 언덕은 지도 데이터에서 통행 비트가 1 이지만(원작은 점프 판정이 따로) 여기선 언덕 칸으로 따로 둔다.
        if beh in LEDGE_BEHAVIORS:
            ledge[n // w][n % w] = LEDGE_BEHAVIORS[beh]
        elif coll != 0 or beh in BLOCKED_BEHAVIORS:
            solid[n // w][n % w] = 1
        if beh == MB_TALL_GRASS:
            grass[n // w][n % w] = 1
    # 테두리(border.bin): 지도 밖 칸에 원작이 깔아 두는 무늬. 칸 (lx, ly)(지도 기준, 음수 가능)는 border[lx % bw + (ly % bh) * bw].
    bw, bh = int(lay.get("border_width") or 2), int(lay.get("border_height") or 2)
    bblocks = struct.unpack(f"<{bw * bh}H", fetch(lay["border_filepath"]).read_bytes()[:bw * bh * 2])
    border_b = Image.new("RGBA", (bw * 16, bh * 16), (0, 0, 0, 0))
    border_t = Image.new("RGBA", (bw * 16, bh * 16), (0, 0, 0, 0))
    bbp, btp = border_b.load(), border_t.load()
    for i, blk in enumerate(bblocks):
        draw_metatile(blk & 0x3FF, (i % bw) * 16, (i // bw) * 16, bbp, btp)
    return {"w": w, "h": h, "bottom": bottom, "top": top, "solid": solid, "grass": grass, "ledge": ledge,
            "border": (border_b, border_t, bw, bh)}


def place_maps(folders: list) -> dict:
    """연결 정보대로 칸 좌표에 놓는다 → {folder: (x, y, map.json, layout)}. 첫 지도가 (0,0)."""
    infos = {f: map_json(f) for f in folders}
    lays = {f: layout_of(infos[f]["layout"]) for f in folders}
    consts = {map_const(f): f for f in folders}
    pos = {folders[0]: (0, 0)}
    todo = [folders[0]]
    while todo:
        f = todo.pop()
        x, y = pos[f]
        w, h = lays[f]["width"], lays[f]["height"]
        for c in infos[f].get("connections") or []:
            g = consts.get(c["map"])
            if g is None or g in pos:
                continue
            gw, gh = lays[g]["width"], lays[g]["height"]
            off = int(c["offset"])
            match c["direction"]:
                case "up": pos[g] = (x + off, y - gh)
                case "down": pos[g] = (x + off, y + h)
                case "left": pos[g] = (x - gw, y + off)
                case "right": pos[g] = (x + w, y + off)
            todo.append(g)
    missing = [f for f in folders if f not in pos]
    if missing:
        raise SystemExit("연결되지 않은 지도: %s" % missing)
    minx = min(p[0] for p in pos.values())
    miny = min(p[1] for p in pos.values())
    return {f: (pos[f][0] - minx, pos[f][1] - miny, infos[f], lays[f]) for f in folders}


def bake(folders: list, out_name: str, start: tuple | None, region: bool):
    placed = place_maps(folders) if region else {folders[0]: (0, 0, map_json(folders[0]), layout_of(map_json(folders[0])["layout"]))}
    W = max(x + lay["width"] for x, y, _, lay in placed.values())
    H = max(y + lay["height"] for x, y, _, lay in placed.values())
    bottom = Image.new("RGBA", ((W + 2 * PAD) * 16, (H + 2 * PAD) * 16), (0, 0, 0, 255))
    top = Image.new("RGBA", (W * 16, H * 16), (0, 0, 0, 0))
    solid = [[1] * W for _ in range(H)]        # 어느 지도에도 안 속한 칸은 막힘
    borders = []                               # [(ox, oy, w, h, (border_b, border_t, bw, bh))]
    grass = [[0] * W for _ in range(H)]
    ledge = [["0"] * W for _ in range(H)]
    areas, warps = [], []
    for f, (ox, oy, info, lay) in placed.items():
        b = bake_layout(lay)
        borders.append((ox, oy, b["w"], b["h"], b["border"]))
        bottom.alpha_composite(b["bottom"], ((ox + PAD) * 16, (oy + PAD) * 16))
        top.alpha_composite(b["top"], (ox * 16, oy * 16))
        for y in range(b["h"]):
            for x in range(b["w"]):
                solid[oy + y][ox + x] = b["solid"][y][x]
                grass[oy + y][ox + x] = b["grass"][y][x]
                ledge[oy + y][ox + x] = b["ledge"][y][x]
        areas.append({"id": snake(f), "x": ox, "y": oy, "w": b["w"], "h": b["h"]})
        for i, wv in enumerate(info.get("warp_events") or []):
            wx, wy = ox + int(wv["x"]), oy + int(wv["y"])
            solid[wy][wx] = 0                      # 문에 들어가야 하므로 그 칸은 지나갈 수 있게
            warps.append({"x": wx, "y": wy, "map": snake(f), "index": i,
                          "to": snake(wv["dest_map"].replace("MAP_", "").title().replace("_", "")) if False else wv["dest_map"],
                          "to_warp": int(wv["dest_warp_id"]) if str(wv["dest_warp_id"]).isdigit() else 0})
    fill_borders(bottom, top, borders, W, H)
    # 워프의 to 는 MAP_ 상수 → 폴더식 snake 로(연결 폴더 목록에 없어도 이름은 일관되게)
    for wv in warps:
        wv["to"] = wv["to"].replace("MAP_", "").lower()
    for x in range(W):
        solid[0][x] = solid[H - 1][x] = 1
    for y in range(H):
        solid[y][0] = solid[y][W - 1] = 1
    # 원작 출구 화살표가 맨 가장자리인 실내도 있다. 외곽 봉쇄 뒤 문 칸은 다시 연다.
    for wv in warps:
        solid[wv["y"]][wv["x"]] = 0
    out = ROOT / "assets" / "maps" / out_name
    out.mkdir(parents=True, exist_ok=True)
    bottom.save(out / "bottom.png")
    top.save(out / "top.png")
    if start is None:
        start = (W // 2, H // 2)
    data = {"width": W, "height": H, "tile": 16, "pad": PAD,
            "solid": ["".join(str(v) for v in r) for r in solid], "grass": ["".join(str(v) for v in r) for r in grass],
            "ledge": ["".join(r) for r in ledge],
            "start": [start[0] * 16 + 8, start[1] * 16 + 8], "areas": areas, "warps": warps,
            "source": "pret/pokefirered " + ", ".join(f"{f}({lay['width']}×{lay['height']} @{x},{y})" for f, (x, y, _, lay) in placed.items())}
    (out / "map.json").write_text(json.dumps(data, ensure_ascii=False, indent=0) + "\n")
    preview = bottom.copy()
    preview.alpha_composite(top, (PAD * 16, PAD * 16))
    preview.save(out / "preview.png")
    print(out_name, W, H, "areas", [(a["id"], a["x"], a["y"]) for a in areas], "warps", len(warps),
          "grass", sum(r.count(1) for r in grass), "ledge", sum(len(r) - r.count("0") for r in ledge), "start", data["start"])
    # Field objects are absent from baked background tiles. Keep Cut obstacles
    # synchronized whenever another original map is imported.
    from field_cut_trees import bake as bake_cut_trees
    bake_cut_trees()


def fill_borders(bottom: Image.Image, top: Image.Image, borders: list, W: int, H: int):
    """어느 지도에도 안 속한 칸(여백 + 안쪽 빈 칸)을 가장 가까운 지도의 테두리 무늬로 채운다(원작이 지도 밖에 그리는 것과 같은 무늬)."""
    def inside(x, y, r):
        return r[0] <= x < r[0] + r[2] and r[1] <= y < r[1] + r[3]

    def dist(x, y, r):
        dx = max(r[0] - x, 0, x - (r[0] + r[2] - 1))
        dy = max(r[1] - y, 0, y - (r[1] + r[3] - 1))
        return dx * dx + dy * dy

    for gy in range(-PAD, H + PAD):
        for gx in range(-PAD, W + PAD):
            if any(inside(gx, gy, r) for r in borders):
                continue
            ox, oy, _, _, (bb, bt, bw, bh) = min(borders, key=lambda r: dist(gx, gy, r))
            sx, sy = ((gx - ox) % bw) * 16, ((gy - oy) % bh) * 16
            tb = bb.crop((sx, sy, sx + 16, sy + 16))
            tt = bt.crop((sx, sy, sx + 16, sy + 16))
            px, py = (gx + PAD) * 16, (gy + PAD) * 16
            bottom.paste((0, 0, 0, 255), (px, py, px + 16, py + 16))
            bottom.alpha_composite(tb, (px, py))
            if 0 <= gx < W and 0 <= gy < H:
                top.alpha_composite(tt, (gx * 16, gy * 16))   # 안쪽 칸: 나무 윗부분은 위층(포켓몬과 y 정렬)
            else:
                bottom.alpha_composite(tt, (px, py))          # 여백: 아무도 못 가니 한 장에


def main():
    args = [a for a in sys.argv[1:] if not a.startswith("--")]
    start = None
    if "--start" in sys.argv:
        sv = sys.argv[sys.argv.index("--start") + 1]
        args = [a for a in args if a != sv]
        start = tuple(int(v) for v in sv.split(","))
    if "--region" in sys.argv:
        bake(args[1:], args[0], start, True)
    else:
        bake([args[0]], args[1], start, False)


if __name__ == "__main__":
    main()
