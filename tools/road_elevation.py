"""Bake globally connected elevations from native ledge direction/footprints.
Run after kanto_seamless.py; source maps and collision stay unchanged.
"""
import json
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DIRS={'s':(0,1),'n':(0,-1),'e':(1,0),'w':(-1,0)}

def bake(name):
    d=ROOT/'assets/maps'/name
    j=json.loads((d/'map.json').read_text());w,h=j['width'],j['height'];pad=j['pad']
    roads=[a for a in j['areas'] if a['id'] in {f'route{i}' for i in range(1,7)}]
    from terrain_topology import topology, LEDGE_HEIGHT
    cells,turns,_=topology(j)
    runs=[];pending=set(cells)
    while pending:
        x,y=min(pending);code=cells[x,y];dx,dy=DIRS[code];tx,ty=(1,0) if dy else (0,1)
        start=(x,y)
        while (start[0]-tx,start[1]-ty) in pending and cells[start[0]-tx,start[1]-ty]==code:start=(start[0]-tx,start[1]-ty)
        end=start;length=0
        while end in pending and cells[end]==code:
            pending.remove(end);length+=1;end=(end[0]+tx,end[1]+ty)
        plane=(start[1]+(1 if dy>0 else 0)) if dy else (start[0]+(1 if dx>0 else 0))
        runs.append((dx,dy,plane,start[0] if dy else start[1],length))
    water_path=d/'water.json';water=json.loads(water_path.read_text())['water'] if water_path.exists() else ['0'*w for _ in range(h)]
    cards=json.loads((d/'hd2d_cards.json').read_text())
    from region_height_solver import solve
    corners,solver=solve(j,water,cards.get('houses',[]),cells,set(cells)|turns)
    data=dict(version=3,solver=solver,corners=corners,ledges=[[x,y,code] for (x,y),code in sorted(cells.items())],height=LEDGE_HEIGHT,roads=[a['id'] for a in roads])
    (d/'elevation.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
    from ledge_geometry import build as ledge_geometry
    ledge_geometry(name)
    print(name,len(cells),'ledge cells',len(runs),'ledge runs',max(max(max(c) for c in row) for row in corners),'max height')

if __name__=='__main__':
    for name in ['kanto_field','kanto_east']:bake(name)
