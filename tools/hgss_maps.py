"""Extract original HGSS terrain, props, permissions, matrices and portals.

Art source: existing pret/pokeheartgold assets, converted with scurest/apicula.
This prepares an isolated map explorer; it never changes Kanto or save files.
"""
import argparse
import concurrent.futures
import json
import re
import shutil
import struct
import subprocess
from collections import Counter, deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SOURCE = ROOT / 'third_party/pokeheartgold'
OUT = ROOT / 'assets/maps/johto_hgss'
CACHE = SOURCE / 'converted_inputs'
APICULA = ROOT / 'third_party/apicula/target/release/apicula'
KO = {
    'NEW_BARK': '연두마을', 'CHERRYGROVE': '무궁시티', 'VIOLET': '도라지시티',
    'AZALEA': '고동마을', 'CIANWOOD': '진청시티', 'GOLDENROD': '금빛시티',
    'OLIVINE': '담청시티', 'ECRUTEAK': '인주시티', 'MAHOGANY': '황토마을',
    'BLACKTHORN': '검은먹시티', 'LAKE_OF_RAGE': '분노의호수', 'MOUNT_SILVER': '은빛산',
    'SPROUT_TOWER': '모다피탑', 'BELL_TOWER': '방울탑', 'BURNED_TOWER': '불탄탑',
    'UNION_CAVE': '연결동굴', 'ILEX_FOREST': '너도밤나무숲', 'NATIONAL_PARK': '자연공원',
    'SLOWPOKE_WELL': '야돈우물', 'MOUNT_MORTAR': '절구산', 'ICE_PATH': '얼음샛길',
    'WHIRL_ISLANDS': '소용돌이섬', 'DARK_CAVE': '어둠의동굴', 'DRAGONS_DEN': '용의굴',
    'RUINS_OF_ALPH': '알프의유적', 'POKEATHLON_DOME': '포켓슬론돔',
    'SAFARI_ZONE': '사파리존', 'BATTLE_FRONTIER': '배틀프런티어',
}


def korean_name(constant):
    name = constant.removeprefix('MAP_')
    for prefix in sorted(KO, key=len, reverse=True):
        if name == prefix or name.startswith(prefix + '_'):
            tail = name[len(prefix):].strip('_')
            return KO[prefix] + (' · ' + tail.replace('_', ' ') if tail else '')
    match = re.match(r'ROUTE_(\d+)(.*)', name)
    if match:
        return match[1] + '번도로' + match[2].replace('_', ' ')
    return name.replace('_', ' ')


def narc(data):
    """Read raw NARC members; terrain headers can resemble LZ10 signatures."""
    assert data[:4] == b'NARC'
    offset = 16
    entries = []
    while offset < len(data):
        tag = data[offset:offset + 4]
        size = struct.unpack_from('<I', data, offset + 4)[0]
        if tag == b'BTAF':
            count = struct.unpack_from('<H', data, offset + 8)[0]
            entries = [struct.unpack_from('<II', data, offset + 12 + i * 8) for i in range(count)]
        if tag == b'GMIF':
            return [data[offset + 8 + a:offset + 8 + b] for a, b in entries]
        offset += size
    raise ValueError('NARC has no GMIF')


def archive(name):
    return narc((SOURCE / 'files' / name).read_bytes())


def write(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, separators=(',', ':')) + '\n')


def headers():
    constants = {k: int(v) for k, v in re.findall(r'#define (MAP_\w+)\s+(\d+)', (SOURCE / 'include/constants/maps.h').read_text())}
    result = {}
    text = (SOURCE / 'src/data/map_headers.h').read_text()
    for name, body in re.findall(r'\[(MAP_\w+)\]\s*=\s*\{(.*?)\}', text, re.S):
        fields = dict(re.findall(r'\.(\w+)\s*=\s*([^,\n]+)', body))
        fields = {k: v.strip() for k, v in fields.items()}
        if name not in constants:
            continue
        result[constants[name]] = dict(fields, constant=name, id=constants[name])
    return result, constants


def matrix(index, default_header=0):
    path = next((SOURCE / 'files/fielddata/mapmatrix/map_matrix').glob(f'map_matrix_{index:04d}_*'))
    data = path.read_bytes()
    w, h, has_headers, has_altitudes, name_len = data[:5]
    n = w * h
    p = 5 + name_len
    ids = list(struct.unpack_from('<' + 'H' * n, data, p)) if has_headers else [default_header] * n
    p += n * 2 if has_headers else 0
    heights = list(data[p:p + n]) if has_altitudes else [0] * n
    p += n if has_altitudes else 0
    models = list(struct.unpack_from('<' + 'H' * n, data, p))
    assert p + n * 2 == len(data), path
    return dict(width=w, height=h, headers=ids, altitudes=heights, models=models, has_headers=bool(has_headers), source=str(path.relative_to(SOURCE)))


def event_file(header):
    match = re.search(r'zone_event_(\d+)_', header['eventsBank'])
    if not match:
        return {}
    path = next((SOURCE / 'files/fielddata/eventdata/zone_event').glob(match[1] + '_*'))
    return json.loads(path.read_text())


