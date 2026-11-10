"""동굴 절벽을 연속 지형으로, 원본의 작은 바위/안내판은 별도 사물로 굽는다."""
from collections import Counter
from PIL import Image
from north_terrain import source_cells, cut_background

ROCK_IDS={0x282,0x283}
SIGN_ID=0x2cd
FOLDERS={'mt_moon_1f':'MtMoon_1F','mt_moon_b1f':'MtMoon_B1F','mt_moon_b2f':'MtMoon_B2F','arena_mt_moon':'MtMoon_1F'}
FOLDERS.update({'rock_tunnel_1f':'RockTunnel_1F','rock_tunnel_b1f':'RockTunnel_B1F'})
FOLDERS.update({'digletts_cave_north_entrance':'DiglettsCave_NorthEntrance','digletts_cave_south_entrance':'DiglettsCave_SouthEntrance','digletts_cave_b1f':'DiglettsCave_B1F'})
for _stem,_folder,_floors in [('victory_road','VictoryRoad',['1F','2F','3F']),
                             ('seafoam_islands','SeafoamIslands',['1F','B1F','B2F','B3F','B4F']),
                             ('cerulean_cave','CeruleanCave',['1F','2F','B1F'])]:
    FOLDERS.update({_stem+'_'+floor.lower():_folder+'_'+floor for floor in _floors})

