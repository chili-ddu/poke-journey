"""Join audited outdoor assets without rebaking their buildings or furniture.

Run after regenerating south/north cards and water: python3 tools/kanto_seamless.py
The source regions remain available for editing; the game loads kanto_field.
"""
import copy
import json
import shutil
from pathlib import Path
from PIL import Image
import frlg_map as fm
from north_terrain import remove_cells

ROOT = Path(__file__).resolve().parents[1]
MAPS = ROOT / 'assets/maps'
PARTS = [('kanto_south', 0, 20), ('kanto_north', 48, 0)]


def read(path):
    return json.loads(path.read_text())


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def move_object(value, dx, dy, prefix):
    if isinstance(value, list):
        return [move_object(v, dx, dy, prefix) for v in value]
    if not isinstance(value, dict):
        return value
    result = {}
    for key, val in value.items():
        if key in ('x', 'x0', 'x1', 'px0', 'px1') and isinstance(val, (float, int)):
            result[key] = val + dx
        elif key in ('z', 'z0', 'z1') and isinstance(val, (float, int)):
            result[key] = val + dy
        elif key == 'tex':
            result[key] = prefix + val
        elif key == 'tile':
            result[key] = [val[0] + dx, val[1] + dy]
        elif key == 'posts':
            result[key] = [[p[0] + dx, p[1] + dy] for p in val]
        else:
            result[key] = move_object(val, dx, dy, prefix)
    return result


