"""원본 지하통로 입구·계단·난간과 5·6번도로 시설을 분리한다."""
import json
from PIL import Image
from city_facility_objects import build as build_room
from north_terrain import source_cells, remove_cells, cut_background

ENTRANCES={'underground_path_north_entrance','underground_path_south_entrance'}
TUNNEL='underground_path_north_south_tunnel'
GATES={'route5_south_entrance','route6_north_entrance'}
FENCES={0xe7,0xec,0xed,0xee,0xef,0xf4,0xf5,0xf6,0xf7}

def entrance(d,j,name):
    specs=[]
    def add(id,kind,rect,**kw):specs.append(dict(id=id,kind=kind,rect=rect,donor=[4,7],**kw))
    for side,stem,cap in [('left',32,48),('right',160,144)]:
        add(side+'_partition_stem','box',[stem,44,stem+16,112],front=104,z1=7,depth=3.75,height=.5)
        add(side+'_partition_north','box',[cap,44,cap+16,64],front=56,z1=4,depth=.75,height=.5)
        add(side+'_partition_south','box',[cap,96,cap+16,112],front=104,z1=7,depth=.5,height=.5)
    add('stairs_down_opening','decal',[83,60,111,92])
    add('stair_rail_north','card',[80,56,114,60],z1=3.5,height=.25)
    add('stair_rail_south','card',[80,92,114,96],z1=6,height=.25)
    for label,x in [('west',80),('east',111)]:
        add('stair_rail_'+label,'card',[x,60,x+3,92],z1=5.75,height=.25)
    for i,(x,y) in enumerate([(0,20),(192,20),(0,116),(192,116)]):
        add(f'potted_plant_{i}','card',[x,y,x+16,min(y+28,160)],z1=min(y+28,160)/16,height=1.75,wall=104)
    metadata=build_room(d,j,name,specs)
    for obj in metadata['tables']:
        if obj['id'] in ('stair_rail_west','stair_rail_east'):
            path=d/(obj['tex']+'_front.png')
            Image.open(path).transpose(Image.Transpose.ROTATE_90).save(path)
            obj.update(side_card=True,x0=5 if obj['id'].endswith('west') else 7.125,x1=5 if obj['id'].endswith('west') else 7.125,z0=3.75,z1=5.75)
    metadata['underground']=dict(stair_direction='down',original_stair_warp=[7,4],partition_height=.5)
    return metadata

