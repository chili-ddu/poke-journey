"""도시 원본 건물별 지붕/벽 경계. 모든 텍스처는 원본 픽셀에서 추출한다."""
from collections import deque
import struct
import frlg_map as fm
from PIL import Image
from north_terrain import source_cells, remove_cells, cut_background

# x,y,w,h are original city tiles; roof_px is the measured source-pixel fold.
BUILDINGS={
 'cerulean_city':[
  dict(id='north_houses',rect=[8,8,13,4],roof_px=44),
  dict(id='burgled_house',rect=[28,8,7,4],roof_px=44),
  dict(id='east_house_back',rect=[38,7,6,4],roof_px=44),
  dict(id='west_house',rect=[13,14,7,4],roof_px=44),
  dict(id='pokemon_center',rect=[20,16,5,4],roof_px=36,badge=[24,30,56,48],roof_donor=12),
  dict(id='gym',rect=[28,17,7,5],roof_px=48),
  dict(id='bike_shop',rect=[12,24,4,5],roof_px=32),
  dict(id='mart_and_houses',rect=[21,25,15,4],roof_px=44,badge=[112,30,144,48],roof_donor=100),
 ],
 'vermilion_city':[
  dict(id='northwest_house',rect=[8,3,5,4],roof_px=48),
  dict(id='pokemon_center',rect=[13,2,5,5],roof_px=52,badge=[24,46,56,64],roof_donor=12),
  dict(id='north_house',rect=[18,3,4,4],roof_px=48),
  dict(id='northeast_house',rect=[25,3,5,4],roof_px=48),
  dict(id='fan_club',rect=[11,14,5,4],roof_px=32),
  dict(id='central_house',rect=[18,14,4,4],roof_px=48),
  dict(id='mart',rect=[27,14,4,4],roof_px=44,badge=[16,30,48,48],roof_donor=4),
  dict(id='gym',rect=[11,21,7,5],roof_px=48),
  dict(id='southeast_house',rect=[27,21,4,4],roof_px=48),
 ],
 'saffron_city':[
  dict(id='northwest_houses',rect=[17,10,12,5],roof_px=48),
  dict(id='dojo',rect=[37,8,6,5],roof_px=48),
  dict(id='gym',rect=[43,8,7,5],roof_px=48),
  dict(id='northeast_back',rect=[50,8,4,4],roof_px=48),
  dict(id='central_west',rect=[18,17,4,5],roof_px=48),
  dict(id='central_west_low',rect=[22,18,4,4],roof_px=48),
  dict(id='psychic_house',rect=[26,17,3,5],roof_px=48),
  dict(id='silph',rect=[29,16,9,15],roof_px=80),
  dict(id='mart',rect=[38,18,4,4],roof_px=44,badge=[16,30,48,48],roof_donor=4),
  dict(id='central_east_low',rect=[42,18,4,4],roof_px=48),
  dict(id='fan_club',rect=[46,17,4,5],roof_px=48),
  dict(id='office_west_1',rect=[19,25,5,6],roof_px=48),
  dict(id='office_west_2',rect=[24,25,5,6],roof_px=48),
  dict(id='office_east_1',rect=[38,25,5,6],roof_px=48),
  dict(id='office_east_2',rect=[43,25,5,6],roof_px=48),
  dict(id='southwest_house',rect=[18,34,4,5],roof_px=48),
  dict(id='pokemon_center',rect=[22,34,5,5],roof_px=52,badge=[24,46,56,64],roof_donor=12),
  dict(id='south_low_house',rect=[27,35,4,4],roof_px=48),
  dict(id='south_houses',rect=[31,34,8,5],roof_px=48),
  dict(id='southeast_houses',rect=[41,34,9,5],roof_px=48),
  dict(id='southwest_back',rect=[19,41,12,4],roof_px=48),
  dict(id='southeast_back',rect=[39,41,12,4],roof_px=48),
  dict(id='north_gate',rect=[32,0,6,6],roof_px=48),
  dict(id='south_gate',rect=[32,47,6,6],roof_px=48),
  dict(id='west_gate',rect=[2,24,6,5],roof_px=48),
  dict(id='west_gate_left',rect=[1,25,1,4],roof_px=32,open_sides=True),
  dict(id='west_gate_right',rect=[8,25,1,4],roof_px=32,open_sides=True),
  dict(id='east_gate',rect=[59,24,6,5],roof_px=48),
  dict(id='east_gate_left',rect=[58,25,1,4],roof_px=32,open_sides=True),
  dict(id='east_gate_right',rect=[65,25,1,4],roof_px=32,open_sides=True),
 ]}
