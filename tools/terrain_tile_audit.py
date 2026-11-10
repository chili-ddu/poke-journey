"""Audit native outdoor coordinates and remove ledge art copied as prop floor fill."""
import json
from collections import Counter
from pathlib import Path

from PIL import Image
import frlg_map as fm
from north_terrain import source_cells
from terrain_topology import CITIES
from terrain_ground import pixels, surface_palette, restore_tree_floor, restore_bank_floor

ROOT = Path(__file__).resolve().parents[1]


def clean_floor(name):
    d = ROOT / 'assets/maps' / name
    j = json.loads((d / 'map.json').read_text())
    w, h, pad = j['width'], j['height'], j['pad']
    raw = Image.open(d / 'bottom.png').convert('RGBA')
    floor = Image.open(d / 'hd2d_floor.png').convert('RGBA')
    folders = [CITIES.get(a['id'], a['id'].replace('route', 'Route')) for a in j['areas']]
    mids = source_cells(j, folders)

    def tile(image, x, y):
        return image.crop(((x+pad)*16, (y+pad)*16, (x+pad+1)*16, (y+pad+1)*16))

    ledge_art = {tile(raw, x, y).tobytes() for y in range(h) for x in range(w) if j['ledge'][y][x] != '0'}
    donors = {}
    for (x, y), mid in sorted(mids.items()):
        if mid not in (8, 9, 0xd9) or j['ledge'][y][x] != '0' or j['solid'][y][x] != '0':
            continue
        art = tile(raw, x, y)
        color, n = Counter(pixels(art)).most_common(1)[0]
        if n >= 0.8*256 and color[1]-color[0] >= 16 and color[1]-color[2] >= 8:
            donors[x, y] = art
    assert donors, 'Native clean grass donors are required'
    repairs = []
    for y in range(h):
        for x in range(w):
            if j['ledge'][y][x] != '0' or tile(floor, x, y).tobytes() not in ledge_art:
                continue
            # Only an exact copy of native ledge artwork is replaced. Actual
            # native ledges, paths, cliffs in the standing atlas, and trees stay.
            candidates = donors
            area = next((a for a in j['areas'] if a['x'] <= x < a['x']+a['w'] and a['y'] <= y < a['y']+a['h']), None)
            if area:
                local = [xy for xy in donors if area['x'] <= xy[0] < area['x']+area['w'] and area['y'] <= xy[1] < area['y']+area['h']]
                candidates = local or donors
            source = min(candidates, key=lambda xy: ((xy[0]-x)**2+(xy[1]-y)**2, xy))
            floor.paste(donors[source], ((x+pad)*16, (y+pad)*16))
            repairs.append({'tile': [x, y], 'donor': list(source), 'source_mid': mids.get((x, y))})
    native_ground = surface_palette(tile(raw,x,y) for x,y in mids if j['solid'][y][x]=='0' and j['grass'][y][x]=='0' and j['ledge'][y][x]=='0')
    cards = json.loads((d/'hd2d_cards.json').read_text())
    tree_cells = {(int(c[0]),int(c[1])+row) for c in cards['cards'] if len(c)>9 and c[9]==1 for row in range(int(c[2]))}
    tree_repairs = restore_tree_floor(j,raw,floor,tree_cells,donors,native_ground)
    from terrain_topology import topology
    ledges,turns,_ = topology(j)
    banks = set(ledges)|turns
    restore_bank_floor(j,raw,floor,banks,native_ground,next(iter(donors.values())))
    # An open editor must never import a partially written PNG.
    temporary = d / 'elevation_floor.png.tmp'
    floor.save(temporary, format='PNG')
    temporary.replace(d / 'elevation_floor.png')

    differences = []
    checked = 0
    warps = {(int(a['x']), int(a['y'])) for a in j['warps']}
    covered = {(x,y) for a in j['areas'] for y in range(a['y'],a['y']+a['h']) for x in range(a['x'],a['x']+a['w'])}
    for area, folder in zip(j['areas'], folders):
        native = fm.bake_layout(fm.layout_of(fm.map_json(folder)['layout']))
        assert (area['w'], area['h']) == (native['w'], native['h'])
        for y in range(native['h']):
            for x in range(native['w']):
                gx, gy = x+area['x'], y+area['y']
                checked += 1
                for key in ('solid', 'grass', 'ledge'):
                    expected, actual = str(native[key][y][x]), j[key][gy][gx]
                    if actual == expected:
                        continue
                    exposed = (x in (0,native['w']-1) or y in (0,native['h']-1)) and any((gx+dx,gy+dy) not in covered for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)])
                    reason = 'warp entrance' if key == 'solid' and (gx, gy) in warps and actual == '0' else 'unconnected region boundary' if key == 'solid' and exposed and actual == '1' else 'unexplained'
                    differences.append({'area': area['id'], 'tile': [gx, gy], 'field': key, 'native': expected, 'actual': actual, 'reason': reason})
    unexplained = [a for a in differences if a['reason'] == 'unexplained']
    remaining = sum(j['ledge'][y][x] == '0' and tile(floor, x, y).tobytes() in ledge_art for y in range(h) for x in range(w))
    report = dict(native_tiles_checked=checked, repaired_floor_copies=repairs, remaining_wrong_floor_copies=remaining, tree_floor_repairs=tree_repairs, native_bank_ground_tiles=[list(xy) for xy in sorted(banks)], native_flag_differences=differences, unexplained_differences=unexplained)
    (d / 'terrain_tile_audit.json').write_text(json.dumps(report, indent=2)+'\n')
    assert not unexplained, unexplained
    assert remaining == 0
    print(name, 'native tiles', checked, 'wrong ledge floor copies repaired', len(repairs), 'tree ground repaired',len(tree_repairs), 'native bank ground',len(banks))
    return report


if __name__ == '__main__':
    import sys
    for name in sys.argv[1:] or ['kanto_field', 'kanto_east']:
        clean_floor(name)
