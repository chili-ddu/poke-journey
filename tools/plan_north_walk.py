"""원본 충돌/워프와 자동 언덕 점프를 따라 3번도로→블루시티 실제 보행 계획을 만든다."""
import json
from collections import deque
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
NAMES=['kanto_north','mt_moon_1f','mt_moon_b1f','mt_moon_b2f']
DIRS=[(0,1,'s'),(1,0,'e'),(0,-1,'n'),(-1,0,'w')]
def plan(names=NAMES,start_point=("kanto_north",3,40),goal_point=("kanto_north",190,22)):
 maps={n:json.loads((ROOT/'assets/maps'/n/'map.json').read_text()) for n in names}
 alias={a['id']:n for n,j in maps.items() for a in j['areas']}
 solids={};warps={};targets={}
 for n,j in maps.items():
  solids[n]={(x,y) for y,r in enumerate(j['solid']) for x,c in enumerate(r) if c=='1'}
  patch=ROOT/'assets/maps'/n/'collision_patch.json'
  if patch.exists():
   p=json.loads(patch.read_text());solids[n].difference_update(map(tuple,p.get('open',[])));solids[n].update(map(tuple,p.get('block',[])))
  warps[n]={(w['x'],w['y']):w for w in j['warps']}
  for w in j['warps']:
   targets[w['map'],w['index']]=(n,w['x'],w['y'],True)
   if w['to'] not in alias:solids[n].add((w['x'],w['y']))
 def clear(n,x,y):
  j=maps[n];return 0<=x<j['width'] and 0<=y<j['height'] and (x,y) not in solids[n] and j['ledge'][y][x]=='0'
 start=(*start_point,False);goal=goal_point
 parents={start:None};q=deque([start]);end=None;jumps=0
 while q:
  state=q.popleft();n,x,y,arrival=state
  if (n,x,y)==goal:end=state;break
  warp=warps[n].get((x,y));nexts=[]
  if warp and not arrival:
   if warp['to'] in alias:nexts=[targets[warp['to'],warp['to_warp']]]
  else:
   for dx,dy,code in DIRS:
    a,b=x+dx,y+dy
    if clear(n,a,b):nexts.append((n,a,b,False));continue
    j=maps[n]
    if 0<=a<j['width'] and 0<=b<j['height'] and j['ledge'][b][a]==code and clear(n,x+2*dx,y+2*dy):nexts.append((n,x+2*dx,y+2*dy,False))
  for nxt in nexts:
   if nxt not in parents:parents[nxt]=state;q.append(nxt)
 assert end,('No native walking route',start_point,goal_point)
 path=[]
 while end is not None:path.append(end);end=parents[end]
 path.reverse();legs=[]
 for a,b in zip(path,path[1:]):
  if a[0]!=b[0]:legs.append(dict(place=a[0],goal=[a[1],a[2]],to=b[0]))
  elif abs(a[1]-b[1])+abs(a[2]-b[2])>1:jumps+=1
 legs.append(dict(place=goal[0],goal=list(goal[1:]),to=''))
 result=dict(start=list(start[:3]),walk_steps=len(path)-1,automatic_ledge_jumps=jumps,legs=legs)
 return result
if __name__=='__main__':
 result=plan();out=ROOT/'docs/kanto_expansion_review/north_walk_plan.json';out.write_text(json.dumps(result,indent=2));print(json.dumps(result))
