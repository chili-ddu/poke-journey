"""Native mainland Kanto blockout; preserve audited source maps and their saves.

The world is one outdoor field. Saffron's actual city, forests, caves and
facilities retain their real doors; the native Saffron connection layout is
render-only background, not a second traversable city.
"""
import argparse
import concurrent.futures
import copy
import json
import re
import shutil
import subprocess
from collections import deque
from pathlib import Path
from PIL import Image
import frlg_map as fm

ROOT=fm.ROOT
MAPS=ROOT/'assets/maps'
WORLD='kanto_world'
_source_fetch=fm.fetch

def network_fetch(rel):
    path=fm.TP/rel
    if path.exists():return path
    if rel.startswith('data/tilesets/') and (fm.TP/'.full_source_cache').exists():raise FileNotFoundError(rel)
    try:return _source_fetch(rel)
    except Exception:
        path.parent.mkdir(parents=True,exist_ok=True)
        temporary=path.with_suffix(path.suffix+'.download')
        subprocess.run(['curl','--fail','--silent','--show-error','--retry','2','--connect-timeout','10',
                        '--max-time','45','--output',str(temporary),fm.RAW+rel],check=True)
        temporary.replace(path)
        return path
KNOWN_PARTS={'kanto_field':'PalletTown','kanto_east':'VermilionCity',
             'cerulean_north':'Route24','kanto_rock_pass':'Route9','route11':'Route11'}
KO={'PalletTown':'태초마을','ViridianCity':'상록시티','PewterCity':'회색시티',
    'CeruleanCity':'블루시티','LavenderTown':'보라타운','VermilionCity':'갈색시티',
    'CeladonCity':'무지개시티','FuchsiaCity':'연분홍시티','CinnabarIsland':'홍련섬',
    'IndigoPlateau_Exterior':'석영고원','SaffronCity':'노랑시티',
    'SeafoamIslands':'쌍둥이섬','VictoryRoad':'챔피언로드','CeruleanCave':'블루시티 동굴',
    'PokemonMansion':'포켓몬저택','PokemonTower':'포켓몬타워','PowerPlant':'무인발전소',
    'SilphCo':'실프주식회사','RocketHideout':'로켓단 아지트','PokemonLeague':'포켓몬리그',
    'SafariZone':'사파리존','UndergroundPath':'지하통로'}

def read(name,file='map.json'):return json.loads((MAPS/name/file).read_text())
def write(name,data,file='map.json'):(MAPS/name/file).write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')

def title(folder):
    if folder in KO:return KO[folder]
    if re.fullmatch(r'Route\d+',folder):return folder[5:]+'번도로'
    if folder.startswith('Route21_'):return '21번수로 '+('북쪽' if folder.endswith('North') else '남쪽')
    base,suffix=folder.split('_',1) if '_' in folder else (folder,'')
    first=KO.get(base,base[5:]+'번도로' if base.startswith('Route') else base)
    words={'PokemonCenter':'포켓몬센터','Mart':'프렌들리숍','Gym':'체육관','DepartmentStore':'백화점',
           'NorthEntrance':'북쪽 관문','SouthEntrance':'남쪽 관문','EastEntrance':'동쪽 관문',
           'WestEntrance':'서쪽 관문','NorthSouthTunnel':'남북 통로','EastWestTunnel':'동서 통로',
           'Center':'중앙','East':'동쪽','West':'서쪽','North':'북쪽','SecretHouse':'비밀의 집',
           'RestHouse':'휴게소','Entrance':'입구','Roof':'옥상','Elevator':'엘리베이터'}
    tail=[]
    for part in suffix.split('_'):
        if not part:continue
        if re.fullmatch(r'B\d+F',part):tail.append('지하 '+part[1:-1]+'층')
        elif re.fullmatch(r'\d+F',part):tail.append(part[:-1]+'층')
        else:tail.append(words.get(part,part))
    return first+(' '+ ' '.join(tail) if tail else '')

