"""Bake the native FRLG Kanto town map and safe, implemented fly destinations."""
import json
import math
import re
import struct
from pathlib import Path
from PIL import Image
import frlg_map as fm

ROOT=Path(__file__).resolve().parents[1]
OWNERS={"kanto_field":"kanto_south","kanto_east":"kanto_east","cerulean_north":"cerulean_north","saffron_city":"saffron_city","route11":"route11"}
KO={"pallet_town":"태초마을","viridian_city":"상록시티","pewter_city":"회색시티","cerulean_city":"블루시티","vermilion_city":"갈색시티",
    "lavender_town":"보라타운","celadon_city":"무지개시티","fuchsia_city":"연분홍시티","saffron_city":"노랑시티","cinnabar_island":"홍련섬","indigo_plateau":"석영고원"}

def landing(folder,data,area):
    water_path=folder/"water.json"
    water=json.loads(water_path.read_text()).get("water",[]) if water_path.exists() else []
    blocked={(int(w['x']),int(w['y'])) for w in data.get('warps',[])}
    patch_path=folder/'collision_patch.json'
    patch=json.loads(patch_path.read_text()) if patch_path.exists() else {}
    opened={tuple(p) for p in patch.get('open',[])}
    patched={tuple(p) for p in patch.get('block',[])}
    def free(x,y,grass=False):
        return (0<=x<data['width'] and 0<=y<data['height']
                and (x,y) not in blocked and (x,y) not in patched
                and ((x,y) in opened or data['solid'][y][x]=='0')
                and data['ledge'][y][x]=='0' and (grass or data['grass'][y][x]=='0')
                and (not water or water[y][x]=='0'))
    center=(area['x']+area['w']/2,area['y']+area['h']/2)
    doors=[w for w in data.get('warps',[]) if w.get('map')==area['id'] and 'pokemon_center' in w.get('to','')]
    if doors:center=(doors[0]['x'],doors[0]['y']+3)
    candidates=[]
    for y in range(area['y']+1,area['y']+area['h']-1):
        for x in range(area['x']+1,area['x']+area['w']-1):
            if all(free(x+dx,y+dy) for dx in [-1,0,1] for dy in [-1,0,1]):
                candidates.append((math.hypot(x-center[0],y-center[1]),x,y))
    if not candidates:
        for y in range(area['y'],area['y']+area['h']):
            for x in range(area['x'],area['x']+area['w']):
                if all(free(x+dx,y+dy,True) for dx in [-1,0,1] for dy in [-1,0,1]):
                    candidates.append((math.hypot(x-center[0],y-center[1]),x,y))
    if not candidates:return None
    _,x,y=min(candidates)
    return [x,y]

def main():
    png=fm.fetch('graphics/region_map/region_map.png')
    binary=fm.fetch('graphics/region_map/kanto.bin')
    sections=json.loads(fm.fetch('src/data/region_map/region_map_sections.json').read_text())['map_sections']
    atlas=Image.open(png).convert('RGBA')
    # The atlas already embeds the native palette; palette index zero is outside the map.
    indexed=Image.open(png)
    for y in range(atlas.height):
        for x in range(atlas.width):
            if indexed.getpixel((x,y))==0:atlas.putpixel((x,y),(0,0,0,0))
    out=Image.new('RGBA',(240,160))
    for i,value in enumerate(struct.unpack('<600H',binary.read_bytes())):
        tile=value&1023;x=tile%16*8;y=tile//16*8
        image=atlas.crop((x,y,x+8,y+8))
        if value&1024:image=image.transpose(Image.Transpose.FLIP_LEFT_RIGHT)
        if value&2048:image=image.transpose(Image.Transpose.FLIP_TOP_BOTTOM)
        out.alpha_composite(image,((i%30)*8,(i//30)*8))
    out.save(ROOT/'assets/ui/kanto_town_map.png')
    places={}
    for folder,owner in OWNERS.items():
        path=ROOT/'assets/maps'/folder;data=json.loads((path/'map.json').read_text())
        for area in data['areas']:
            point=landing(path,data,area)
            if point:places[area['id']]={'map':owner,'tile':point,'area':area['id'],'local_tile':[point[0]-area['x'],point[1]-area['y']]}
    world=ROOT/'assets/maps/kanto_world'
    if (world/'map.json').exists():
        data=json.loads((world/'map.json').read_text())
        aliases={'route21_north':'route21','route21_south':'route21','indigo_plateau_exterior':'indigo_plateau'}
        for area in data['areas']:
            point=landing(world,data,area)
            key=aliases.get(area['id'],area['id'])
            if point and not (key=='route21' and key in places):
                places[key]={'map':'kanto_world','tile':point,'area':area['id'],'local_tile':[point[0]-area['x'],point[1]-area['y']]}
    records=[]
    for section in sections:
        key=section['id'].removeprefix('MAPSEC_').lower()
        match=re.fullmatch(r'route_(\d+)',key)
        if match and 1<=int(match[1])<=25:
            num=int(match[1]);key=f'route{num}';name_ko=f'{num}번도로';kind='route'
        elif key in KO:name_ko=KO[key];kind='town' if key in ['pallet_town','lavender_town'] else 'city'
        else:continue
        entry=dict(id=key,name=section['name'],name_ko=name_ko,kind=kind,
                   region=[section['x']*8+32,section['y']*8+32,section['width']*8,section['height']*8],enabled=key in places)
        entry.update(places.get(key,{}));records.append(entry)
    records.sort(key=lambda e:(e['kind']=='route',int(e['id'][5:]) if e['kind']=='route' else list(KO).index(e['id'])))
    (ROOT/'assets/data/fly_destinations.json').write_text(json.dumps({'source':'pret/pokefirered region_map_sections.json, kanto.bin; current baked maps','locations':records},ensure_ascii=False,indent=2)+'\n')
    print('Native Kanto town map; destinations:',[(e['id'],e['tile']) for e in records if e['enabled']])

if __name__=='__main__':main()
