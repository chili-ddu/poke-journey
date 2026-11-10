"""Verify runtime tables and terrain against native source (including water rocks)."""
import json,struct
from pathlib import Path
import frlg_map as fm
ROOT=fm.ROOT
source=json.loads((fm.TP/'src/data/wild_encounters.json').read_text())['wild_encounter_groups'][0]
fields={f['type']:f for f in source['fields']}
text=(ROOT/'scripts/data/kanto_water_data.gd').read_text()
tables=json.loads(text.split('const TABLES := ',1)[1])
for area,cfg in tables.items():
 original=next(e for e in source['encounters'] if e['map']=='MAP_'+area.upper() and e['base_label'].endswith('FireRed'))
 for kind in ['water_mons','fishing_mons']:
  field=fields[kind];mons=original[kind]['mons']
  sets=field['groups'] if kind=='fishing_mons' else {'water':list(range(5))}
  for name,indices in sets.items():
   actual=cfg['fishing'][name] if kind=='fishing_mons' else cfg['water_encounters']
   assert sum(row[2] for row in actual)==100
   assert len(actual)==len(indices)
   for row,index in zip(actual,indices,strict=True):
    m=mons[index]
    assert row==[m['species'].removeprefix('SPECIES_').lower(),m['min_level'],field['encounter_rates'][index],m['max_level']],(area,name,row)
  assert cfg['fishing_encounter_rate' if kind=='fishing_mons' else 'water_encounter_rate']==original[kind]['encounter_rate']
 print(area+': all rods, water slots, weights and level ranges verified')
folders={fm.snake(p.name):p.name for p in (fm.TP/'data/maps').iterdir() if p.is_dir()}
blocked_water=0
for region in ['kanto_south','kanto_north','kanto_east']:
 j=json.loads((ROOT/'assets/maps'/region/'map.json').read_text())
 mask=json.loads((ROOT/'assets/maps'/region/'water.json').read_text())['water']
 assert len(mask)==j['height'] and all(len(row)==j['width'] for row in mask)
 for area in j['areas']:
  if area['id'] not in tables:continue
  lay=fm.layout_of(fm.map_json(folders[area['id']])['layout']);attrs={}
  for base,d in [(0,fm.tileset_dir(lay['primary_tileset'])),(640,fm.tileset_dir(lay['secondary_tileset']))]:
   raw=fm.fetch(d+'/metatile_attributes.bin').read_bytes()
   attrs.update({base+i:struct.unpack_from('<I',raw,i*4)[0]&511 for i in range(len(raw)//4)})
  w,h=lay['width'],lay['height'];blocks=struct.unpack(f'<{w*h}H',fm.fetch(lay['blockdata_filepath']).read_bytes())
  for y in range(h):
   for x in range(w):
    gx,gy=area['x']+x,area['y']+y;b=blocks[y*w+x]
    native_water=attrs.get(b&1023) in {0x10,0x11,0x12,0x15}
    collision=(b>>10)&3
    expected=native_water and collision==0 and 0<gx<j['width']-1 and 0<gy<j['height']-1
    assert (mask[gy][gx]=='1')==expected,(region,gx,gy)
    if native_water and collision!=0:blocked_water+=1
print(f'Native water masks verified; {blocked_water} blocked water/rock tiles remain impassable.')
