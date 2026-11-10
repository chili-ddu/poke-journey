"""Source, GLB/image integrity, native permissions and portal audit for HGSS."""
import hashlib
import json
import struct
from collections import Counter, deque
from pathlib import Path
import hgss_maps as hg


def main():
    manifest = json.loads((hg.OUT / 'manifest.json').read_text())
    scenes = {sid: json.loads((hg.OUT / 'scenes' / (sid + '.json')).read_text()) for sid in manifest['scenes']}
    source = hg.archive('a/0/6/5')
    errors, warnings, boundaries, variants = [], [], [], []
    warps = [w for scene in scenes.values() for w in scene['warps']]
    source_tiles = 0
    for sid, scene in scenes.items():
        cells = {(c['x'], c['z']) for c in scene['chunks']}
        assert len(cells) == len(scene['chunks']), sid
        positions = Counter((w['x'], w['z']) for w in scene['warps'])
        for tile, count in positions.items():
            if count > 1:
                variants.append(dict(scene=sid, tile=tile, entries=[w['index'] for w in scene['warps'] if (w['x'], w['z']) == tile],
                                     policy='first in-scope native variant; other rooms available through selector'))
        for chunk in scene['chunks']:
            raw = source[chunk['land']]
            # Independently decode the runtime's variable preamble, rather
            # than using the exporter's permission parser as its own oracle.
            prefix = 20 + struct.unpack_from('<H', raw, 18)[0]
            permissions = list(struct.unpack_from('<1024H', raw, prefix))
            expected = hg.land(raw)
            assert chunk['attributes'] == permissions, (sid, chunk['land'])
            assert len(chunk['attributes']) == 1024
            assert len(chunk['props']) == len(expected['props'])
            source_tiles += 1024
        for warp in scene['warps']:
            assert (warp['x'] // 32, warp['z'] // 32) in cells, (sid, warp)
            if not warp['to']:
                boundaries.append(dict(scene=sid, header=warp['header'], index=warp['index'], target=warp['source']['header'],
                                       reason='dynamic return' if warp['source']['header'] == 4095 else 'outside Johto map scope'))
                continue
            target = next((w for w in scenes[warp['to']]['warps'] if w['header'] == warp['to_header'] and w['index'] == warp['to_index']), None)
            if not target: errors.append(dict(id='missing_portal_target', warp=warp))
    for key, resource in manifest['assets'].items():
        path = hg.ROOT / resource.removeprefix('res://')
        raw = path.read_bytes()
        assert raw[:4] == b'glTF' and len(raw) == struct.unpack_from('<I', raw, 8)[0], path
        doc = json.loads(raw[20:20 + struct.unpack_from('<I', raw, 12)[0]])
        for image in doc.get('images', []):
            if 'uri' in image: assert (path.parent / image['uri']).is_file(), (path, image)
        log = path.parent / 'conversion.log'
        for line in log.read_text().splitlines():
            if '[WARN]' in line or '[ERROR]' in line:
                warnings.append(dict(id='apicula_conversion', asset=key, value=line, threshold='exact material conversion', file=str(log.relative_to(hg.ROOT))))
    names = {h['constant'] for h in manifest['headers'].values()}
    assert all(f'MAP_ROUTE_{r}' in names for r in range(29, 49))
    required = ['NEW_BARK', 'CHERRYGROVE', 'VIOLET', 'AZALEA', 'GOLDENROD', 'ECRUTEAK', 'OLIVINE', 'CIANWOOD', 'MAHOGANY', 'BLACKTHORN']
    assert all('MAP_' + name in names for name in required)
    # Terrain-level connectivity: original special puzzle geometry is retained.
    # Inspect each native component, connect only actual portals, and report gaps.
    component_at = {}
    component_counts = {}
    for sid, scene in scenes.items():
        opened = set()
        for chunk in scene['chunks']:
            for i, value in enumerate(chunk['attributes']):
                if not value & 32768:
                    opened.add((chunk['x'] * 32 + i % 32, chunk['z'] * 32 + i // 32))
        opened.update((w['x'], w['z']) for w in scene['warps'] if w['to'])
        count = 0
        while opened:
            seed = opened.pop()
            count += 1
            pending = [seed]
            while pending:
                x, z = pending.pop()
                component_at[sid, x, z] = count
                for nxt in [(x - 1, z), (x + 1, z), (x, z - 1), (x, z + 1)]:
                    if nxt in opened:
                        opened.remove(nxt)
                        pending.append(nxt)
        component_counts[sid] = count
    report = dict(status='PASS_WITH_LIMITATIONS' if not errors else 'FAIL',
                  locations=len(manifest['headers']), scene_layouts=len(scenes), terrain_chunks=sum(len(s['chunks']) for s in scenes.values()),
                  source_permission_tiles=source_tiles, model_assets=len(manifest['assets']),
                  portals=len(warps), resolved_portals=len(warps) - len(boundaries), missing_targets=len(errors),
                  boundaries=boundaries, entrance_variants=variants, warnings=warnings, errors=errors, native_components=component_counts,
                  limitations=['Standalone map explorer; not connected to Kanto gameplay or player saves.',
                               'Original elevators, minigames, gym mechanisms, ice sliding, waterfalls and dynamic Safari rearrangement have no script logic.',
                               'Map selector can inspect rooms unreachable without those scripted mechanisms.',
                               'No NPCs, encounters, battles, original map music or story scripts.',
                               'Water/texture animation is not converted; source terrain permission bit 15 and behavior byte are preserved.'])
    output = hg.ROOT / 'docs/johto_maps/checks.json'
    hg.write(output, report)
    lines = ['# HGSS conversion warnings', '', 'These are converter limitations, not passed exact-render checks.', '']
    for warning in warnings:
        lines.append(f"- `{warning['file']}`: `{warning['value']}` (threshold: {warning['threshold']})")
    (output.parent / 'conversion-warnings.md').write_text('\n'.join(lines) + '\n')
    print(json.dumps({k: report[k] for k in ['status','locations','scene_layouts','terrain_chunks','source_permission_tiles','model_assets','portals','resolved_portals','missing_targets']}))
    print('converter warnings:', len(warnings), 'files:', len({w['file'] for w in warnings}))
    if errors: raise SystemExit(1)


if __name__ == '__main__': main()
