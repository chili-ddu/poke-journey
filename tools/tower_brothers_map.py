"""Bake a clear square phantom battlefield using original Pokémon Tower tiles.

The native seven floors are left intact. Run: python3 tools/tower_brothers_map.py
"""
import json
import struct
from PIL import Image
import frlg_arena as ar
import frlg_map as fm

NAME = 'arena_tower_brothers'

def main():
    layout = fm.layout_of(fm.map_json('PokemonTower_3F')['layout'])
    source = ar.blocks_of(layout)
    # Original clean floor and the north wall, with a clear 16×16 combat square.
    floor = source[8 + 7 * layout['width']]
    size, ring = 24, 4
    blocks = []
    for y in range(size):
        for x in range(size):
            if ring <= x < size-ring and ring <= y < size-ring:
                blocks.append(floor)
            else:
                donor = source[11 + 1 * layout['width']] if y < ring else floor
                blocks.append((donor & 1023) | 1024)
    rel = f'generated/{NAME}.bin'
    path = fm.TP / rel
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_bytes(struct.pack(f'<{size*size}H', *blocks))
    baked = fm.bake_layout(dict(layout, width=size, height=size, blockdata_filepath=rel))
    pad = fm.PAD
    bottom = Image.new('RGBA', ((size+pad*2)*16, (size+pad*2)*16), (0,0,0,255))
    bottom.alpha_composite(baked['bottom'], (pad*16,pad*16))
    top = baked['top']
    out = ar.ROOT / 'assets/maps' / NAME
    out.mkdir(parents=True, exist_ok=True)
    bottom.save(out/'bottom.png');top.save(out/'top.png')
    data = dict(width=size,height=size,tile=16,pad=pad,indoor=True,
                solid=[''.join('0' if ring<=x<size-ring and ring<=y<size-ring else '1' for x in range(size)) for y in range(size)],
                grass=['0'*size]*size,ledge=['0'*size]*size,start=[12*16+8,17*16+8],
                areas=[dict(id=NAME,x=0,y=0,w=size,h=size)],warps=[],
                arena=dict(surface='natural',style='room',wall_rows=4,player=[12,17],field=[4,4,16,16]),
                source='pret/pokefirered PokemonTower_3F; four brothers phantom battle')
    (out/'map.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
    preview=bottom.copy();preview.alpha_composite(top,(pad*16,pad*16));preview.save(out/'preview.png')
    print(NAME, '24×24; clear 16×16 combat field')

if __name__=='__main__':main()