def gate(d,j,name):
    specs=[]
    for i,x in enumerate([32,96]):
        specs.append(dict(id=f'gate_partition_{i}',kind='box',rect=[x,25,x+16,160],front=152,z1=10,depth=7.9375,height=.5,wall=24,donor=[1,4]))
    for i,(x,y) in enumerate([(0,36),(128,36),(0,84),(128,84),(0,132),(128,132)]):
        # The outside floor tiles include a shaded strip. Using the corridor
        # tile as a donor leaves that gold pattern standing behind the leaves.
        specs.append(dict(id=f'gate_plant_{i}',kind='card',rect=[x,y,x+16,y+28],z1=(y+28)/16,height=1.75,donor=[x//16,4]))
    for i,x in enumerate([0,114]):
        specs.append(dict(id=f'gate_window_{i}',kind='card',rect=[x,10,x+24,24],z1=2.01,base=.5,wall=24,donor=[1,4]))
    result=build_room(d,j,name,specs)
    p=j.get('pad',0)*16
    raw=Image.open(d/'preview.png').convert('RGBA').crop((p,p,p+j['width']*16,p+j['height']*16))
    plants=[]
    for obj in result['tables']:
        if not obj['id'].startswith('gate_plant_'):continue
        source=next(s for s in specs if s['id']==obj['id'])
        x,y,xx,yy=source['rect']
        # Only the native foliage and stem remain on the card. The original
        # pot/soil/shadow are removed with the full source rectangle above;
        # the shared octagonal planter supplies a solid rim, body and soil.
        foliage=raw.crop((x,y,xx,y+16))
        foliage.putdata([(0,0,0,0) if r>=g and g>b+25 else (r,g,b,a)
                         for r,g,b,a in foliage.getdata()])
        foliage.save(d/(obj['tex']+'_front.png'))
        obj.update(planter=True,base=.5625,h=1.0)
        plants.append(dict(id=obj['id'],source=[x,y,xx,yy],foliage_source=[x,y,xx,y+16],
                           root=[(x+xx)/32,(y+28)/16],pot_height=.5625))
    result['gate_facility']=dict(partition_height=.5,original_exit_map='route5' if name.startswith('route5') else 'route6',plants=plants)
    return result

def tunnel(d,j):
    p=j['pad'];w,h=j['width'],j['height']
    raw=Image.open(d/'preview.png').convert('RGBA').crop((p*16,p*16,(p+w)*16,(p+h)*16));clean=raw.copy()
    floor_colors=set(raw.crop((48,128,64,144)).getdata())
    tables=[]
    for id,rect in [('stairs_up_north',(80,24,112,76)),('stairs_up_south',(16,936,48,992))]:
        x,y,xx,yy=rect;art=cut_background(raw.crop(rect),floor_colors);tex='hd2d_'+id
        art.save(d/(tex+'_front.png'))
        tables.append(dict(id=id,card=True,x0=x/16,x1=xx/16,z0=yy/16,z1=yy/16,h=2,base=0,tex=tex))
        for py in range(y,yy):
            for px in range(x,xx):clean.putpixel((px,py),raw.getpixel((48,py)) if py<32 else raw.getpixel((48+px%16,128+py%16)))
    for i,x in enumerate([32,80]):
        tex=f'hd2d_tunnel_wall_lamp_{i}';art=raw.crop((x,16,x+16,30));cut_background(art,{raw.getpixel((48,24))}).save(d/(tex+'_front.png'))
        tables.append(dict(id=f'wall_lamp_{i}',card=True,x0=x/16,x1=(x+16)/16,z0=2.01,z1=2.01,h=.875,base=.125,tex=tex))
        for y in range(16,30):
            for xx in range(x,x+16):clean.putpixel((xx,y),raw.getpixel((48,y)))
    atlas=Image.new('RGBA',(w*16,48));atlas.paste(clean.crop((0,0,w*16,32)),(0,0))
    # Each side segment uses the original stone curb rotated into an upright cutaway wall.
    left=raw.crop((8,128,16,144)).transpose(Image.Transpose.ROTATE_90)
    right=raw.crop((112,128,120,144)).transpose(Image.Transpose.ROTATE_270)
    atlas.paste(left,(0,32));atlas.paste(right,(16,32));atlas.save(d/'hd2d_atlas.png')
    sides=[]
    for y in range(2,h-1):
        sides.append(dict(column=100,a=[1,y],b=[1,y+1],h=.75,atlas=[0,32,16,8]))
        sides.append(dict(column=101,a=[7,y+1],b=[7,y],h=.75,atlas=[16,32,16,8]))
    floor=Image.open(d/'bottom.png').convert('RGBA');floor.paste(clean,(p*16,p*16));floor.save(d/'hd2d_floor.png')
    (d/'collision_patch.json').write_text(json.dumps(dict(open=[],block=[])))
    return dict(tile=16,cards=[[x,0,2,x*16,0,0,1,0,0] for x in range(1,7)],corner_walls=sides,
                tables=tables,houses=[],props=[],underground=dict(side_wall_height=.75,stair_direction='up',original_stair_warps=[[4,3],[3,60]]))

def road_facilities(d,j,name,metadata):
    folder='Route5' if name=='kanto_north' else 'Route6'
    area=next(a for a in j['areas'] if a['id']==folder.lower())
    cells=source_cells(j,[folder]);p=j['pad'];w,h=j['width'],j['height']
    raw=Image.open(d/'preview.png').convert('RGBA').crop((p*16,p*16,(p+w)*16,(p+h)*16))
    ground=next(xy for xy,mid in cells.items() if mid==8 and j['solid'][xy[1]][xy[0]]=='0')
    gx,gy=ground;tile=raw.crop((gx*16,gy*16,(gx+1)*16,(gy+1)*16));colors=set(tile.getdata())
    groups=[dict(id='underground_hut',x=30 if folder=='Route5' else 18,y=28 if folder=='Route5' else 10,w=4,h=4,roof=2),
            dict(id='city_gate',x=22 if folder=='Route5' else 10,y=33 if folder=='Route5' else 0,w=6,h=6,roof=3,flat_step=True)]
    removed={xy for xy,mid in cells.items() if mid in FENCES or mid==2};strips=[];definitions=[]
    for group in groups:
        x,y=group['x']+area['x'],group['y']+area['y'];group.update(world_x=x,world_y=y)
        for xx in range(x,x+group['w']):
            removed.update((xx,yy) for yy in range(y,y+group['h']+int(group.get('flat_step',False))))
            strips.append(cut_background(raw.crop((xx*16,y*16,(xx+1)*16,(y+group['h'])*16)),colors))
            definitions.append([xx,y,group['h'],len(strips)-1,group['roof']])
    fence_tiles=[];sign_tiles=[]
    for (x,y),mid in cells.items():
        if mid not in FENCES and mid!=2:continue
        strips.append(cut_background(raw.crop((x*16,y*16,(x+1)*16,(y+1)*16)),colors))
        definitions.append([x,y,1,len(strips)-1,0])
        (sign_tiles if mid==2 else fence_tiles).append([x,y])
    metadata['cards']=remove_cells(metadata['cards'],removed)
    old=Image.open(d/'hd2d_atlas.png').convert('RGBA');stride=112;cols=old.width//16
    atlas=Image.new('RGBA',(old.width,old.height+((len(strips)+cols-1)//cols)*stride));atlas.paste(old,(0,0))
    for i,art in enumerate(strips):atlas.paste(art,((i%cols)*16,old.height+(i//cols)*stride))
    atlas.save(d/'hd2d_atlas.png')
    metadata['cards'] += [[x,y,n,(i%cols)*16,old.height+(i//cols)*stride,r,1,0,0] for x,y,n,i,r in definitions]
    floor=Image.open(d/'hd2d_floor.png').convert('RGBA')
    for x,y in removed:floor.paste(tile,((x+p)*16,(y+p)*16))
    for group in groups:
        if group.get('flat_step'):
            x,y=group['world_x'],group['world_y']+group['h']
            for xx in range(x,x+group['w']):
                if cells.get((xx,y)) not in FENCES:
                    floor.paste(raw.crop((xx*16,y*16,(xx+1)*16,(y+1)*16)),((xx+p)*16,(y+p)*16))
    floor.save(d/'hd2d_floor.png')
    metadata['road_facilities']=dict(source=folder,buildings=groups,fence_tiles=fence_tiles,sign_tiles=sign_tiles)
    return metadata
