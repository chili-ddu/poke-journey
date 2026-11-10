"""Fit original HGSS exterior models to FRLG's existing door/solid footprints.

Preserve campaign geography, collision, warp IDs, event positions and saves.
New render resources live separately; never overwrite original map assets.
"""
import collections
import json
import math
import re
import struct
from pathlib import Path
from PIL import Image
import hgss_maps as hg

OUT = hg.ROOT / 'assets/maps/hgss_render'
SOURCE = hg.ROOT / 'assets/maps/hgss_game_source'


def bounds(path):
    raw = path.read_bytes()
    doc = json.loads(raw[20:20 + struct.unpack_from('<I', raw, 12)[0]])
    indices = {p['attributes']['POSITION'] for mesh in doc['meshes'] for p in mesh['primitives']}
    accessors = [doc['accessors'][i] for i in indices]
    return [[min(a['min'][axis] for a in accessors) / 16 for axis in range(3)],
            [max(a['max'][axis] for a in accessors) / 16 for axis in range(3)]]


def canon(name):
    s = name.lower().removeprefix('map_')
    s = s.replace('pokemon_center', 'pokecenter').replace('_city_', '_').replace('_town_', '_')
    s = s.replace('professor_oaks_lab', 'oaks_lab').replace('reds_house', 'players_house').replace('blues_house', 'rivals_house')
    s = s.replace('_museum_of_science', '_museum').removesuffix('_1f')
    return s


def category(name):
    s = name.lower()
    if 'lab' in s: return 'oaks_lab'
    for key in ['oaks_lab','pokecenter','pokemon_center','mart','gym','museum','department_store','game_corner','gate','house']:
        if key in s: return 'pokecenter' if key == 'pokemon_center' else key
    return 'house'


def templates(manifest):
    bbox = {key: bounds(hg.ROOT / path.removeprefix('res://')) for key, path in manifest['assets'].items() if key.startswith('prop_field_')}
    result = {}
    for sid in manifest['scenes']:
        scene = json.loads((SOURCE / 'scenes' / (sid + '.json')).read_text())
        if scene['matrix'] != 0: continue
        for warp in scene['warps']:
            target = manifest['headers'].get(str(warp['to_header']), {})
            if target.get('mapType') != 'MAP_TYPE_INTERIOR': continue
            door = [warp['x'] + .5, warp['z'] + .5]
            choices = []
            for chunk in scene['chunks']:
                if abs(chunk['x'] * 32 + 16 - door[0]) > 48 or abs(chunk['z'] * 32 + 16 - door[1]) > 48: continue
                for prop in chunk['props']:
                    bb = bbox[prop['asset']]
                    size = [bb[1][i] - bb[0][i] for i in range(3)]
                    if size[0] < 2.4 or size[1] < 1.5 or size[2] < 1.2: continue
                    trans = [chunk['x'] * 32 + 16 + prop['translation'][0] / 16,
                             chunk['altitude'] + prop['translation'][1] / 16,
                             chunk['z'] * 32 + 16 + prop['translation'][2] / 16]
                    local = [door[0] - trans[0], door[1] - trans[2]]
                    dx = max(bb[0][0] - local[0], 0, local[0] - bb[1][0])
                    dz = abs(local[1] - bb[1][2])
                    if dx > .8 or dz > 2: continue
                    choices.append((dx * 4 + dz, prop, bb, local))
            if not choices: continue
            _, prop, bb, local = min(choices, key=lambda c: c[0])
            key = canon(target['constant'])
            result.setdefault(key, dict(asset=manifest['assets'][prop['asset']], bounds=bb,
                                        door=local, category=category(key), source=target['constant']))
    return result


def fit(template, rectangle, door):
    x0, z0, x1, z1 = rectangle
    lo, hi = template['bounds']
    dx, dz = template['door']
    target = [door['x'] + .5, door['y'] + .5]
    # Fit the complete solid shell inside the old solid envelope, while the
    # native doorway remains exactly at the gameplay warp cell.
    ratios_x = [(target[0] - x0) / max(.001, dx - lo[0]), (x1 - target[0]) / max(.001, hi[0] - dx)]
    ratios_z = [(target[1] - z0) / max(.001, dz - lo[2]), (z1 - target[1]) / max(.001, hi[2] - dz)]
    sx = min(r for r in ratios_x if r > 0)
    sz = min(r for r in ratios_z if r > 0)
    # Width governs height so tall landmarks retain their native silhouette.
    sy = sx
    return dict(asset=template['asset'], source=template['source'], scale=[sx, sy, sz],
                position=[target[0] - dx * sx, -lo[1] * sy, target[1] - dz * sz],
                door=target, envelope=rectangle, bounds=template['bounds'])