def legacy_registry():
    result={}
    for file,key in [('dungeon_db.gd','BASE_WARP_MAPS'),('kanto_expansion.gd','WARP_MAPS'),
                     ('cerulean_progression.gd','WARP_MAPS'),('rock_pass.gd','WARP_MAPS'),
                     ('saffron_access.gd','WARP_MAPS'),('route11_diglett.gd','WARP_MAPS')]:
        text=(ROOT/'scripts/data'/file).read_text()
        body=text.split('const '+key,1)[1].split('}',1)[0]
        result.update(dict(re.findall(r'"([\w]+)"\s*:\s*"([\w]+)"',body)))
    return result

def scope():
    groups=json.loads(fm.fetch('data/maps/map_groups.json').read_text())
    towns=groups['gMapGroup_TownsAndRoutes']
    outdoor=towns[:towns.index('SaffronCity')]+[f for f in towns if f.startswith('Route')]
    indoor=[]
    for group,folders in groups.items():
        if not group.startswith('gMapGroup_Indoor') or any(s in group for s in ['OneIsland','TwoIsland','ThreeIsland','FourIsland','FiveIsland','SixIsland','SevenIsland']):continue
        indoor += [f for f in folders if 'Unused' not in f and not f.endswith('PokemonCenter_2F')]
    dungeons=[]
    for folder in groups['gMapGroup_Dungeons']:
        if folder.startswith('MtEmber'):break
        if folder.startswith('SSAnne'):continue # The existing ship has already departed.
        dungeons.append(folder)
    all_folders=list(dict.fromkeys(outdoor+indoor+dungeons+['SaffronCity_Connection']))
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:
        infos=dict(zip(all_folders,pool.map(fm.map_json,all_folders)))
    layouts={f:fm.layout_of(info['layout']) for f,info in infos.items()}
    return dict(outdoor=outdoor,indoor=indoor,dungeons=dungeons,infos=infos,layouts=layouts)

def placement(s):
    names=s['outdoor']+['SaffronCity_Connection'];by={fm.map_const(f):f for f in names}
    positions={'PalletTown':(0,0)};queue=deque(positions)
    while queue:
        a=queue.popleft();x,y=positions[a];lay=s['layouts'][a]
        for c in s['infos'][a].get('connections') or []:
            b=by.get(c['map'])
            if b is None or b in positions:continue
            bl=s['layouts'][b];o=int(c['offset'])
            positions[b]={'up':(x+o,y-bl['height']),'down':(x+o,y+lay['height']),
                          'left':(x-bl['width'],y+o),'right':(x+lay['width'],y+o)}[c['direction']]
            queue.append(b)
    assert set(positions)==set(names),set(names)-set(positions)
    minx=min(x for x,y in positions.values());miny=min(y for x,y in positions.values())
    return {f:(x-minx,y-miny) for f,(x,y) in positions.items()}

def plan(s):
    pos=placement(s);parts=[];covered=set();offsets={}
    for name,anchor in KNOWN_PARTS.items():
        j=read(name);area=next(a for a in j['areas'] if a['id']==fm.snake(anchor))
        dx,dy=pos[anchor][0]-area['x'],pos[anchor][1]-area['y']
        for a in j['areas']:
            folder=next(f for f in s['outdoor'] if fm.snake(f)==a['id'])
            assert (dx+a['x'],dy+a['y'])==pos[folder],(name,folder,'native position mismatch')
            covered.add(folder)
        parts.append(dict(map=name,x=dx,y=dy,folders=[f for f in s['outdoor'] if f in covered and any(a['id']==fm.snake(f) for a in j['areas'])]))
        offsets[name]=[dx,dy]
    for f in s['outdoor']+['SaffronCity_Connection']:
        if f in covered:continue
        x,y=pos[f];parts.append(dict(map='world_'+fm.snake(f),x=x,y=y,folders=[f]))
    offsets['kanto_south']=offsets['kanto_field'];offsets['kanto_north']=offsets['kanto_field']
    return dict(parts=parts,legacy_offsets=offsets,positions=pos,
                width=max(pos[f][0]+s['layouts'][f]['width'] for f in pos),
                height=max(pos[f][1]+s['layouts'][f]['height'] for f in pos))

