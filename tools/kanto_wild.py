"""FireRed native land slots; map coordinates/art remain untouched."""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
SOURCE=ROOT/'third_party/pokefirered/src/data/wild_encounters.json'
def land_tables():
 group=json.loads(SOURCE.read_text())['wild_encounter_groups'][0]
 weights=next(f['encounter_rates'] for f in group['fields'] if f['type']=='land_mons')
 tables={}
 for e in group['encounters']:
  if not e['base_label'].endswith('FireRed') or 'land_mons' not in e: continue
  land=e['land_mons']; slots=[]
  for mon,w in zip(land['mons'],weights,strict=True):
   assert mon['min_level']==mon['max_level'], 'Range support required'
   slots.append([mon['species'].removeprefix('SPECIES_').lower(),mon['min_level'],w])
  tables[e['map']]={'encounter_rate':land['encounter_rate'],'encounters':slots}
 return tables
def area(folder,title):
 import frlg_map as fm
 key='MAP_'+fm.snake(folder).upper().replace('ROUTE_', 'ROUTE')
 cfg={'name':folder,'name_ko':title}
 cfg.update(land_tables().get(key,{}))
 if folder.startswith('MtMoon'): cfg['encounter_terrain']='cave'
 return json.dumps(cfg,ensure_ascii=False)