CITY_MAPS={'kanto_north':('cerulean_city','CeruleanCity'),
           'kanto_east':('vermilion_city','VermilionCity'),
           'saffron_city':('saffron_city','SaffronCity')}
# 0x115 is the native sandy road. Its three colors also occur in the exposed
# rear margin of Vermilion roofs; leaving it out creates a raised floor-colored occluder.
GROUND={1,8,9,0xd4,0xd9,0xdc,0x115,0x12b}
SAFFRON_GROUND=GROUND|{0xd3,0xd5,0xdb,0xdd,0xde,0xe4,0x178,0x179,0x17a,0x2e1,0x2e3,0x2e4,0x2e5,0x2e8,0x2e9,0x2ea,0x2eb,
                      0x2ec,0x2ed,0x2f1,0x2f3,0x2f4,0x2f5}
SAFFRON_BACKGROUND=SAFFRON_GROUND-{0x178,0x179,0x17a}

def build(d,j,name,metadata):
    city,folder=CITY_MAPS[name]
    ground=SAFFRON_GROUND if city=='saffron_city' else GROUND
    color_ground=SAFFRON_BACKGROUND if city=='saffron_city' else ground
    area=next(a for a in j['areas'] if a['id']==city)
    cells=source_cells(j,[folder]);p=j.get('pad',0);w,h=j['width'],j['height']
    raw=Image.open(d/'preview.png').convert('RGBA').crop((p*16,p*16,(p+w)*16,(p+h)*16))
    layout=fm.layout_of(fm.map_json(folder)['layout']);water_ids=set()
    for base,tileset in [(0,layout['primary_tileset']),(640,layout['secondary_tileset'])]:
        values=fm.fetch(fm.tileset_dir(tileset)+'/metatile_attributes.bin').read_bytes()
        for i in range(len(values)//4):
            behavior=struct.unpack_from('<I',values,i*4)[0]&0x1ff
            if behavior in set(range(0x10,0x1c))-{0x17}:water_ids.add(base+i)
    water={xy for xy,mid in cells.items() if mid in water_ids}
    donors={xy:xy for xy,mid in cells.items() if mid in ground|water_ids}
    nearest=dict(donors);q=deque(nearest)
    while q:
        x,y=q.popleft()
        for n in ((x-1,y),(x+1,y),(x,y-1),(x,y+1)):
            if 0<=n[0]<w and 0<=n[1]<h and n not in nearest:nearest[n]=nearest[x,y];q.append(n)
    floor_bg=set();roof_bg=set()
    for (x,y),mid in cells.items():
        if mid in ((color_ground-{0x12b}) if city=='saffron_city' else (8,9,0x12b)):floor_bg.update(raw.crop((x*16,y*16,(x+1)*16,(y+1)*16)).getdata())
        if mid in color_ground|water_ids or 0x14<=mid<=0x1f:roof_bg.update(raw.crop((x*16,y*16,(x+1)*16,(y+1)*16)).getdata())
    roof_bg |= floor_bg
    front_bg=set(floor_bg)
    if city=='saffron_city':
        from hd2d_cards import _tree_template
        leaf_colors={c for c in _tree_template(name)[0].getdata() if c[3]>0}
        # The southern back facades share native metatiles with the first
        # forest row. Trees are already separate crowns, never facade pixels.
        front_bg |= leaf_colors
        roof_bg |= leaf_colors
    back_steps=[]
    if city=='cerulean_city':
        for warp in j['warps']:
            if warp['map']==city and warp['index'] in (8,9):
                cx=int((warp['x']+.5)*16);yy=warp['y']*16+4
                back_steps.append(dict(rect=[cx-18,yy,cx+18,yy+5],warp=warp['index']))
    removed=set();strips=[];cards=[];records=[]
    for group in BUILDINGS[city]:
        lx,ly,bw,bh=group['rect'];x,y=lx+area['x'],ly+area['y'];fold=group['roof_px']
        art=raw.crop((x*16,y*16,(x+bw)*16,(y+bh)*16))
        assert 0<fold<art.height,(city,group['id'])
        record=dict(id=group['id'],source_rect=group['rect'],world_rect=[x,y,bw,bh],roof_px=fold)
        if group.get('open_sides'):record['open_sides']=True
        if 'badge' in group:
            a,b,c,e=group['badge'];badge=art.crop((a,b,c,e))
            # Flood only colors taken from the adjoining roof. The enclosed logo remains intact.
            roof_colors=set(art.crop((group['roof_donor'],b,group['roof_donor']+1,min(fold,e))).getdata())
            cut_background(badge,roof_colors).save(d/('hd2d_city_'+group['id']+'_badge_front.png'))
            metadata['tables'].append(dict(id='city_'+group['id']+'_badge',card=True,x0=x+a/16,x1=x+c/16,
                 z0=y+bh+.012,z1=y+bh+.012,h=(e-b)/16,base=bh-e/16,tex='hd2d_city_'+group['id']+'_badge'))
            for yy in range(b,min(fold,e)):
                for xx in range(a,c):art.putpixel((xx,yy),raw.getpixel((x*16+group['roof_donor']+xx%4,y*16+yy)))
            record['badge']=group['badge']
        for step in back_steps:
            a,b,c,e=step['rect']
            if x*16<=a and c<=(x+bw)*16 and y*16<=b and e<=(y+bh)*16:
                for yy in range(b,e):
                    for xx in range(a,c):art.putpixel((xx-x*16,yy-y*16),(0,0,0,0))
        # Protect native roof colors even when the nearby sea shares a blue palette.
        keep=set(art.crop((8,max(0,fold-24),art.width-8,fold-4)).getdata())
        top=cut_background(art.crop((0,0,art.width,fold)),roof_bg-keep)
        front=cut_background(art.crop((0,fold,art.width,art.height)),front_bg)
        art.paste(top,(0,0));art.paste(front,(0,fold))
        for dx in range(bw):
            strip=art.crop((dx*16,0,(dx+1)*16,art.height));index=len(strips);strips.append(strip)
            face=strip.crop((0,fold,16,strip.height))
            side=max(range(16),key=lambda xx:sum(face.getpixel((xx,yy))[3]>0 for yy in range(face.height)))
            rear=next((yy for yy in range(fold) if any(strip.getpixel((xx,yy))[3]>0 for xx in range(16))),fold)
            # These are thin portal frames around an open east/west doorway,
            # not opaque wall columns stretched across the whole entrance.
            if group.get('open_sides'):rear=fold
            cards.append([x+dx,y,bh,index,fold/16,side,rear/16])
        removed.update((xx,yy) for yy in range(y,y+bh) for xx in range(x,x+bw))
        records.append(record)
    metadata['cards']=remove_cells(metadata['cards'],removed|water)
    # The old red-center auto-house must not remain under the explicitly measured building.
    metadata['houses']=[house for house in metadata['houses'] if not any(
        house['x']<r['world_rect'][0]+r['world_rect'][2] and house['x']+house['w']>r['world_rect'][0]
        and r['world_rect'][1]<=house['z']<=r['world_rect'][1]+r['world_rect'][3] for r in records)]
    old=Image.open(d/'hd2d_atlas.png').convert('RGBA');cols=old.width//16;stride=max(im.height for im in strips)
    atlas=Image.new('RGBA',(old.width,old.height+((len(strips)+cols-1)//cols)*stride));atlas.paste(old,(0,0))
    for i,im in enumerate(strips):atlas.paste(im,((i%cols)*16,old.height+(i//cols)*stride))
    atlas.save(d/'hd2d_atlas.png')
    metadata['cards'] += [[x,y,n,(i%cols)*16,old.height+(i//cols)*stride,r,1,0,0,3,side,rear] for x,y,n,i,r,side,rear in cards]
    floor=Image.open(d/'hd2d_floor.png').convert('RGBA')
    for x,y in removed:
        a,b=nearest[x,y];floor.paste(raw.crop((a*16,b*16,(a+1)*16,(b+1)*16)),((x+p)*16,(y+p)*16))
    for x,y in water:floor.paste(raw.crop((x*16,y*16,(x+1)*16,(y+1)*16)),((x+p)*16,(y+p)*16))
    for step in back_steps:
        a,b,c,e=step['rect'];floor.paste(raw.crop((a,b,c,e)),(a+p*16,b+p*16))
    floor.save(d/'hd2d_floor.png')
    metadata['city_exteriors']=dict(city=city,buildings=records,water_tiles=[list(xy) for xy in sorted(water)],back_steps=back_steps,source='pret/pokefirered '+folder)
    return metadata
