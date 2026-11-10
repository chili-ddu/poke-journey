"""Native Fuchsia scenery, safari workers and existing Lapras animations."""
import json
import struct
from PIL import Image
import frlg_arena as ar
import frlg_map as fm
import hd2d_cards
import frlg_npc
import kanto_wild_assets

NAME='arena_lapras_escape'

def main():
    layout=fm.layout_of(fm.map_json('FuchsiaCity')['layout'])
    # Row 23 is the road's grassy edge; repeat its interior, not that edge.
    source=ar.blocks_of(layout);floor=source[12+24*layout['width']]
    border,bw,bh=ar.border_blocks(layout)
    width,height,ring=24,26,2
    blocks=[floor if ring<=x<width-ring and ring<=y<height-ring else (border[x%bw+(y%bh)*bw]&1023)|1024 for y in range(height) for x in range(width)]
    rel=f'generated/{NAME}.bin';path=fm.TP/rel;path.parent.mkdir(parents=True,exist_ok=True)
    path.write_bytes(struct.pack(f'<{width*height}H',*blocks))
    baked=fm.bake_layout(dict(layout,width=width,height=height,blockdata_filepath=rel))
    pad=fm.PAD
    bottom=Image.new('RGBA',((width+2*pad)*16,(height+2*pad)*16),(0,0,0,255))
    bottom.alpha_composite(baked['bottom'],(pad*16,pad*16));top=baked['top']
    fm.fill_borders(bottom,top,[(0,0,width,height,baked['border'])],width,height)
    out=ar.ROOT/'assets/maps'/NAME;out.mkdir(parents=True,exist_ok=True)
    bottom.save(out/'bottom.png');top.save(out/'top.png')
    # Staff occupy the northern apron; only their Pokémon enter the field.
    data=dict(width=width,height=height,tile=16,pad=pad,
              solid=[''.join('0' if 2<=x<22 and 2<=y<24 else '1' for x in range(width)) for y in range(height)],
              grass=['0'*width]*height,ledge=['0'*width]*height,start=[12*16+8,19*16+8],
              areas=[dict(id=NAME,x=0,y=0,w=width,h=height)],warps=[],
              arena=dict(surface='natural',style='border',wall_rows=2,player=[12,19],field=[2,7,20,17]),
              source='pret/pokefirered FuchsiaCity native terrain; four safari staff battle')
    (out/'map.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    preview=bottom.copy();preview.alpha_composite(top,(pad*16,pad*16));preview.save(out/'preview.png')
    hd2d_cards.TREE_DEFS[NAME]={'map':'kanto_south','x':14,'y':174,'bottom_y':174,'w':2,'h':3}
    hd2d_cards.build(NAME)
    patch_path=out/'collision_patch.json'
    patch=json.loads(patch_path.read_text()) if patch_path.exists() else dict(open=[],block=[])
    patch['block']=[list(tile) for tile in sorted({tuple(t) for t in patch.get('block',[])}|{(x,y) for x in range(2,22) for y in range(2,7)})]
    patch_path.write_text(json.dumps(patch,indent=2)+'\n')
    # Use the actual worker graphic/palette from the native Safari entrance.
    sprite=ar.ROOT/'assets/npcs/worker_m.png'
    if not sprite.exists():
        image=Image.open(frlg_npc.fetch('graphics/object_events/pics/people/worker_m.png'))
        palette=frlg_npc.jasc(frlg_npc.fetch('graphics/object_events/palettes/npc_white.pal'))
        result=Image.new('RGBA',image.size)
        for y in range(image.height):
            for x in range(image.width):
                index=image.getpixel((x,y))%16
                if index:result.putpixel((x,y),palette[index]+(255,))
        result.save(sprite)
    kanto_wild_assets.main([131])
    print('Lapras escape arena and native safari staff ready',flush=True)

if __name__=='__main__':main()