def land(data):
    attr_size, prop_size, model_size, height_size = struct.unpack_from('<4I', data)
    magic, extra_size = struct.unpack_from('<HH', data, 16)
    assert magic == 0x1234 and attr_size == 2048
    props_start = 20 + extra_size + attr_size
    model_start = props_start + prop_size
    assert data[model_start:model_start + 4] == b'BMD0'
    assert model_start + model_size + height_size == len(data)
    # The runtime loader reads the variable-sized HGSS preamble before the
    # permission block (overlay_01_021F4704: ov01_021F4AAC then 021F4AE4).
    # terrain_attributes.h's fixed 0x14 offset does not account for this block.
    attrs = list(struct.unpack_from('<1024H', data, 20 + extra_size))
    props = []
    for offset in range(props_start, model_start, 48):
        model, *values = struct.unpack_from('<10i', data, offset)
        props.append(dict(model=model, translation=[v / 4096 for v in values[:3]],
                          rotation=[v / 4096 for v in values[3:6]], scale=[v / 4096 for v in values[6:9]]))
    return dict(attributes=attrs, props=props, model=data[model_start:model_start + model_size],
                height_data=data[model_start + model_size:])


def convert_job(job):
    target, inputs = job
    if target.exists() and any(target.glob('*.glb')):
        return str(target), 'cached'
    # Native game adoption can reuse the identical conversion already checked
    # in a sample; copy its texture dependencies together with the GLB.
    for collection in ['johto_hgss', 'hgss_pallet_sample']:
        candidate = ROOT / 'assets/maps' / collection / 'models' / target.name
        if candidate != target and candidate.is_dir() and any(candidate.glob('*.glb')):
            shutil.copytree(candidate, target, dirs_exist_ok=True)
            return str(target), 'reused'
    target.mkdir(parents=True, exist_ok=True)
    proc = subprocess.run([str(APICULA), 'convert', '-f=glb', *map(str, inputs), '-o', str(target), '--overwrite'], capture_output=True, text=True)
    (target / 'conversion.log').write_text(proc.stdout + proc.stderr)
    outputs = list(target.glob('*.glb'))
    if proc.returncode or len(outputs) != 1:
        raise RuntimeError(f'{target}: expected one GLB, found {len(outputs)}: {proc.stderr[-500:]}')
    return str(target), 'converted'


