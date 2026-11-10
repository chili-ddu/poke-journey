"""Open the native Vermilion/Cinnabar barriers for leader-only challenges.

Apply the original SetBeamsOff/OpenDoor tile states, preserving all other tiles,
warp numbers, saved coordinates and the original cached source files.
"""
import json
import re
import struct
import tempfile
from pathlib import Path
from PIL import Image
import frlg_map as fm


def open_gates(source,labels_to_apply):
    key=fm.snake(source)
    script=fm.fetch(f"data/maps/{source}/scripts.inc").read_text()
    changes=[]
    for label in labels_to_apply:
        body=script.split(source+"_EventScript_"+label+"::",1)[1].split("\n\n",1)[0]
        changes.extend((int(x),int(y),tile,int(coll)) for x,y,tile,coll in re.findall(r"setmetatile\s+(\d+),\s*(\d+),\s*(\w+),\s*([01])",body))
    names=dict((name,int(value,16)) for name,value in re.findall(r"#define\s+(METATILE_\w+)\s+(0x[0-9A-Fa-f]+)",fm.fetch("include/constants/metatile_labels.h").read_text()))
    info=fm.map_json(source);layout=fm.layout_of(info["layout"])
    blocks=list(struct.unpack(f"<{layout['width']*layout['height']}H",fm.fetch(layout["blockdata_filepath"]).read_bytes()))
    for x,y,tile,coll in changes:
        index=y*layout["width"]+x
        blocks[index]=(blocks[index]&0xf000)|names[tile]|(coll<<10)
    original_fetch=fm.fetch
    with tempfile.TemporaryDirectory(prefix="poke-gym-tiles-") as temp:
        path=Path(temp)/"opened.bin";path.write_bytes(struct.pack(f"<{len(blocks)}H",*blocks))
        fm.fetch=lambda rel:path if rel==layout["blockdata_filepath"] else original_fetch(rel)
        try:render=fm.bake_layout(layout)
        finally:fm.fetch=original_fetch
    folder=fm.ROOT/"assets/maps"/key
    data=json.loads((folder/"map.json").read_text())
    bottom=Image.open(folder/"bottom.png").convert("RGBA")
    top=Image.open(folder/"top.png").convert("RGBA")
    solid=[list(row) for row in data["solid"]]
    pad=int(data.get("pad",0))*16
    for x,y,_,_ in changes:
        box=(x*16,y*16,(x+1)*16,(y+1)*16)
        bottom.paste(render["bottom"].crop(box),(x*16+pad,y*16+pad))
        top.paste(render["top"].crop(box),(x*16,y*16))
        solid[y][x]=str(render["solid"][y][x])
    bottom.save(folder/"bottom.png");top.save(folder/"top.png")
    data["solid"]=["".join(row) for row in solid]
    data["gym_open_gates"]=[[x,y] for x,y,_,_ in changes]
    (folder/"map.json").write_text(json.dumps(data,ensure_ascii=False,separators=(",",":"))+"\n")
    preview=bottom.copy();preview.alpha_composite(top,(pad,pad));preview.save(folder/"preview.png")
    print(key,"native open-state tiles",len(changes))


def main():
    open_gates("VermilionCity_Gym",["SetBeamsOff"])
    open_gates("CinnabarIsland_Gym",["OpenDoor"+str(i) for i in range(1,7)])


if __name__=="__main__":main()
