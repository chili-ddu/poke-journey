"""Compose the existing Johto library with original HGSS border maps.

No art generation or changes to the source collections. Existing GLTF paths
are reused. Gameplay overrides only join HGSS's reception gate to FRLG roads.
"""
import copy
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
BASE = ROOT / 'assets/maps/johto_hgss'
SOURCE = ROOT / 'assets/maps/hgss_game_source'
OUT = ROOT / 'assets/maps/johto_border_hgss'
HEADERS = [30, 31, 32, 126, 296, 297, 298, 299, 322, 510]
NAMES = {126: '동성폭포', 298: '동성폭포 안쪽 방', 299: '리그 접수 게이트',
         296: '26번도로 북쪽 민가', 297: '26번도로 요일남매의 집',
         322: '27번도로 민가', 510: '28번도로 민가'}


def read(path):
    return json.loads(path.read_text())


def uri(path):
    return 'res://' + str(path.relative_to(ROOT))


def write(path, obj):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(obj, ensure_ascii=False, separators=(',', ':'))+'\n')


def build():
    base, source = read(BASE/'manifest.json'), read(SOURCE/'manifest.json')
    manifest = copy.deepcopy(base)
    manifest['scene_paths'] = {sid: uri(BASE/'scenes'/f'{sid}.json') for sid in base['scenes']}
    for h in HEADERS:
        meta = copy.deepcopy(source['headers'][str(h)])
        if h in NAMES: meta['name_ko'] = NAMES[h]
        manifest['headers'][str(h)] = meta
        manifest['header_scene'][str(h)] = source['header_scene'][str(h)]
    chosen = {int(k) for k in manifest['headers']}
    added_scenes = {}
    # Only the new border's outdoor chunks are added. Existing Kanto remains FRLG.
    mainland_id = base['header_scene']['60']
    mainland = read(BASE/'scenes'/f'{mainland_id}.json')
    full = read(SOURCE/'scenes'/f'{mainland_id}.json')
    for field in ['chunks', 'areas', 'warps']:
        mainland[field].extend(copy.deepcopy([x for x in full[field] if int(x['header']) in [30,31,32]]))
    mainland['headers'].extend([30,31,32])
    added_scenes[mainland_id] = mainland
    for h in HEADERS:
        sid = source['header_scene'][str(h)]
        if sid == mainland_id: continue
        added_scenes[sid] = read(SOURCE/'scenes'/f'{sid}.json')
    # The native junction's north/east doors use the existing FRLG approaches.
    gate = added_scenes[source['header_scene']['299']]
    for warp in gate['warps']:
        if warp['index'] == 1: warp.update(game_to='route23', game_to_warp=2)
        if warp['index'] == 2: warp.update(game_to='route22', game_to_warp=0)
    # Map-connection phase: keep surfing required, but make the two original
    # waterfall strips traversable until the proper Waterfall event is authored.
    falls = added_scenes[source['header_scene']['126']]
    falls['cull_back_faces'] = True
    falls['permission_patches'] = []
    for chunk in falls['chunks']:
        for i, value in enumerate(chunk['attributes']):
            if value & 255 == 19 and value & 32768:
                chunk['attributes'][i] = value & ~32768
                falls['permission_patches'].append({'x':chunk['x']*32+i%32, 'z':chunk['z']*32+i//32,
                    'original':value, 'value':value & ~32768, 'reason':'map-stage surf passage; Waterfall event pending'})
    used_assets = set()
    for sid, scene in added_scenes.items():
        for warp in scene['warps']:
            warp['to'] = ('kanto_world' if warp.get('game_to') else
                          manifest['header_scene'].get(str(warp['to_header']), ''))
        for chunk in scene['chunks']:
            used_assets.add(chunk['asset'])
            used_assets.update(p['asset'] for p in chunk['props'])
        path = OUT/'scenes'/f'{sid}.json'
        write(path, scene)
        manifest['scene_paths'][sid] = uri(path)
        if sid not in manifest['scenes']: manifest['scenes'].append(sid)
    for key in used_assets:
        if key not in manifest['assets']: manifest['assets'][key] = source['assets'][key]
    manifest.update(composition={'base':uri(BASE/'manifest.json'), 'border_source':uri(SOURCE/'manifest.json'),
                                 'added_headers':HEADERS, 'gate_links':'FRLG route22:0 and route23:2'})
    write(OUT/'manifest.json', manifest)
    (OUT/'.gdignore').write_text('')
    summary = {'headers':len(manifest['headers']), 'scenes':len(manifest['scenes']),
               'added_headers':HEADERS, 'mainland_chunks':len(mainland['chunks']),
               'new_models':len(set(manifest['assets'])-set(base['assets'])), 'art_source':'existing',
               'assets_copied':0}
    write(OUT/'build.json', summary)
    print(json.dumps(summary))


if __name__ == '__main__': build()
