"""Validate native mainland doors and terrain reachability without story scripts."""
import collections
import json
from pathlib import Path
import kanto_world as k

ROOT=k.ROOT
SCRIPTED_ROOMS={
    'celadon_city_department_store_elevator','rocket_hideout_elevator','silph_co_elevator',
    'pokemon_mansion_b1f','pokemon_league_brunos_room','pokemon_league_agathas_room',
    'pokemon_league_lances_room','pokemon_league_champions_room','pokemon_league_hall_of_fame',
}

def run():
    native=json.loads((ROOT/'assets/data/kanto_world_manifest.json').read_text())
    source=(ROOT/'scripts/data/kanto_world.gd').read_text()
    added=json.loads(source.split('const WARP_MAPS := ',1)[1].split('\nconst DUNGEONS',1)[0])
    registry=k.legacy_registry()|added
    maps={name:k.read(name) for name in sorted(set(registry.values()))}
    doors={name:{(w['map'],int(w['index'])):w for w in j['warps']} for name,j in maps.items()}
    unknown=[];dynamic=[];links=0;bad=[]
    for name,j in maps.items():
        for w in j['warps']:
            target=registry.get(w['to'])
            if target is None:
                (dynamic if w['to'] in ['dynamic','undefined','none'] else unknown).append(dict(map=name,warp=w))
                continue
            key=(w['to'],int(w['to_warp']))
            if key not in doors[target]:bad.append((name,w,target))
            else:links+=1
    assert not bad,('Broken registered native destination',bad)
    assert not unknown,('Unregistered native destination',unknown)
    solid={}
    for name,j in maps.items():
        cells={(x,y) for y,row in enumerate(j['solid']) for x,c in enumerate(row) if c=='1'}
        patch=ROOT/'assets/maps'/name/'collision_patch.json'
        if patch.exists():
            cfg=json.loads(patch.read_text());cells.difference_update(map(tuple,cfg.get('open',[])));cells.update(map(tuple,cfg.get('block',[])))
        for warp in j['warps']:
            if warp['to'] not in registry:cells.add((warp['x'],warp['y']))
        solid[name]=cells
    water={}
    for name,j in maps.items():
        path=ROOT/'assets/maps'/name/'water.json'
        water[name]={ (x,y) for y,row in enumerate(json.loads(path.read_text()).get('water',[])) for x,c in enumerate(row) if c=='1'} if path.exists() else set()
    start=('kanto_world',71,270)
    seen={start};queue=collections.deque([start]);warpat={name:{(w['x'],w['y']):w for w in j['warps']} for name,j in maps.items()}
    while queue:
        name,x,y=queue.popleft();j=maps[name]
        nexts=[(name,x+dx,y+dy) for dx,dy in [(1,0),(-1,0),(0,1),(0,-1)]]
        warp=warpat[name].get((x,y))
        if warp and warp['to'] in registry:
            target=registry[warp['to']];other=doors[target].get((warp['to'],int(warp['to_warp'])))
            if other:nexts.append((target,other['x'],other['y']))
        for point in nexts:
            target,xx,yy=point;data=maps[target]
            if point in seen or not(0<=xx<data['width'] and 0<=yy<data['height']):continue
            if (xx,yy) in solid[target] and (xx,yy) not in water[target] and data['ledge'][yy][xx]=='0':continue
            seen.add(point);queue.append(point)
    reached_areas=[];missing_areas=[]
    for area in maps['kanto_world']['areas']:
        reached=any(('kanto_world',x,y) in seen for y in range(area['y'],area['y']+area['h']) for x in range(area['x'],area['x']+area['w']))
        (reached_areas if reached else missing_areas).append(area['id'])
    assert not missing_areas,('Unreachable outdoor area with land/surf/doors',missing_areas)
    missing_maps=[name for name in maps if not any(p[0]==name for p in seen)]
    assert set(missing_maps)<=SCRIPTED_ROOMS,('Unexpected terrain-disconnected room',set(missing_maps)-SCRIPTED_ROOMS)
    report=dict(outdoor_areas=len(reached_areas),registered_maps=len(maps),validated_door_links=links,
                reached_terrain_cells=len(seen),unreachable_maps=missing_maps,dynamic_script_warps=dynamic,
                unregistered_warps=unknown,terrain_only=True,
                note='Land, Surf and native jump ledges; original event/strength/switch puzzles are not simulated.')
    out=ROOT/'docs/kanto_world';out.mkdir(exist_ok=True)
    (out/'connections.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    print('Kanto world:',len(reached_areas),'outdoor areas;',len(maps),'registered maps;',links,'native door links; missing rooms:',missing_maps)
    print('Dynamic scripted exits:',len(dynamic),'unregistered native exits:',len(unknown))
    return report

if __name__=='__main__':run()
