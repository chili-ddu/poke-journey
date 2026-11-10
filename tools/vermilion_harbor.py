"""Connect Vermilion's original harbor permanently after the S.S. Anne has sailed."""
import json
from PIL import Image
import frlg_map as fm
from kanto_water import rows as water_rows
from north_terrain import remove_cells

NAME = 'vermilion_harbor'
SOURCE = 'SSAnne_Exterior'
MAPS = fm.ROOT / 'assets/maps'


def write(path, value):
    path.write_text(json.dumps(value, ensure_ascii=False, indent=2) + '\n')


def city_pier(d, j, metadata):
    """The south exit is flat paving, not a six-tile building/roof column."""
    area = next(a for a in j['areas'] if a['id'] == 'vermilion_city')
    cells = {(area['x'] + x, area['y'] + y) for y in range(34, 40) for x in range(22, 25)}
    metadata['cards'] = remove_cells(metadata['cards'], cells)
    pad = j['pad']
    bottom = Image.open(d / 'bottom.png').convert('RGBA')
    top = Image.open(d / 'top.png').convert('RGBA')
    floor = Image.open(d / 'hd2d_floor.png').convert('RGBA')
    for x, y in cells:
        box = ((x+pad)*16, (y+pad)*16, (x+pad+1)*16, (y+pad+1)*16)
        tile = bottom.crop(box)
        tile.alpha_composite(top.crop((x*16, y*16, (x+1)*16, (y+1)*16)))
        floor.paste(tile, box[:2])
    floor.save(d / 'hd2d_floor.png')
    return metadata


def build():
    fm.bake([SOURCE], NAME, (32, 8), False)
    d = MAPS / NAME
    j = json.loads((d / 'map.json').read_text())
    native = fm.bake_layout(fm.layout_of(fm.map_json(SOURCE)['layout']))
    # The liner is a native object sprite, not part of these background tiles.
    # Keep only the town exits; old boarding triggers must not open sea tiles.
    removed = [w for w in j['warps'] if w['to'] != 'vermilion_city']
    j['warps'] = [dict(w, arrival_dir=[0, 1]) for w in j['warps'] if w['to'] == 'vermilion_city']
    solid = [list(row) for row in j['solid']]
    for warp in removed:
        solid[warp['y']][warp['x']] = str(native['solid'][warp['y']][warp['x']])
    j['solid'] = [''.join(row) for row in solid]
    j['harbor'] = dict(ship_departed=True, source_object='LOCALID_SS_ANNE')
    write(d / 'map.json', j)
    write(d / 'water.json', dict(water=water_rows(SOURCE)))
    # Paving, dock rails and wave crests are low ground details. Do not turn
    # their long north/south runs into building walls or standing water sheets.
    floor = Image.open(d / 'bottom.png').convert('RGBA')
    floor.alpha_composite(Image.open(d / 'top.png').convert('RGBA'), (j['pad']*16, j['pad']*16))
    floor.save(d / 'hd2d_floor.png')
    Image.new('RGBA', (16, 16)).save(d / 'hd2d_atlas.png')
    write(d / 'hd2d_cards.json', dict(tile=16, cards=[], terrain='flat_harbor', ship_departed=True))
    city_dir = MAPS / 'kanto_east'
    city = json.loads((city_dir / 'map.json').read_text())
    for warp in city['warps']:
        if warp['to'] == 'ssanne_exterior':
            warp['arrival_dir'] = [0, -1]
    write(city_dir / 'map.json', city)
    cards = city_pier(city_dir, city, json.loads((city_dir / 'hd2d_cards.json').read_text()))
    write(city_dir / 'hd2d_cards.json', cards)
    print('Vermilion harbor: empty berth, three town exits, no boarding triggers')


if __name__ == '__main__':
    build()
