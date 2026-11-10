"""Generate the mainland's FireRed encounters without changing map artwork.

Encounter slots, rates and rod groups come from the cached original source.
Static gifts, trades and story/legendary encounters are not random wild slots.
"""
import json
from pathlib import Path
import frlg_map as fm
import kanto_world as world
from kanto_wild import SOURCE

ROOT=fm.ROOT
OUT=ROOT/'assets/data/kanto_world_wild.json'

def tables():
    scope=world.scope()
    folders=scope['outdoor']+scope['dungeons']
    group=json.loads(SOURCE.read_text())['wild_encounter_groups'][0]
    fields={f['type']:f for f in group['fields']}
    native={e['map']:e for e in group['encounters'] if e['base_label'].endswith('FireRed')}
    result={};origins={}
    for folder in folders:
        entry=native.get(fm.map_const(folder))
        if not entry:continue
        cfg=dict(encounters=[],encounter_rate=0,water_encounters=[],water_encounter_rate=0,fishing={},fishing_encounter_rate=0)
        for field,key,rate in [('land_mons','encounters','encounter_rate'),('water_mons','water_encounters','water_encounter_rate'),('fishing_mons','fishing','fishing_encounter_rate'),('rock_smash_mons','rock_smash_encounters','rock_smash_encounter_rate')]:
            data=entry.get(field)
            if not data:continue
            slots=[]
            for mon,weight in zip(data['mons'],fields[field]['encounter_rates'],strict=True):
                row=[mon['species'].removeprefix('SPECIES_').lower(),mon['min_level'],weight]
                if field!='land_mons' or mon['max_level']!=mon['min_level']:row.append(mon['max_level'])
                slots.append(row)
            cfg[key]={rod:[slots[i] for i in indices] for rod,indices in fields[field]['groups'].items()} if field=='fishing_mons' else slots
            cfg[rate]=data['encounter_rate']
        if cfg['encounters'] and folder not in scope['outdoor'] and folder!='ViridianForest' and not folder.startswith('SafariZone_'):
            cfg['encounter_terrain']='cave'
        key=fm.snake(folder);result[key]=cfg;origins[key]=folder
    return result,origins

def roster(tables):
    result={}
    for area,cfg in tables.items():
        groups={'land':cfg['encounters'],'surf':cfg['water_encounters'],'rock_smash':cfg.get('rock_smash_encounters',[]),**cfg['fishing']}
        for method,entries in groups.items():
            for row in entries:
                species,minimum,weight=row[:3];maximum=row[3] if len(row)>3 else minimum
                record=result.setdefault(species,dict(min_level=100,max_level=0,areas=[],methods=[]))
                record['min_level']=min(minimum,record['min_level']);record['max_level']=max(maximum,record['max_level'])
                if area not in record['areas']:record['areas'].append(area)
                if method not in record['methods']:record['methods'].append(method)
    species=json.loads((ROOT/'assets/data/species.json').read_text())
    return {key:dict(dex=species[key]['dex'],**result[key]) for key in sorted(result,key=lambda name:species[name]['dex'])}

def water_masks(tables,origins):
    from kanto_water import rows
    masks={key:rows(origins[key]) for key,cfg in tables.items() if cfg['water_encounters'] or cfg['fishing']}
    changed=[]
    for source in sorted((ROOT/'assets/maps').glob('*/map.json')):
        j=json.loads(source.read_text());water_path=source.with_name('water.json')
        selected=[area for area in j.get('areas',[]) if area['id'] in masks]
        if not selected:continue
        old=json.loads(water_path.read_text()) if water_path.exists() else {}
        grid=[list(row) for row in old.get('water',['0'*j['width'] for _ in range(j['height'])])]
        for area in selected:
            native=masks[area['id']]
            assert (len(native),len(native[0]))==(area['h'],area['w'])
            for y,row in enumerate(native):
                for x,value in enumerate(row):grid[area['y']+y][area['x']+x]=value
        updated={'water':[''.join(row) for row in grid]}
        if updated!=old:
            water_path.write_text(json.dumps(updated,separators=(',',':'))+'\n');changed.append(source.parent.name)
    print('Native water masks updated:',changed)

def main():
    generated,origins=tables();species=roster(generated)
    OUT.write_text(json.dumps(dict(version='FireRed',source='pret/pokefirered/src/data/wild_encounters.json',tables=generated,origins=origins,species=species),ensure_ascii=False,indent=2)+'\n')
    water_masks(generated,origins)
    print('Mainland wild:',len(generated),'areas,',len(species),'species;',sum(bool(t['encounters']) for t in generated.values()),'land,',sum(bool(t['water_encounters']) for t in generated.values()),'surf,',sum(bool(t['fishing']) for t in generated.values()),'fishing tables')

if __name__=='__main__':main()
