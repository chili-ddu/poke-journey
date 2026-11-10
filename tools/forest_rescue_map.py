"""Bake the square story battlefield from native Viridian Forest tiles.

Only the new map and native cut-tree object data are written. Existing outdoor
maps and trainer arenas are untouched. Run: python3 tools/forest_rescue_map.py
"""
import json
import struct
from PIL import Image

import frlg_arena as ar
import frlg_map as fm
import frlg_npc as npc
import field_cut_trees

NAME = "arena_forest_rescue"


def main():
    layout = fm.layout_of(fm.map_json("ViridianForest")["layout"])
    floor = ar.floor_block(layout, ar.blocks_of(layout))
    border, bw, bh = ar.border_blocks(layout)
    size, ring = 24, 4
    blocks = [floor if ring <= x < size-ring and ring <= y < size-ring
              else (border[x % bw + (y % bh)*bw] & 1023) | 1024
              for y in range(size) for x in range(size)]
    rel = f"generated/{NAME}.bin"
    generated=fm.TP / rel
    generated.parent.mkdir(parents=True,exist_ok=True)
    generated.write_bytes(struct.pack(f"<{size*size}H", *blocks))
    baked = fm.bake_layout(dict(layout, width=size, height=size, blockdata_filepath=rel))
    pad = fm.PAD
    bottom = Image.new("RGBA", ((size+2*pad)*16, (size+2*pad)*16), (0,0,0,255))
    bottom.alpha_composite(baked["bottom"], (pad*16,pad*16))
    top = baked["top"]
    fm.fill_borders(bottom, top, [(0,0,size,size,baked["border"])], size, size)
    out = ar.ROOT / "assets/maps" / NAME
    out.mkdir(parents=True, exist_ok=True)
    bottom.save(out / "bottom.png")
    top.save(out / "top.png")
    rows = ["".join("0" if ring <= x < size-ring and ring <= y < size-ring else "1"
                    for x in range(size)) for y in range(size)]
    data = dict(width=size,height=size,tile=16,pad=pad,solid=rows,
                grass=["0"*size]*size,ledge=["0"*size]*size,start=[12*16+8,15*16+8],
                areas=[dict(id=NAME,x=0,y=0,w=size,h=size)],warps=[],
                arena=dict(surface="natural",style="border",wall_rows=4,player=[12,15],field=[4,4,16,16]),
                source="pret/pokefirered ViridianForest; square rescue event field")
    (out / "map.json").write_text(json.dumps(data,ensure_ascii=False,indent=2)+"\n")
    preview=bottom.copy();preview.alpha_composite(top,(pad*16,pad*16));preview.save(out/"preview.png")

    trees=field_cut_trees.bake()
    source=Image.open(npc.fetch("graphics/object_events/pics/misc/cut_tree.png"))
    palette=npc.jasc(npc.fetch("graphics/object_events/palettes/npc_green.pal"))
    # Npc's shared renderers use 16x32 frames; preserve the native 16x16 art.
    tree=Image.new("RGBA",(16*9,32))
    for y in range(16):
        for x in range(16):
            index=source.getpixel((x,y))%16
            if index:
                for frame in range(9):tree.putpixel((frame*16+x,y+16),palette[index]+(255,))
    tree.save(ar.ROOT/"assets/npcs/cut_tree.png")
    print(NAME, "24x24; walkable field 16x16;",sum(map(len,trees.values())),"native cut trees")


if __name__=="__main__":
    main()