def new_singles(s,registry):
    return [f for f in s['indoor']+s['dungeons'] if fm.snake(f) not in registry
            and not f.startswith('SafariZone_')]

def definitions(s,p):
    from cerulean_progression import dump
    registry=legacy_registry();themes={WORLD:dict(map='res://assets/maps/'+WORLD,tiles={})}
    warps={fm.snake(f):WORLD for f in s['outdoor']}
    areas={fm.snake(f):dict(name=f,name_ko=title(f),encounter_rate=0,encounters=[]) for f in s['outdoor']}
    places={WORLD:dict(name='KANTO',name_ko='관동',theme=WORLD,overworld=True,count=0,encounters=[],areas=areas)}
    music={fm.snake(f):s['infos'][f]['music'].lower() for f in s['outdoor']}
    for folder in new_singles(s,registry):
        name=fm.snake(folder);themes[name]=dict(map='res://assets/maps/'+name,tiles={});warps[name]=name
        cave=folder.startswith(('VictoryRoad','SeafoamIslands','CeruleanCave'))
        dungeon=folder in s['dungeons']
        cfg=dict(name=folder.upper(),name_ko=title(folder),theme=name,count=0,encounters=[])
        cfg['overworld' if dungeon else 'indoor']=True
        if dungeon:cfg.update(areas={name:dict(name=folder,name_ko=title(folder),encounter_rate=0,encounters=[])},battle_style='room')
        if dungeon and not cave:cfg['indoor']=True
        if cave:cfg['areas'][name]['encounter_terrain']='cave'
        if folder.endswith('PokemonCenter_1F'):
            nurse=next((o for o in s['infos'][folder].get('object_events',[]) if o.get('graphics_id')=='OBJ_EVENT_GFX_NURSE'),dict(x=7,y=2))
            x,y=nurse['x'],nurse['y']
            cfg['npcs']=[dict(id='nurse',sprite='nurse',tile=[x,y],face='down',talk='nurse',talk_tile=[x,y+2],heal_spot=[x-1.0,y-.3])]
        elif folder.endswith('_Mart'):
            cfg['npcs']=[dict(id='clerk',sprite='clerk',tile=[2,3],face='right',talk='shop',talk_tile=[4,3])]
        places[name]=cfg;music[name]=s['infos'][folder]['music'].lower()
    safari=[f for f in s['dungeons'] if f in ['SafariZone_Center','SafariZone_East','SafariZone_North','SafariZone_West']]
    # Safari sections use native gate warps rather than map connections.
    # Preserve those original gate coordinates instead of inventing a layout.
    for f in safari:
        name=fm.snake(f);themes[name]=dict(map='res://assets/maps/'+name,tiles={});warps[name]=name
        places[name]=dict(name=f.upper(),name_ko=title(f),theme=name,overworld=True,count=0,encounters=[],
                         areas={name:dict(name=f,name_ko=title(f),encounter_rate=0,encounters=[])})
        music[name]=s['infos'][f]['music'].lower()
    for f in [f for f in s['dungeons'] if f.startswith('SafariZone_') and f not in safari]:
        name=fm.snake(f);themes[name]=dict(map='res://assets/maps/'+name,tiles={});warps[name]=name
        places[name]=dict(name=f.upper(),name_ko=title(f),theme=name,indoor=True,count=0,encounters=[])
        music[name]=s['infos'][f]['music'].lower()
    text='# Generated by tools/kanto_world.py; mainland map layout, without new story battles.\nextends RefCounted\n'
    legacy_warps=dict(registry)
    for id in ['route3','route4','cerulean_city','route5']:legacy_warps[id]='kanto_south'
    for key,value in [('THEMES',themes),('WARP_MAPS',warps),('DUNGEONS',places),('MUSIC',music),('LEGACY_OFFSETS',p['legacy_offsets']),('LEGACY_WARP_MAPS',legacy_warps)]:
        value=dump(value)
        value=re.sub(r'"heal_spot":\s*\[\s*([\d.]+),\s*([\d.]+)\s*\]',r'"heal_spot": Vector2(\1, \2)',value)
        text+='const '+key+' := '+value+'\n'
    (ROOT/'scripts/data/kanto_world.gd').write_text(text)
    (ROOT/'assets/data/kanto_world_manifest.json').write_text(json.dumps(dict(p,scope=s['outdoor'],new_interiors=new_singles(s,registry)),ensure_ascii=False,indent=2)+'\n')
    return safari