def prepare(sample=False, header_ids=None, destination=OUT):
    OUT = Path(destination)
    OUT.mkdir(parents=True, exist_ok=True)
    CACHE.mkdir(parents=True, exist_ok=True)
    hdrs, consts = headers()
    selected = {i: h for i, h in hdrs.items() if h.get('regionNo') == 'MAP_REGION_JOHTO'
                and h.get('mapsec') not in {'MAPSEC_MYSTERY_ZONE', 'MAPSEC_BATTLE_FRONTIER', 'MAPSEC_SAFARI_ZONE_GATE', 'MAPSEC_SAFARI_ZONE'}
                and h.get('mapType') != 'MAP_TYPE_INVALID' and i > 3}
    # Safari layouts are also maps, even though their dynamic area arrangement is not a story system here.
    selected.update({i: h for i, h in hdrs.items() if h.get('regionNo') == 'MAP_REGION_JOHTO'
                     and h.get('mapsec') in {'MAPSEC_SAFARI_ZONE_GATE', 'MAPSEC_SAFARI_ZONE', 'MAPSEC_BATTLE_FRONTIER'}})
    selected = {i: h for i, h in selected.items() if 'UNUSED' not in h['constant']
                and h['constant'] != 'MAP_POKEMON_LEAGUE_ENTRANCE_WIFI_ROOM'}
    # These native targets are actually referenced by in-scope doors despite
    # the source's legacy name / generic region setting.
    for constant in ['MAP_NATIONAL_PARK_UNUSED_GATEHOUSE', 'MAP_GOLDENROD_GAME_CORNER']:
        hid = consts[constant]
        selected[hid] = hdrs[hid]
    for h in selected.values():
        h['name_ko'] = korean_name(h['constant'])
    if sample:
        selected = {60: hdrs[60]}
    if header_ids is not None:
        selected = {i: dict(hdrs[i], name_ko=korean_name(hdrs[i]['constant'])) for i in header_ids}
    lands = archive('a/0/6/5')
    area_data = archive('a/0/4/2')
    terrain_textures = archive('a/0/4/4')
    prop_textures = archive('a/0/7/0')
    prop_field = archive('fielddata/build_model/bm_field.narc')
    prop_room = archive('fielddata/build_model/bm_room.narc')
    jobs = {}
    scenes = {}
    header_scene = {}
    for hid, h in selected.items():
        mid = int(re.search(r'map_matrix_(\d+)', h['matrixId'])[1])
        m = matrix(mid, hid)
        # Reused room geometry is not a shared physical room: each town's
        # center/mart needs its own portal table and destination identity.
        independent = not m['has_headers'] or hid not in m['headers']
        sid = f'header_{hid:03d}' if independent else f'matrix_{mid:04d}'
        if independent:
            m['headers'] = [hid] * len(m['headers'])
        header_scene[hid] = sid
        if sid not in scenes:
            scenes[sid] = dict(id=sid, matrix=mid, width=m['width'] * 32, height=m['height'] * 32,
                               headers=[], chunks=[], warps=[], areas=[], source=m['source'], matrix_data=m)
        scenes[sid]['headers'].append(hid)
    for sid, scene in scenes.items():
        m = scene.pop('matrix_data')
        for i, model_id in enumerate(m['models']):
            hid = m['headers'][i]
            if model_id == 65535 or hid not in selected:
                continue
            h = selected[hid]
            area_id = int(h['areaDataBank'])
            prop_list, texture_id, _, mode = struct.unpack('<4H', area_data[area_id])
            indoor = mode & 255 == 0
            native = land(lands[model_id])
            x, z = i % m['width'], i // m['width']
            terrain_key = f'terrain_{model_id:04d}_{texture_id:03d}'
            terrain_path = CACHE / (terrain_key + '.nsbmd')
            terrain_path.write_bytes(native['model'])
            texture_path = CACHE / f'terrain_texture_{texture_id:03d}.nsbtx'
            texture_path.write_bytes(terrain_textures[texture_id])
            inputs = [terrain_path, texture_path]
            # Three native models reference a texture outside their area's bank.
            # Supply that original bank explicitly, never fabricate the material.
            supplements = {280: 27, 372: 27, 566: 70}
            if model_id in supplements:
                extra = supplements[model_id]
                extra_path = CACHE / f'terrain_texture_{extra:03d}.nsbtx'
                extra_path.write_bytes(terrain_textures[extra])
                inputs.append(extra_path)
            jobs[terrain_key] = (OUT / 'models' / terrain_key, inputs)
            props = []
            for prop in native['props']:
                model = prop['model']
                key = f'prop_{"room" if indoor else "field"}_{model:03d}_{prop_list:03d}'
                model_path = CACHE / (key + '.nsbmd')
                library = prop_room if indoor else prop_field
                if model >= len(library):
                    raise ValueError(f'prop {model} not in {key}')
                model_path.write_bytes(library[model])
                texture_path = CACHE / f'prop_texture_{prop_list:03d}.nsbtx'
                texture_path.write_bytes(prop_textures[prop_list])
                jobs[key] = (OUT / 'models' / key, [model_path, texture_path])
                props.append(dict(prop, asset=key))
            scene['chunks'].append(dict(x=x, z=z, altitude=m['altitudes'][i], header=hid, land=model_id,
                                        asset=terrain_key, attributes=native['attributes'], props=props))
            scene['areas'].append(dict(header=hid, x=x * 32, z=z * 32, width=32, height=32))
        for hid in scene['headers']:
            for i, warp in enumerate(event_file(selected[hid]).get('warps', [])):
                dest = consts.get(warp['header'], -1)
                scene['warps'].append(dict(x=warp['x'], z=warp['z'], y=warp.get('y', 0), header=hid, index=i,
                                           to_header=dest, to_index=warp['anchor'], to=header_scene.get(dest, ''), source=warp))
        write(OUT / 'scenes' / (sid + '.json'), scene)
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        results = list(pool.map(convert_job, jobs.values()))
    assets = {key: 'res://' + str(next(target.glob('*.glb')).relative_to(ROOT)) for key, (target, _) in jobs.items()}
    manifest = dict(format='hgss_map_collection.v1', art_source='existing', source='pret/pokeheartgold',
                    converter='scurest/apicula', start_header=next(iter(selected)) if header_ids is not None else 60, headers={str(k): v for k, v in selected.items()},
                    header_scene={str(k): v for k, v in header_scene.items()}, scenes=list(scenes), assets=assets)
    write(OUT / 'manifest.json', manifest)
    if not sample:
        # Remove only generated outputs no longer referenced by this collection.
        for directory in (OUT / 'models').iterdir():
            if directory.is_dir() and directory.name not in assets: shutil.rmtree(directory)
        for path in (OUT / 'scenes').glob('*.json'):
            if path.stem not in scenes: path.unlink()
        for resource in assets.values():
            path = ROOT / resource.removeprefix('res://')
            raw = path.read_bytes()
            document = json.loads(raw[20:20 + struct.unpack_from('<I', raw, 12)[0]])
            used = {image['uri'] for image in document.get('images', []) if 'uri' in image}
            for image in path.parent.glob('*.png'):
                if image.name not in used: image.unlink()
    print(json.dumps(dict(headers=len(selected), scenes=len(scenes), chunks=sum(len(s['chunks']) for s in scenes.values()),
                          assets=len(assets), conversions=Counter(status for _, status in results))))


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--sample', action='store_true')
    args = parser.parse_args()
    prepare(args.sample)
