"""Find native-board push solutions; entrance components represent stair travel.

Only player walking is fast-forwarded by review/tests. Every listed push still
passes through the real Space interaction, collision, animation and fall code.
"""
from collections import deque
import json
from pathlib import Path

ROOT=Path(__file__).resolve().parents[1]
DIRS=[(0,-1),(1,0),(0,1),(-1,0)]

def add(a,b):return a[0]+b[0],a[1]+b[1]

def solve(floor,objects,holes,targets):
    metadata=json.loads((ROOT/'assets/maps'/floor/'map.json').read_text())
    native=json.loads((ROOT/'assets/data/seafoam_puzzle.json').read_text())['floors'][floor]
    hole_set={tuple(h['tile']) for h in native['holes']}
    ports={(w['x'],w['y']) for w in metadata['warps'] if (w['x'],w['y']) not in hole_set}
    # Falling-only arrival points are floor, not exits that teleport upward.
    walk={(x,y) for y,row in enumerate(metadata['solid']) for x,c in enumerate(row) if c=='0'}
    water=json.loads((ROOT/'assets/maps'/floor/'water.json').read_text())['water']
    walk-={(x,y) for y,row in enumerate(water) for x,c in enumerate(row) if c=='1'}
    walk-=hole_set
    rock_floor=walk|hole_set
    flags=list(objects);start=tuple(tuple(objects[k]) for k in flags)
    def reachable_from(player,boxes):
        occupied={p for p in boxes if p is not None}
        reachable={player};todo=[player];joined=False
        for at in todo:
            if at in ports and not joined:
                joined=True
                for port in ports&walk-occupied:
                    if port not in reachable:reachable.add(port);todo.append(port)
            for d in DIRS:
                other=add(at,d)
                if other in walk and other not in occupied and other not in reachable:reachable.add(other);todo.append(other)
        return reachable
    player=next(iter(ports&walk-set(start)))
    initial=(start,min(reachable_from(player,start)))
    queue=deque([(initial,player)]);previous={initial:None};actions={}
    while queue:
        state,player=queue.popleft();boxes=state[0];occupied={p for p in boxes if p is not None}
        reachable=reachable_from(player,boxes)
        if all(boxes[flags.index(flag)] is None for flag in targets):
            result=[]
            while previous[state] is not None:result.append(actions[state]);state=previous[state]
            return list(reversed(result)),len(previous)
        for i,at in enumerate(boxes):
            if at is None:continue
            for d in DIRS:
                stance=add(at,(-d[0],-d[1]));to=add(at,d)
                if stance not in reachable or to not in rock_floor or to in occupied:continue
                # Stair tiles accept players, never pushed boulders.
                if to in ports:continue
                new_boxes=list(boxes);new_boxes[i]=None if to in hole_set else to;new_boxes=tuple(new_boxes)
                new=(new_boxes,min(reachable_from(at,new_boxes)))
                if new in previous:continue
                previous[new]=state;actions[new]={'stage':flags[i],'from':list(at),'direction':list(d),'stand':list(stance),'to':list(to)};queue.append((new,at))
        if len(previous)>500000:raise RuntimeError('Search budget exceeded: '+floor)
    raise RuntimeError('No native puzzle solution: '+floor)

def main():
    data=json.loads((ROOT/'assets/data/seafoam_puzzle.json').read_text());solutions={}
    for floor,meta in data['floors'].items():
        objects={flag:data['objects'][flag]['tile'] for flag in meta['objects'] if data['objects'][flag]['pushable']}
        targets=[flag for flag in objects if data['objects'][flag]['reveal']]
        if not targets:continue
        solution,states=solve(floor,objects,meta['holes'],targets)
        solutions[floor]=solution
        print(floor,len(solution),'pushes;',states,'board states checked')
    out=ROOT/'docs/seafoam_puzzle';out.mkdir(parents=True,exist_ok=True)
    content=json.dumps(solutions,indent=2)+'\n'
    (out/'solutions.json').write_text(content)
    fixtures=ROOT/'test/fixtures';fixtures.mkdir(parents=True,exist_ok=True)
    (fixtures/'seafoam_puzzle_solutions.json').write_text(content)

if __name__=='__main__':main()
