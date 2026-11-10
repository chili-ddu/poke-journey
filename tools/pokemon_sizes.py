"""Assign all registered species to eight sizes using cached Pokedex heights.

Does not rewrite stats, moves, native art, or individual save files.
Run again after adding species or editing pokemon_size_rules.json.
"""
import csv
import json
from collections import Counter
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]

def build():
    rules=json.loads((ROOT/'assets/data/pokemon_size_rules.json').read_text())
    species=json.loads((ROOT/'assets/data/species.json').read_text())
    source=ROOT/'third_party/pokeapi/pokemon.csv'
    heights={int(row['id']):int(row['height']) for row in csv.DictReader(source.open()) if row['is_default']=='1'}
    profiles={}
    for sid,data in species.items():
        dex=int(data['dex']);height=heights[dex]
        assert height>0,sid
        tier=next(t for t in rules['tiers'] if t['max_height_dm'] is None or height<=t['max_height_dm'])
        profiles[sid]={'dex':dex,'height_dm':height,'size_tier':tier['id'],'display_span':tier['display_span'],'radius':tier['radius']}
    result={'source':'PokeAPI pokemon.csv, cached in third_party/pokeapi; default forms matched by National Dex number',
            'basis':rules['basis'],'tiers':rules['tiers'],'species':profiles}
    (ROOT/'assets/data/pokemon_sizes.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    print('Eight size tiers:',len(profiles),'species;',dict(sorted(Counter(p['size_tier'] for p in profiles.values()).items())))
    return result

if __name__=='__main__':build()
