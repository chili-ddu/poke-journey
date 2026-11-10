"""Native Seafoam boulders, fall links, currents and current-stopped layouts."""
import json
import struct
from PIL import Image
import frlg_map as fm
import frlg_arena as ar
import frlg_npc
import cave_cards
from kanto_water import SURFABLE

FLOORS=['SeafoamIslands_1F','SeafoamIslands_B1F','SeafoamIslands_B2F','SeafoamIslands_B3F','SeafoamIslands_B4F']
FLOW={0x50:[1,0],0x51:[-1,0],0x52:[0,-1],0x53:[0,1]}

def terrain(layout):
    attrs={}
    for base,directory in [(0,fm.tileset_dir(layout['primary_tileset'])),(640,fm.tileset_dir(layout['secondary_tileset']))]:
        raw=fm.fetch(directory+'/metatile_attributes.bin').read_bytes()
        attrs.update({base+i:struct.unpack_from('<I',raw,i*4)[0]&511 for i in range(len(raw)//4)})
    return ar.blocks_of(layout),attrs

def write_water(directory,layout):
    blocks,attrs=terrain(layout);w,h=layout['width'],layout['height']
    # Currents are water even where native collision bits rely on a scripted ride.
    rows=[''.join('1' if attrs[b&1023] in FLOW or (attrs[b&1023] in SURFABLE and ((b>>10)&3)==0) else '0' for b in blocks[y*w:(y+1)*w]) for y in range(h)]
    (directory/'water.json').write_text(json.dumps({'water':rows},separators=(',',':'))+'\n')

def main():
    maps={fm.snake(name):fm.map_json(name) for name in FLOORS}
    result={'source':'pret/pokefirered native object events, MB_FALL_WARP and directional currents','floors':{},'objects':{},'roots':{}}
    for name in FLOORS:
        id=fm.snake(name);native=maps[id];layout=fm.layout_of(native['layout']);blocks,attrs=terrain(layout);w=layout['width']
        directory=fm.ROOT/'assets/maps'/id
        write_water(directory,layout)
        metadata=json.loads((directory/'map.json').read_text())
        (directory/'hd2d_cards.json').write_text(json.dumps(cave_cards.build(directory,metadata),indent=2)+'\n')
        objects=[]
        for obj in native.get('object_events',[]):
            if obj['graphics_id']!='OBJ_EVENT_GFX_PUSHABLE_BOULDER':continue
            flag=obj['flag'];reveal=obj['trainer_type']
            entry={'floor':id,'tile':[obj['x'],obj['y']],'flag':flag,'reveal':reveal if reveal.startswith('FLAG_') else '', 'pushable':obj['script']=='EventScript_StrengthBoulder'}
            result['objects'][flag]=entry;objects.append(flag)
        holes=[];arrivals=[]
        for warp in metadata['warps']:
            x,y=warp['x'],warp['y']
            if attrs[blocks[y*w+x]&1023]==0x66:
                target=maps[warp['to']];arrival=target['warp_events'][warp['to_warp']]
                holes.append({'tile':[x,y],'floor':warp['to'],'arrival':[arrival['x'],arrival['y']]})
            elif warp['to'] in maps:
                target=maps[warp['to']];tl=fm.layout_of(target['layout']);tb,ta=terrain(tl)
                tw=target['warp_events'][warp['to_warp']]
                if ta[tb[tw['y']*tl['width']+tw['x']]&1023]==0x66:arrivals.append([x,y])
        currents=[[i%w,i//w,*FLOW[attrs[b&1023]]] for i,b in enumerate(blocks) if attrs[b&1023] in FLOW]
        result['floors'][id]={'objects':objects,'holes':holes,'arrival_only':arrivals,'currents':currents}
        if name.endswith(('B3F','B4F')):
            calm_id=id+'_calm';calm_layout_id=native['layout']+'_CURRENT_STOPPED';calm=fm.layout_of(calm_layout_id)
            baked=fm.bake_layout(calm);out=fm.ROOT/'assets/maps'/calm_id;out.mkdir(parents=True,exist_ok=True)
            pad=metadata['pad'];width,height=calm['width'],calm['height']
            bottom=Image.new('RGBA',((width+2*pad)*16,(height+2*pad)*16));top=baked['top']
            bottom.alpha_composite(baked['bottom'],(pad*16,pad*16));fm.fill_borders(bottom,top,[(0,0,width,height,baked['border'])],width,height)
            bottom.save(out/'bottom.png');top.save(out/'top.png')
            preview=bottom.copy();preview.alpha_composite(top,(pad*16,pad*16));preview.save(out/'preview.png')
            data=dict(metadata,source_layout=calm_layout_id,source='native current-stopped Seafoam layout')
            solid=baked['solid']
            for warp in metadata['warps']:solid[warp['y']][warp['x']]=0
            data['solid']=[''.join(str(int(v)) for v in row) for row in solid]
            data['grass']=['0'*width]*height;data['ledge']=['0'*width]*height
            (out/'map.json').write_text(json.dumps(data,indent=2)+'\n')
            write_water(out,calm)
            (out/'hd2d_cards.json').write_text(json.dumps(cave_cards.build(out,data),indent=2)+'\n')
            result['floors'][id]['calm_map']='res://assets/maps/'+calm_id
    for floor in result['floors'].values():
        for hole in floor['holes']:
            arrival_only=result['floors'][hole['floor']]['arrival_only']
            if hole['arrival'] not in arrival_only:arrival_only.append(hole['arrival'])
    revealed={o['reveal'] for o in result['objects'].values()}
    result['roots']={flag:{'floor':o['floor'],'tile':o['tile'],'stage':flag} for flag,o in result['objects'].items() if flag not in revealed}
    (fm.ROOT/'assets/data/seafoam_puzzle.json').write_text(json.dumps(result,indent=2)+'\n')
    image=Image.open(fm.fetch('graphics/object_events/pics/misc/strength_boulder.png'))
    palette=frlg_npc.jasc(fm.fetch('graphics/object_events/palettes/npc_white.pal'))
    sprite=Image.new('RGBA',(16,32))
    for y in range(16):
        for x in range(16):
            index=image.getpixel((x,y))%16
            if index:sprite.putpixel((x,y+16),palette[index]+(255,))
    sprite.save(fm.ROOT/'assets/npcs/strength_boulder.png')
    print(f'Seafoam: {len(result["roots"])} root boulders, {sum(len(f["holes"]) for f in result["floors"].values())} fall holes, 2 native calm layouts')

if __name__=='__main__':main()
