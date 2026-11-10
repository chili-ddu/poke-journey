"""DS(Nitro) NARC 안의 그림을 PNG 로 풀어 본다 — 플래티넘 전투 아래 화면 UI(기술 버튼 등)를 찾기 위한 도구.

  python3 -I tools/nitro_dump.py <narc> <출력 폴더> [--sheet]

NARC 안 파일: LZ10(0x10) 압축일 수 있다. RLCN(NCLR 팔레트), RGCN(NCGR 타일), RCSN(NSCR 화면 타일맵), RECN(NCER 셀) 을 다룬다.
NSCR 은 "가장 가까운 앞의 NCGR + NCLR" 로 그린다(배틀 BG NARC 는 보통 NCGR·NSCR·NCLR 이 묶여 있다).
결과: <idx>_<종류>.png 와 --sheet 면 전체 썸네일 sheet.png. 원작 자료는 personal use 로만.
"""
import struct
import sys
from pathlib import Path

from PIL import Image


def lz10(data: bytes) -> bytes:
    if not data or data[0] != 0x10:
        return data
    size = struct.unpack("<I", data[:4])[0] >> 8
    out = bytearray()
    i = 4
    while len(out) < size and i < len(data):
        flags = data[i]; i += 1
        for b in range(8):
            if len(out) >= size or i >= len(data):
                break
            if flags & (0x80 >> b):
                hi, lo = data[i], data[i + 1]; i += 2
                n = (hi >> 4) + 3
                disp = ((hi & 0xF) << 8 | lo) + 1
                for _ in range(n):
                    out.append(out[-disp])
            else:
                out.append(data[i]); i += 1
    return bytes(out)


def narc_files(data: bytes) -> list:
    assert data[:4] == b"NARC"
    pos, files, base = 16, [], 0
    while pos < len(data):
        tag = data[pos:pos + 4]; size = struct.unpack("<I", data[pos + 4:pos + 8])[0]
        if tag == b"BTAF":
            cnt = struct.unpack("<H", data[pos + 8:pos + 10])[0]
            files = [struct.unpack("<II", data[pos + 12 + i * 8:pos + 20 + i * 8]) for i in range(cnt)]
        elif tag == b"GMIF":
            base = pos + 8
        pos += size
    return [lz10(data[base + s:base + e]) for s, e in files]


def sections(d: bytes) -> dict:
    """Nitro 파일 공통 헤더 뒤의 섹션들 {tag: bytes(본문)}."""
    out = {}
    n = struct.unpack("<H", d[14:16])[0]
    pos = 16
    for _ in range(n):
        tag = d[pos:pos + 4][::-1].decode("ascii", "replace")
        size = struct.unpack("<I", d[pos + 4:pos + 8])[0]
        out[tag] = d[pos + 8:pos + size]
        pos += size
    return out


def nclr(d: bytes) -> list:
    s = sections(d)["PLTT"]
    depth = struct.unpack("<I", s[0:4])[0]
    size = struct.unpack("<I", s[8:12])[0]
    off = struct.unpack("<I", s[12:16])[0]
    raw = s[off:off + size]
    pal = []
    for i in range(0, len(raw) - 1, 2):
        v = struct.unpack("<H", raw[i:i + 2])[0]
        pal.append(((v & 31) * 8, ((v >> 5) & 31) * 8, ((v >> 10) & 31) * 8))
    return pal


