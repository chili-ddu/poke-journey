"""Check committed runtime tables against the local FireRed source, not a snapshot."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
source=json.loads((ROOT/'third_party/pokefirered/src/data/wild_encounters.json').read_text())['wild_encounter_groups'][0]
weights=next(f['encounter_rates'] for f in source['fields'] if f['type']=='land_mons')
native={e['map']:e['land_mons'] for e in source['encounters'] if e['base_label'].endswith('FireRed') and 'land_mons' in e}
locations={'kanto_north':{'route3':'MAP_ROUTE3','route4':'MAP_ROUTE4','route5':'MAP_ROUTE5'},'kanto_east':{'route6':'MAP_ROUTE6'},'mt_moon_1f':{'mt_moon_1f':'MAP_MT_MOON_1F'},'mt_moon_b1f':{'mt_moon_b1f':'MAP_MT_MOON_B1F'},'mt_moon_b2f':{'mt_moon_b2f':'MAP_MT_MOON_B2F'}}
lines=(ROOT/'scripts/data/kanto_expansion.gd').read_text().splitlines()
for place,areas in locations.items():
 line=next(line for line in lines if line.startswith('\t"'+place+'": {"name":'))
 runtime=json.loads(line.split(':',1)[1].rstrip(','))
 for area,map_id in areas.items():
  actual=runtime['areas'][area]; original=native[map_id]
  assert actual['encounter_rate']==original['encounter_rate'],area
  assert len(actual['encounters'])==len(weights)==12,area
  for row,mon,weight in zip(actual['encounters'],original['mons'],weights,strict=True):
   assert row==[mon['species'].removeprefix('SPECIES_').lower(),mon['min_level'],weight],(area,row)
   assert mon['min_level']==mon['max_level'],area
  print(area+': native slots/levels/weights/rate verified')
 for city in ['cerulean_city','vermilion_city']:
  if city in runtime.get('areas',{}): assert not runtime['areas'][city].get('encounters'),city
scope=['MAP_ROUTE1','MAP_ROUTE2','MAP_VIRIDIAN_FOREST']+[m for areas in locations.values() for m in areas.values()]
species={m['species'] for key in scope for m in native[key]['mons']}
assert len(species)==19,len(species)
print('Verified 7 new tables; 19 terrestrial species across 10 encounter areas through Vermilion.')
