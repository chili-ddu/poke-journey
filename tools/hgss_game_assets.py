"""Prepare HGSS Kanto/Johto source geometry for the gameplay renderer.

This is an asset build, not a change to the campaign's geography or save IDs.
"""
import hgss_maps as hg

if __name__ == '__main__':
    headers, _ = hg.headers()
    chosen = [i for i, h in headers.items()
              if h.get('regionNo') in {'MAP_REGION_KANTO', 'MAP_REGION_JOHTO'}
              and h.get('mapType') in {'MAP_TYPE_CITY_TOWN','MAP_TYPE_ROUTE','MAP_TYPE_CAVE','MAP_TYPE_INTERIOR'}
              and h.get('mapsec') != 'MAPSEC_MYSTERY_ZONE'
              and 'UNUSED' not in h['constant']
              and 'WIFI_ROOM' not in h['constant']]
    _, constants = hg.headers()
    for name in ['MAP_NATIONAL_PARK_UNUSED_GATEHOUSE','MAP_GOLDENROD_GAME_CORNER','MAP_CELADON_GAME_CORNER']:
        if constants[name] not in chosen: chosen.append(constants[name])
    hg.prepare(header_ids=chosen, destination=hg.ROOT / 'assets/maps/hgss_game_source')