def ncgr(d: bytes) -> tuple:
    """(tiles: list of 64-index lists, bpp, tiles_w, tiles_h)."""
    s = sections(d)["CHAR"]
    th, tw = struct.unpack("<HH", s[0:4])
    depth = struct.unpack("<I", s[4:8])[0]      # 3 = 4bpp, 4 = 8bpp
    size = struct.unpack("<I", s[16:20])[0]
    off = struct.unpack("<I", s[20:24])[0]
    raw = s[off:off + size]
    tiles = []
    if depth == 3:
        for t in range(len(raw) // 32):
            b = raw[t * 32:t * 32 + 32]
            tiles.append([(b[i // 2] >> (4 * (i % 2))) & 0xF for i in range(64)])
    else:
        for t in range(len(raw) // 64):
            tiles.append(list(raw[t * 64:t * 64 + 64]))
    return tiles, (4 if depth == 3 else 8), tw, th


def nscr(d: bytes) -> tuple:
    s = sections(d)["SCRN"]
    w, h = struct.unpack("<HH", s[0:4])
    fmt = struct.unpack("<HH", s[4:8])
    size = struct.unpack("<I", s[8:12])[0]
    raw = s[12:12 + size]
    entries = struct.unpack("<%dH" % (len(raw) // 2), raw)
    return w, h, entries


def draw_tiles(tiles, pal, cols=32, pal_index=0, bpp=4) -> Image.Image:
    rows = (len(tiles) + cols - 1) // cols
    im = Image.new("RGBA", (cols * 8, max(1, rows) * 8), (0, 0, 0, 0))
    for t, tile in enumerate(tiles):
        tx, ty = (t % cols) * 8, (t // cols) * 8
        for i, ci in enumerate(tile):
            if ci == 0:
                continue
            c = pal[(pal_index * 16 + ci) % len(pal)] if bpp == 4 else pal[ci % len(pal)]
            im.putpixel((tx + i % 8, ty + i // 8), c + (255,))
    return im


def draw_screen(w, h, entries, tiles, pal, bpp) -> Image.Image:
    im = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    cols = w // 8
    for n, e in enumerate(entries):
        t = e & 0x3FF; hf = (e >> 10) & 1; vf = (e >> 11) & 1; pi = e >> 12
        if t >= len(tiles):
            continue
        tile = tiles[t]
        x0, y0 = (n % cols) * 8, (n // cols) * 8
        for i, ci in enumerate(tile):
            if ci == 0:
                continue
            x, y = i % 8, i // 8
            if hf: x = 7 - x
            if vf: y = 7 - y
            c = pal[(pi * 16 + ci) % len(pal)] if bpp == 4 else pal[ci % len(pal)]
            if x0 + x < w and y0 + y < h:
                im.putpixel((x0 + x, y0 + y), c + (255,))
    return im


GRAY = [(i * 17, i * 17, i * 17) for i in range(16)] * 16


def main():
    src = Path(sys.argv[1]); out = Path(sys.argv[2]); out.mkdir(parents=True, exist_ok=True)
    files = narc_files(src.read_bytes())
    gray = "--gray" in sys.argv   # 팔레트를 모를 때 모양만 보기(인덱스 → 회색)
    last_tiles, last_bpp, last_pal = None, 4, (GRAY if gray else [(0, 0, 0)] * 256)
    thumbs = []
    for i, f in enumerate(files):
        tag = f[:4]
        try:
            if tag == b"RLCN":
                if not gray:
                    last_pal = nclr(f)
            elif tag == b"RGCN":
                last_tiles, last_bpp, tw, th = ncgr(f)
                im = draw_tiles(last_tiles, last_pal, 32 if tw in (0, 0xFFFF) else max(1, tw), 0, last_bpp)
                im.save(out / f"{i:03d}_ncgr.png"); thumbs.append((i, "ncgr", im))
            elif tag == b"RCSN":
                w, h, entries = nscr(f)
                if last_tiles:
                    im = draw_screen(w, h, entries, last_tiles, last_pal, last_bpp)
                    im.save(out / f"{i:03d}_nscr.png"); thumbs.append((i, "nscr", im))
        except Exception as ex:
            print(i, tag, "fail", ex)
    print(f"{len(files)} files, {len(thumbs)} images → {out}")
    if "--sheet" in sys.argv and thumbs:
        cell = 160
        cols = 8
        rows = (len(thumbs) + cols - 1) // cols
        sheet = Image.new("RGBA", (cols * cell, rows * cell), (40, 40, 40, 255))
        for k, (i, kind, im) in enumerate(thumbs):
            th = im.copy(); th.thumbnail((cell - 8, cell - 8))
            sheet.paste(th, ((k % cols) * cell + 4, (k // cols) * cell + 4), th)
        sheet.save(out / "sheet.png")
        print("sheet:", [(i, kind) for i, kind, _ in thumbs])


if __name__ == "__main__":
    main()
