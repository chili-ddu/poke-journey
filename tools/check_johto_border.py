"""Check actual border tile routes, including directed ledge hops and surfing."""
import json
from collections import deque
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'assets/maps/johto_border_hgss'
manifest=json.loads((BASE/'manifest.json').read_text())


def scene(header):
    sid=manifest['header_scene'][str(header)]
    data=json.loads((ROOT/manifest['scene_paths'][sid].removeprefix('res://')).read_text())
    return data


def anchor(data,header,index):
    w=next(w for w in data['warps'] if w['header']==header and w['index']==index)
    return (w['x'],w['z'])


def route(data,start,goal,surf=True):
    chunks={(c['x'],c['z']):c for c in data['chunks']}
    portals={}
    for w in data['warps']:
        key=w['x'],w['z']
        if key not in portals or (not portals[key]['to'] and w['to']):portals[key]=w
    def attr(t):
        c=chunks.get((t[0]//32,t[1]//32))
        return c['attributes'][(t[1]%32)*32+t[0]%32] if c else 32768
    def clear(t):
        if t in portals:
            return t in [start,goal] and bool(portals[t]['to'])
        a=attr(t)
        return not a&32768 and (surf or a&255 not in [16,17,18,19,20,21,25,42]) and a&255 not in [56,57,58,59]
    queue=deque([start]);parents={start:None};action={}
    directions=[(0,-1),(0,1),(-1,0),(1,0)]
    ledges={56:(1,0),57:(-1,0),58:(0,-1),59:(0,1)}
    while queue and goal not in parents:
        at=queue.popleft()
        for d in directions:
            nxt=(at[0]+d[0],at[1]+d[1]);hop=False
            if attr(nxt)&255 in ledges:
                if ledges[attr(nxt)&255]!=d:continue
                nxt=(at[0]+2*d[0],at[1]+2*d[1]);hop=True
            if nxt in parents or not clear(nxt):continue
            parents[nxt]=at;action[nxt]=hop;queue.append(nxt)
    if goal not in parents: return []
    path=[];at=goal
    while at!=start:
        path.append({'tile':list(at),'hop':action[at]});at=parents[at]
    path.append({'tile':list(start),'hop':False})
    return path[::-1]


def run():
    main=scene(60);falls=scene(126);gate=scene(299)
    silver=next((c['x']*32+16,c['z']*32+16) for c in main['chunks'] if c['header']==90)
    # Prefer the native Silver entrance's open adjacent tile over a model's centre.
    silver_w=next(w for w in main['warps'] if w['header']==90)
    silver=(silver_w['x'],silver_w['z'])
    cases=[('new_bark_to_falls',60,(684,394),anchor(main,31,0)),
           ('falls_west_to_east',126,anchor(falls,126,0),anchor(falls,126,1)),
           ('route27_to_route26_gate',30,anchor(main,31,1),anchor(main,30,2)),
           ('gate_south_to_east',299,anchor(gate,299,0),anchor(gate,299,2)),
           ('gate_south_to_north',299,anchor(gate,299,0),anchor(gate,299,1)),
           ('gate_east_to_west',299,anchor(gate,299,2),anchor(gate,299,3)),
           ('route28_to_silver',32,anchor(main,32,0),silver)]
    records=[]
    for label,h,start,end in cases:
        for reverse in [False,True]:
            a,b=(end,start) if reverse else (start,end)
            path=route(scene(h),a,b)
            record={'id':label+('_reverse' if reverse else ''),'header':h,'start':list(a),'end':list(b),'path':path,'ok':bool(path)}
            records.append(record)
            print(record['id'],len(path),'steps',sum(p['hop'] for p in path),'hops')
    out=ROOT/'docs/johto_border';out.mkdir(exist_ok=True)
    (out/'routes.json').write_text(json.dumps({'surf_required':True,'routes':records},ensure_ascii=False,indent=2)+'\n')
    assert all(r['ok'] for r in records),'Disconnected native border path'
    print('Border tile navigation passed: all seven paths in both directions')

if __name__=='__main__': run()