def building_groups(cards):
    rows = collections.defaultdict(list)
    for index, c in enumerate(cards):
        if len(c) > 9 and c[9] in [1, 2]: continue
        if c[2] < 4 or c[5] <= 0: continue
        front = c[1] + c[2] - (c[8] if len(c) > 8 else 0)
        rows[front].append((c[0], index, c))
    for front, row in rows.items():
        group = []
        for item in sorted(row):
            if group and item[0] > group[-1][0] + 1:
                if len(group) >= 3: yield front, group
                group = []
            group.append(item)
        if len(group) >= 3: yield front, group


def replacement_map(name, directory, catalog, registry):
    meta = json.loads((directory / 'hd2d_cards.json').read_text())
    nav = json.loads((directory / 'map.json').read_text())
    replacements, skip_cards, skip_houses = [], [], []
    for front, group in building_groups(meta['cards']):
        x0, x1 = group[0][0], group[-1][0] + 1
        depth = max(c[2][5] for c in group)
        rect = [x0, front - depth, x1, front]
        door = next((w for w in nav['warps'] if x0 <= w['x'] < x1 and abs(w['y'] + 1 - front) <= 1), None)
        if not door: continue
        target = registry['warps'].get(door['to'], '')
        cfg = registry['maps'].get(target, {})
        if not cfg.get('indoor'): continue
        key = canon(door['to'])
        template = catalog.get(key)
        if 'pokemon_tower' in key:
            template = catalog.get('lavender_radio_station', template)
        if template is None:
            kind = category(key)
            town = key.split('_')[0]
            template = next((v for k,v in catalog.items() if v['category'] == kind and k.startswith(town+'_')),None)
            if template is None: template = next((v for v in catalog.values() if v['category'] == kind), None)
        if template is None: continue
        replacements.append(fit(template, rect, door))
        skip_cards += [item[1] for item in group]
    for index, house in enumerate(meta.get('houses', [])):
        rect = [house['x'], house['z'] - house['d'], house['x'] + house['w'], house['z']]
        door = next((w for w in nav['warps'] if rect[0] <= w['x'] < rect[2] and abs(w['y'] + 1 - house['z']) <= 1), None)
        if not door: continue
        template = catalog.get(canon(door['to'])) or next((v for v in catalog.values() if v['category'] == 'house'), None)
        if not template: continue
        replacements.append(fit(template, rect, door))
        skip_houses.append(index)
    return dict(map=name, buildings=replacements, skip_cards=skip_cards, skip_houses=skip_houses)


def main():
    manifest = json.loads((SOURCE / 'manifest.json').read_text())
    registry = json.loads((hg.ROOT / 'docs/visual_style_review/legacy_registry.json').read_text())
    catalog = templates(manifest)
    OUT.mkdir(parents=True, exist_ok=True)
    reports = []
    paths = {}
    for place, cfg in registry['maps'].items():
        directory = hg.ROOT / cfg['map'].removeprefix('res://')
        if cfg['indoor'] or cfg['arena'] or not (directory / 'hd2d_cards.json').exists(): continue
        if directory.name in paths: continue
        data = replacement_map(directory.name, directory, catalog, registry)
        if not data['buildings']: continue
        path = OUT / directory.name / 'replacements.json'
        hg.write(path, data)
        paths[directory.name] = 'res://' + str(path.relative_to(hg.ROOT))
        reports.append(dict(map=directory.name, buildings=len(data['buildings'])))
    previous = json.loads((OUT/'manifest.json').read_text()) if (OUT/'manifest.json').exists() else {}
    hg.write(OUT / 'manifest.json', dict(art_source='existing', maps=paths, catalog=catalog, summary=reports,terrain=previous.get('terrain',{})))
    print(json.dumps(dict(native_building_templates=len(catalog), maps=len(paths), buildings=sum(r['buildings'] for r in reports))))


if __name__ == '__main__': main()