def build(d,j):
    t=16;w=j['width'];h=j['height'];p=j.get('pad',0)
    bottom=Image.open(d/'bottom.png').convert('RGBA')
    raw=bottom.crop((p*t,p*t,(p+w)*t,(p+h)*t))
    raw.alpha_composite(Image.open(d/'top.png').convert('RGBA'))
    if j.get('arena'):
        import struct
        from pathlib import Path
        blocks=(Path(__file__).resolve().parents[1]/'third_party/pokefirered/generated'/f'{d.name}.bin').read_bytes()
        cells={(i%w,i//w):v&1023 for i,v in enumerate(struct.unpack(f'<{w*h}H',blocks))}
    elif j.get('source_layout'):
        import struct
        import frlg_map as fm
        layout=fm.layout_of(j['source_layout'])
        blocks=struct.unpack(f'<{w*h}H',fm.fetch(layout['blockdata_filepath']).read_bytes())
        cells={(i%w,i//w):v&1023 for i,v in enumerate(blocks)}
    else:
        cells=source_cells(j,[FOLDERS[j['areas'][0]['id']]])
    source_solid={(x,y) for y,row in enumerate(j['solid']) for x,c in enumerate(row) if c=='1'}
    props={xy:mid for xy,mid in cells.items() if mid in ROCK_IDS or mid==SIGN_ID}
    # Ladder shaft caps are solid in FRLG but must not become cliff cubes.
    flat={xy for xy,mid in cells.items() if mid in {0x2c9,0x28e,0x28f}}
    import json
    water_path=d/'water.json'
    water_rows=json.loads(water_path.read_text()).get('water',[]) if water_path.exists() else []
    water={(x,y) for y,row in enumerate(water_rows) for x,c in enumerate(row) if c=='1'}
    solid=source_solid-props.keys()-flat-water
    if j.get('arena'):
        # The trainer apron is collision-locked, but visually remains level floor.
        rim=int(j['arena']['wall_rows'])
        solid-={(x,y) for y in range(rim,h-rim) for x in range(rim,w-rim)}
    # Only native plain cave floor may fill a hidden cliff footprint. Ladders/entrance art are excluded.
    donors=[xy for xy,mid in cells.items() if mid==0x281 and xy not in solid]
    if not donors:
        warps={(v['x'],v['y']) for v in j.get('warps',[])}
        candidates={xy:mid for xy,mid in cells.items() if xy not in source_solid and xy not in warps and xy not in flat and xy not in water}
        mid=Counter(candidates.values()).most_common(1)[0][0]
        donors=[xy for xy,v in candidates.items() if v==mid]
    counts=Counter(raw.crop((x*t,y*t,(x+1)*t,(y+1)*t)).tobytes() for x,y in donors)
    clean_floor=Image.frombytes('RGBA',(t,t),counts.most_common(1)[0][0])
    floor_colors=set(clean_floor.getdata())
    floor=bottom.copy();floor.alpha_composite(raw,(p*t,p*t))
    for x,y in solid|props.keys():floor.paste(clean_floor,((x+p)*t,(y+p)*t))
    floor.save(d/'hd2d_floor.png')
    # A tile's footprint is independent of its height: never collapse a long
    # north/south cliff run into a stretched roof and a two-row billboard.
    # FRLG's block elevation nibble is a movement layer (all cave paths use 3),
    # not a metric height. Use an explicit terrain surface one tile above floor.
    import json
    from pathlib import Path
    donor_dir=Path(__file__).resolve().parents[1]/'assets/maps/mt_moon_1f'
    donor_map=json.loads((donor_dir/'map.json').read_text())
    donor_cells=source_cells(donor_map,['MtMoon_1F'])
    dp=donor_map.get('pad',0)
    donor_raw=Image.open(donor_dir/'preview.png').convert('RGBA')
    def sample(mid):
        x,y=next(xy for xy,m in donor_cells.items() if m==mid)
        return donor_raw.crop(((x+dp)*t,(y+dp)*t,(x+dp+1)*t,(y+dp+1)*t))
    cap=sample(0x2a3)
    # This source metatile includes a north-facing rim in its first four rows.
    # The rim now has real geometry, so extend the plain plateau pixels over it.
    cap.paste(cap.crop((0,12,t,t)),(0,0))
    wall=sample(0x299)
    if d.name.startswith(('seafoam_islands','cerulean_cave')):
        # Ice/cave palettes come from this cave, never from Mt. Moon's brown rock.
        def local_sample(mid,fallback):
            xy=next((xy for xy,value in cells.items() if value==mid),None)
            return raw.crop((xy[0]*t,xy[1]*t,(xy[0]+1)*t,(xy[1]+1)*t)) if xy else fallback
        cap=local_sample(0x2a3,cap);cap.paste(cap.crop((0,12,t,t)),(0,0))
        wall=local_sample(0x299,wall)
    textures=[];uvs={}
    def texture(art):
        key=art.tobytes()
        if key not in uvs:
            i=len(textures);uvs[key]=[(i%16)*t,(i//16)*t];textures.append(art)
        return uvs[key]
    wall_uv=texture(wall)
    heights=[[1 if (x,y) in solid else 0 for x in range(w)] for y in range(h)]
    tiles=[]
    for x,y in sorted(solid):
        # Reuse native plateau pixels. Wall-facing artwork belongs exclusively
        # on vertical faces; it must never be painted onto the raised cap.
        art=cap.transpose(Image.Transpose.FLIP_LEFT_RIGHT) if (x+y)%3==0 else cap
        tiles.append([x,y,*texture(art)])
    cap_uv=texture(cap)
    atlas=Image.new('RGBA',(16*t,((len(textures)+15)//16)*t))
    for i,im in enumerate(textures):atlas.paste(im,((i%16)*t,(i//16)*t))
    atlas.save(d/'hd2d_atlas.png')
    heightfield=dict(heights=heights,tiles=tiles,wall_uv=wall_uv,floor_height=0,
                     wall_height=1,padding=p,cap_uv=cap_uv,source='native solid footprints; explicit metric terrain height')
    cards=[]
    tables=[];objects=[]
    for (x,y),mid in props.items():
        id=('rock' if mid in ROCK_IDS else 'sign')+f'_{x}_{y}';tex='hd2d_terrain_'+id
        cut_background(raw.crop((x*t,y*t,(x+1)*t,(y+1)*t)),floor_colors).save(d/(tex+'_front.png'))
        tables.append(dict(id=id,card=True,x0=x,x1=x+1,z0=y+1,z1=y+1,h=.875,base=0,tex=tex))
        objects.append(dict(id=id,tile=[x,y],mid=mid))
    return dict(tile=t,cards=cards,houses=[],props=[],tables=tables,terrain='heightfield_cave_cliffs',heightfield=heightfield,
                terrain_objects=objects,flat_terrain_tiles=[list(xy) for xy in sorted(flat)],floor_donor_mid=cells[donors[0]],
                floor_donor_tile=list(next((x,y) for x,y in donors if raw.crop((x*t,y*t,(x+1)*t,(y+1)*t)).tobytes()==clean_floor.tobytes())))


if __name__ == '__main__':
    import json
    import sys
    from pathlib import Path
    root=Path(__file__).resolve().parents[1]/'assets/maps'
    for name in sys.argv[1:] or FOLDERS:
        if name not in FOLDERS:raise SystemExit('Unsupported cave: '+name)
        directory=root/name
        metadata=build(directory,json.loads((directory/'map.json').read_text()))
        (directory/'hd2d_cards.json').write_text(json.dumps(metadata,ensure_ascii=False,indent=2)+'\n')
        print(name,len(metadata['heightfield']['tiles']),'raised terrain cells')
