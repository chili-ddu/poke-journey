"""Reproducible woven nest, concave ground and matching collision/roost data.

Drawn at the project's native 16-pixel tile resolution; only the nest is written.
"""
import json
import math
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets/maps/arena_bird_nest"

SIZE, PAD, TILE = 24, 10, 16
CENTER = SIZE / 2
ROOSTS = [(-3.5, 3.7), (3.8, 3.3), (-4.6, 0.0), (-2.8, -3.4), (.9, -4.5), (4.2, -2.1)]
ENTRIES = [(-4.5, -1.9), (-.9, -4.8), (3.5, -3.5), (4.9, 1.3), (1.2, 4.6), (-4.1, 2.6)]


def smooth(t):
    t = max(0, min(1, t))
    return t*t*(3-2*t)


def radius_at(x, y):
    angle = math.atan2(y, x)
    return math.hypot(x, y)/(1 + .02*math.sin(3*angle) + .012*math.sin(7*angle))


def height_at(x, y):
    """A recessed lining, sloping inner wall and a low, rounded woven lip."""
    r = radius_at(x-CENTER, y-CENTER)
    if r < 5.8:
        return -.8 + .05*(r/5.8)**2
    if r < 8.25:
        return -.75 + 1.4*smooth((r-5.8)/2.45)
    if r < 9.5:
        return .65*(1-smooth((r-8.25)/1.25))
    return -3.2*smooth((r-9.5)/2.5)


def main():
    from nest_pixel_art import build
    OUT.mkdir(parents=True, exist_ok=True)
    bottom, floor, atlas, cards = build(SIZE, PAD, radius_at, height_at)
    for name in ["bottom.png", "preview.png"]:
        bottom.save(OUT/name)
    for name in ["hd2d_floor.png", "elevation_floor.png"]:
        floor.save(OUT/name)
    atlas.save(OUT/"hd2d_atlas.png")
    Image.new("RGBA", (SIZE*TILE, SIZE*TILE)).save(OUT/"top.png")
    rows = ["".join("0" if math.hypot(x+.5-CENTER, y+.5-CENTER) <= 7 else "1" for x in range(SIZE)) for y in range(SIZE)]
    data = dict(width=SIZE, height=SIZE, tile=TILE, pad=PAD, solid=rows,
                grass=["0"*SIZE]*SIZE, ledge=["0"*SIZE]*SIZE, start=[12*16+8, 14*16+8],
                areas=[dict(id="arena_bird_nest", x=0, y=0, w=SIZE, h=SIZE)], warps=[],
                arena=dict(surface="natural", style="border", player=[12, 14], field=[5, 5, 14, 14],
                           nest=dict(center=[CENTER, CENTER], basin_radius=5.8,
                                     roosts=[[CENTER+x, CENTER+y] for x, y in ROOSTS],
                                     entries=[[CENTER+x, CENTER+y] for x, y in ENTRIES])),
                source="Original nest pixel art and geometry: tools/bird_nest_map.py + nest_pixel_art.py; FRLG Viridian Forest crowns")
    (OUT/"map.json").write_text(json.dumps(data, indent=2)+"\n")
    (OUT/"hd2d_cards.json").write_text(json.dumps(cards, separators=(",", ":"))+"\n")
    corners = []
    for y in range(SIZE):
        corners.append([[round(height_at(x+dx, y+dy), 5) for dx, dy in [(0, 0), (1, 0), (1, 1), (0, 1)]] for x in range(SIZE)])
    (OUT/"elevation.json").write_text(json.dumps(dict(version=2, corners=corners, ledges=[],
                                                    source="Recessed straw lining; lower forest floor under raised native crowns"), separators=(",", ":"))+"\n")
    print("Bird nest:", cards["art"]["canopy_trees"], "native crowns; eight-color pixel lining; raised wooden rim; six interior roosts")


if __name__ == "__main__":
    main()