def build():
    out = MAPS / 'kanto_field'
    out.mkdir(exist_ok=True)
    sources = [(name, dx, dy, read(MAPS/name/'map.json')) for name, dx, dy in PARTS]
    width = max(dx+j['width'] for _, dx, _, j in sources)
    height = max(dy+j['height'] for _, _, dy, j in sources)
    pad = 10
    data = dict(width=width, height=height, tile=16, pad=pad, areas=[], warps=[],
                start=[sources[0][3]['start'][0], sources[0][3]['start'][1]+20*16])
    rows = {key: [list(default*width) for _ in range(height)]
            for key, default in [('solid', '1'), ('grass', '0'), ('ledge', '0'), ('water', '0')]}
    images = {key: Image.new('RGBA', ((width+2*pad)*16, (height+2*pad)*16), (0,0,0,255))
              for key in ('bottom', 'hd2d_floor')}
    images['top'] = Image.new('RGBA', (width*16, height*16))
    atlases = [Image.open(MAPS/name/'hd2d_atlas.png').convert('RGBA') for name, _, _ in PARTS]
    atlas = Image.new('RGBA', (max(im.width for im in atlases), sum(im.height for im in atlases)))
    cards = dict(tile=16, cards=[], houses=[], props=[], tables=[], log_fences=[])
    side_surfaces = {}
    patch = dict(open=[], block=[])
    atlas_y = 0
    # Native walking lanes, previously hidden behind artificial outer-boundary walls.
    # Restore every native walkable cell on the former source-region boundary.
    # The two source sides do not have identical widths (Pewter: 4, Route3: 4).
    seam_cells = set()
    native_areas = {a['id']:dict(a,x=a['x']+dx,y=a['y']+dy) for _,dx,dy,j in sources for a in j['areas']}
    for folder, edge_x in [('PewterCity',47),('Route3',48)]:
        native = fm.bake_layout(fm.layout_of(fm.map_json(folder)['layout']))
        area = native_areas[fm.snake(folder)]
        lx = edge_x-area['x']
        seam_cells.update((edge_x,area['y']+y) for y in range(native['h']) if native['solid'][y][lx]==0 and native['ledge'][y][lx]=='0')
    for part, (name, dx, dy, j) in enumerate(sources):
        source = MAPS/name
        prefix = name + '_'
        for f in source.iterdir():
            if f.suffix in ('.png', '.svg') and f.stem not in ('bottom','top','preview','hd2d_atlas','hd2d_floor'):
                shutil.copyfile(f, out/(prefix+f.name))
        for key in rows:
            values = read(source/'water.json')['water'] if key == 'water' else j[key]
            for y, row in enumerate(values):
                rows[key][y+dy][dx:dx+j['width']] = list(row)
        for area in j['areas']:
            data['areas'].append(dict(area, x=area['x']+dx, y=area['y']+dy))
        data['warps'] += [dict(w, x=w['x']+dx, y=w['y']+dy) for w in j['warps'] if not w.get('edge_transition')]
        for key, target in images.items():
            im = Image.open(source/(key+'.png')).convert('RGBA')
            sp = 0 if key == 'top' else j['pad']
            tp = 0 if key == 'top' else pad
            # Keep the original padding; later sources own their actual map rectangle.
            target.alpha_composite(im, ((dx+tp-sp)*16, (dy+tp-sp)*16))
        c = read(source/'hd2d_cards.json')
        atlas.alpha_composite(atlases[part], (0, atlas_y))
        local_seam = {(x-dx,y-dy) for x,y in seam_cells if dx<=x<dx+j['width'] and dy<=y<dy+j['height']}
        for card in remove_cells(c['cards'],local_seam):
            card = copy.deepcopy(card)
            card[0] += dx
            card[1] += dy
            card[4] += atlas_y
            cards['cards'].append(card)
        for key in ('houses','props','tables','log_fences'):
            cards[key] += move_object(c.get(key, []), dx, dy, prefix)
        sf = source/'hd2d_side_surfaces.json'
        if sf.exists():
            for key, value in read(sf).items():
                x, y, face = key.split(':')
                side_surfaces[f'{int(x)+dx}:{int(y)+dy}:{face}'] = dict(value, texture=prefix+value['texture'])
        pf = source/'collision_patch.json'
        if pf.exists():
            for key in patch:
                patch[key] += [[x+dx,y+dy] for x,y in read(pf).get(key, [])]
        atlas_y += atlases[part].height
    # Actual map pixels win over neighboring decorative padding.
    for name, dx, dy, j in sources:
        for key, target in images.items():
            im = Image.open(MAPS/name/(key+'.png')).convert('RGBA')
            sp = 0 if key == 'top' else j['pad']
            tp = 0 if key == 'top' else pad
            crop = im.crop((sp*16, sp*16, (sp+j['width'])*16, (sp+j['height'])*16))
            target.paste(crop, ((dx+tp)*16, (dy+tp)*16))
    # Restore the native seam cells and original floor pixels on the old blocked strip.
    for x,y in sorted(seam_cells):
        rows['solid'][y][x] = '0'
        name, dx, dy = PARTS[0 if x == 47 else 1]
        j = sources[0 if x == 47 else 1][3]
        im = Image.open(MAPS/name/'bottom.png')
        sx, sy = x-dx+j['pad'], y-dy+j['pad']
        images['hd2d_floor'].paste(im.crop((sx*16,sy*16,(sx+1)*16,(sy+1)*16)), ((x+pad)*16,(y+pad)*16))
    for key in ('solid','grass','ledge'):
        data[key] = [''.join(row) for row in rows[key]]
    data['source'] = 'Audited kanto_south + kanto_north; native Pewter/Route3 connection'
    for key, im in images.items(): im.save(out/(key+'.png'))
    atlas.save(out/'hd2d_atlas.png')
    write(out/'map.json', data)
    write(out/'hd2d_cards.json', cards)
    write(out/'water.json', {'water': [''.join(row) for row in rows['water']]})
    write(out/'collision_patch.json', patch)
    write(out/'hd2d_side_surfaces.json', side_surfaces)
    print('kanto_field', width, height, 'cards', len(cards['cards']))
    from road_elevation import bake as road_elevation
    for region in ('kanto_field','kanto_east'):road_elevation(region)
    if (MAPS/'cerulean_north/map.json').exists():
        from cerulean_progression import link_north
        link_north()


if __name__ == '__main__':
    build()