def fetch_assets(s,folders):
    paths=set()
    for f in folders:
        lay=s['layouts'][f]
        paths.update([lay['blockdata_filepath'],lay['border_filepath']])
    with concurrent.futures.ThreadPoolExecutor(max_workers=8) as pool:list(pool.map(fm.fetch,sorted(paths)))
    tilesets={v[k] for f,v in s['layouts'].items() if f in folders for k in ['primary_tileset','secondary_tileset']}
    for tileset in sorted(tilesets):
        files=fm.tileset_files(tileset);d=files['metatiles'];primary='/primary/' in d
        paths={files['tiles'],d+'/metatiles.bin',d+'/metatile_attributes.bin'}
        paths.update(files['palettes'][i] for i in (range(7) if primary else range(7,13)))
        with concurrent.futures.ThreadPoolExecutor(max_workers=6) as pool:list(pool.map(fm.fetch,sorted(paths)))
    print('Native assets cached:',len(folders),'maps,',len(tilesets),'tilesets',flush=True)

def bake_sources(s,p,safari,force=False):
    import hd2d_cards
    folders=[part['folders'][0] for part in p['parts'] if part['map'].startswith('world_')]
    folders += new_singles(s,legacy_registry())
    folders += [f for f in s['dungeons'] if f.startswith('SafariZone_') and f not in safari]
    folders += safari
    fetch_assets(s,list(dict.fromkeys(folders+safari)))
    for f in folders:
        name='world_'+fm.snake(f) if f in s['outdoor']+['SaffronCity_Connection'] else fm.snake(f)
        if (MAPS/name/'hd2d_cards.json').exists() and not force:continue
        fm.bake([f],name,None,False);j=read(name)
        if f in s['indoor'] or (f in s['dungeons'] and not f.startswith(('VictoryRoad','SeafoamIslands','CeruleanCave','SafariZone_'))):j['indoor']=True
        j['warps']=[w for w in j['warps'] if not w['to'].endswith('pokemon_center_2f')]
        candidates=[(x,y) for y,row in enumerate(j['solid']) for x,c in enumerate(row)
                    if c=='0' and j['ledge'][y][x]=='0' and not any(w['x']==x and w['y']==y for w in j['warps'])]
        assert candidates,(f,'no spawn')
        center=(j['width']/2,j['height']/2);x,y=min(candidates,key=lambda xy:(xy[0]-center[0])**2+(xy[1]-center[1])**2)
        j['start']=[x*16+8,y*16+8];write(name,j)
        if f in s['outdoor'] or f in s['dungeons']:
            from kanto_water import rows
            write(name,dict(water=rows(f)),'water.json')
        hd2d_cards.build(name)
        print('Built world source',name,flush=True)

