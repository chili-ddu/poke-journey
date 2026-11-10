import json,sys,collections
sys.path.insert(0,'tools')
import kanto_expansion as k,frlg_map as f
import saffron_access
import route11_diglett
maps={n:k.load(n) for n in ['kanto_field','kanto_east','vermilion_harbor','cerulean_north','route25_sea_cottage','forest_gate_north','forest_gate_south','viridian_forest']+[f.snake(x) for x in k.SINGLES+saffron_access.FOLDERS+route11_diglett.FOLDERS]}
alias={a['id']:n for n,j in maps.items() for a in j['areas']}
solids={}
for n,j in maps.items():
 s={(x,y) for y,r in enumerate(j['solid']) for x,c in enumerate(r) if c=='1'}
 p=f.ROOT/'assets/maps'/n/'collision_patch.json'
 if p.exists():
  patch=json.loads(p.read_text());s.difference_update(map(tuple,patch.get('open',[])));s.update(map(tuple,patch.get('block',[])))
 for w in j['warps']:
  if w['to'] not in alias: s.add((w['x'],w['y']))
 solids[n]=s
for n,j in maps.items():
 for w in j['warps']:
  if w['to'] not in alias:continue
  dest=maps[alias[w['to']]]
  target=[a for a in dest['warps'] if a['map']==w['to'] and a['index']==w['to_warp']]
  assert target,(n,w)
  assert (w['x'],w['y']) not in solids[n],('blocked warp',n,w)
print('All registered warp destinations and collisions valid')
# Global graph respects source impassable cells. Ledges may be jumped in-game and are included explicitly.
start=('kanto_field',45,40)
seen={start};q=collections.deque([start]);warpat={n:{(w['x'],w['y']):w for w in j['warps']} for n,j in maps.items()}
while q:
 n,x,y=q.popleft();j=maps[n]
 nexts=[(n,x+dx,y+dy) for dx,dy in [(0,1),(0,-1),(1,0),(-1,0)]]
 w=warpat[n].get((x,y))
 if w and w['to'] in alias:
  dn=alias[w['to']];dw=next(a for a in maps[dn]['warps'] if a['map']==w['to'] and a['index']==w['to_warp']);nexts.append((dn,dw['x'],dw['y']))
 for p in nexts:
  nn,xx,yy=p;jj=maps[nn]
  if p not in seen and 0<=xx<jj['width'] and 0<=yy<jj['height'] and ((xx,yy) not in solids[nn] or jj.get('ledge',[])[yy][xx]!='0'):
   seen.add(p);q.append(p)
for n,j in maps.items():
 reached=sum(1 for a in seen if a[0]==n);print(n,reached)
 assert reached,('unreachable map',n)
for n in ['kanto_field','kanto_east','cerulean_north','forest_gate_north','forest_gate_south','viridian_forest']:
 for a in maps[n]['areas']:assert any(nn==n and a['x']<=x<a['x']+a['w'] and a['y']<=y<a['y']+a['h'] for nn,x,y in seen),('unreachable area',a)
print('All expanded maps reachable from Pewter')