def compose(s,p):
    from kanto_seamless import move_object
    from north_terrain import remove_cells
    out=MAPS/WORLD;out.mkdir(exist_ok=True)
    w,h,pad=p['width'],p['height'],10
    names=s['outdoor'];positions=p['positions']
    native={};borders=[];areas=[];owner={}
    for folder in names+['SaffronCity_Connection']:
        x,y=positions[folder];b=fm.bake_layout(s['layouts'][folder]);native[folder]=b
        borders.append((x,y,b['w'],b['h'],b['border']))
        if folder=='SaffronCity_Connection':continue
        areas.append(dict(id=fm.snake(folder),x=x,y=y,w=b['w'],h=b['h']))
        for yy in range(y,y+b['h']):
            for xx in range(x,x+b['w']):
                assert (xx,yy) not in owner,('Overlapping native maps',folder,owner.get((xx,yy)),xx,yy)
                owner[xx,yy]=folder
    bottom=Image.new('RGBA',((w+2*pad)*16,(h+2*pad)*16),(0,0,0,255))
    top=Image.new('RGBA',(w*16,h*16))
    fm.fill_borders(bottom,top,borders,w,h)
    floor=bottom.copy()
    images={'bottom':bottom,'top':top,'hd2d_floor':floor}
    rows={key:[list(default*w) for _ in range(h)] for key,default in [('solid','1'),('grass','0'),('ledge','0'),('water','0')]}
    metadata=dict(tile=16,cards=[],houses=[],props=[],tables=[],log_fences=[],corner_walls=[])
    patches=dict(open=[],block=[]);warps=[];side_surfaces={};seams=set()
    sources=[]
    for part in p['parts']:
        name,dx,dy=part['map'],part['x'],part['y'];j=read(name)
        sources.append((part,j))
        background=part['folders']==['SaffronCity_Connection']
        for a in j['areas']:
            for key,im in images.items():
                sp=0 if key=='top' else j['pad'];tp=0 if key=='top' else pad
                source=Image.open(MAPS/name/(key+'.png')).convert('RGBA')
                crop=source.crop(((a['x']+sp)*16,(a['y']+sp)*16,(a['x']+a['w']+sp)*16,(a['y']+a['h']+sp)*16))
                im.paste(crop,((a['x']+dx+tp)*16,(a['y']+dy+tp)*16))
            if background:continue
            water_path=MAPS/name/'water.json'
            water=read(name,'water.json').get('water',[]) if water_path.exists() else []
            for yy in range(a['h']):
                y=a['y']+yy;gy=y+dy
                for key in rows:
                    source_rows=water if key=='water' else j[key]
                    if source_rows:rows[key][gy][a['x']+dx:a['x']+dx+a['w']]=list(source_rows[y][a['x']:a['x']+a['w']])
        if not background:
            warps.extend(dict(v,x=v['x']+dx,y=v['y']+dy) for v in j['warps'] if not v.get('edge_transition'))
            pf=MAPS/name/'collision_patch.json'
            if pf.exists():
                patch=read(name,'collision_patch.json')
                for key in patches:patches[key].extend([x+dx,y+dy] for x,y in patch.get(key,[]))
    # Only real native neighbors open an edge. Do not create a walk-through
    # city from Saffron's connection-only background or bypass its gates.
    from kanto_water import rows as native_water_rows
    for folder in names:
        x,y=positions[folder];b=native[folder]
        for yy,row in enumerate(native_water_rows(folder)):
            rows['water'][y+yy][x:x+b['w']]=list(row)
        for lx,ly in {(xx,yy) for yy in range(b['h']) for xx in range(b['w']) if xx in (0,b['w']-1) or yy in (0,b['h']-1)}:
            gx,gy=x+lx,y+ly
            adjacent=any(owner.get((gx+u,gy+v)) not in (None,folder) for u,v in [(1,0),(-1,0),(0,1),(0,-1)])
            if not adjacent:continue
            if b['solid'][ly][lx]==0:
                rows['solid'][gy][gx]='0';seams.add((gx,gy))
                tile=b['bottom'].crop((lx*16,ly*16,(lx+1)*16,(ly+1)*16))
                tile.alpha_composite(b['top'].crop((lx*16,ly*16,(lx+1)*16,(ly+1)*16)))
                floor.paste(tile,((gx+pad)*16,(gy+pad)*16))
    patches['block']=[xy for xy in patches['block'] if tuple(xy) not in seams]
    # Pack source atlases as rectangles; a vertical concatenation of the full
    # mainland can exceed the GPU's maximum texture height.
    atlas_positions={};atlas_images={}
    for part,_ in sources:atlas_images[part['map']]=Image.open(MAPS/part['map']/'hd2d_atlas.png').convert('RGBA')
    ax=ay=row_height=0;atlas_width=max(4096,max(im.width for im in atlas_images.values()))
    for name in sorted(atlas_images,key=lambda n:-atlas_images[n].height):
        im=atlas_images[name]
        if ax+im.width>atlas_width:ax=0;ay+=row_height;row_height=0
        atlas_positions[name]=(ax,ay);ax+=im.width;row_height=max(row_height,im.height)
    atlas=Image.new('RGBA',(atlas_width,ay+row_height))
    assert max(atlas.size)<=16384,('Atlas exceeds texture limits',atlas.size)
    for name,im in atlas_images.items():atlas.paste(im,atlas_positions[name])
    for part,j in sources:
        name,dx,dy=part['map'],part['x'],part['y'];prefix=name+'_';au,av=atlas_positions[name]
        c=read(name,'hd2d_cards.json');allowed=set(part['folders']);background='SaffronCity_Connection' in allowed
        for path in (MAPS/name).iterdir():
            if path.suffix in ('.png','.svg') and path.stem not in ['bottom','top','preview','hd2d_atlas','hd2d_floor','elevation_floor']:
                shutil.copyfile(path,out/(prefix+path.name))
        local_seams={(x-dx,y-dy) for x,y in seams if 0<=x-dx<j['width'] and 0<=y-dy<j['height']}
        for card in remove_cells(c['cards'],local_seams):
            root=(int(card[0]+dx),int(card[1]+card[2]-1+dy))
            if not background and owner.get(root) not in allowed:continue
            if background and root in owner:continue
            card=copy.deepcopy(card);card[0]+=dx;card[1]+=dy;card[3]+=au;card[4]+=av
            metadata['cards'].append(card)
        for key in ['houses','props','tables','log_fences']:
            metadata[key]+=move_object(c.get(key,[]),dx,dy,prefix)
        for corner in c.get('corner_walls',[]):
            item=copy.deepcopy(corner)
            for key in ['a','b']:item[key]=[item[key][0]+dx,item[key][1]+dy]
            item['atlas'][0]+=au;item['atlas'][1]+=av
            metadata['corner_walls'].append(item)
        sf=MAPS/name/'hd2d_side_surfaces.json'
        if sf.exists():
            for key,value in read(name,'hd2d_side_surfaces.json').items():
                x,y,face=key.split(':');side_surfaces[f'{int(x)+dx}:{int(y)+dy}:{face}']=dict(value,texture=prefix+value['texture'])
    start=read('kanto_field')['start'];dx,dy=p['legacy_offsets']['kanto_field']
    data=dict(width=w,height=h,tile=16,pad=pad,start=[start[0]+dx*16,start[1]+dy*16],
              areas=areas,warps=warps,source='Audited mainland Kanto; native connections; Saffron through gates',
              native_folders={fm.snake(f):f for f in names},world_parts=p['parts'])
    for key in ['solid','grass','ledge']:data[key]=[''.join(row) for row in rows[key]]
    write(WORLD,data);write(WORLD,metadata,'hd2d_cards.json');write(WORLD,patches,'collision_patch.json')
    write(WORLD,dict(water=[''.join(row) for row in rows['water']]),'water.json');write(WORLD,side_surfaces,'hd2d_side_surfaces.json')
    for key,im in images.items():
        temporary=out/(key+'.png.tmp');im.save(temporary,format='PNG');temporary.replace(out/(key+'.png'))
    atlas.save(out/'hd2d_atlas.png')
    preview=bottom.copy();preview.alpha_composite(top,(pad*16,pad*16));preview.save(out/'preview.png')
    print('Composed world:',w,h,'areas',len(areas),'native doors',len(warps),'seam cells',len(seams),'cards',len(metadata['cards']),'atlas',atlas.size,flush=True)
    # Elevation is solved as one field; road ends never fall back to sea level.
    from road_elevation import bake as bake_elevation
    bake_elevation(WORLD)

def main():
    parser=argparse.ArgumentParser();parser.add_argument('--sources-only',action='store_true');parser.add_argument('--compose-only',action='store_true');parser.add_argument('--force',action='store_true')
    args=parser.parse_args();fm.fetch=network_fetch;s=scope();p=plan(s);safari=definitions(s,p)
    print('Mainland plan:',len(s['outdoor']),'outdoor maps,',p['width'],'x',p['height'],'tiles;',len(new_singles(s,legacy_registry())),'new interior/dungeon maps',flush=True)
    if not args.compose_only:bake_sources(s,p,safari,args.force)
    if not args.sources_only:compose(s,p)

if __name__=='__main__':main()
