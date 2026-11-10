"""Terrace levels constrained across full impassable bank cells, including ends."""
from collections import defaultdict, deque
from terrain_topology import LEDGE_HEIGHT

class Union:
    def __init__(self,n):
        self.parent=list(range(n));self.rank=[0]*n;self.offset=[0.]*n
    def find(self,a):
        if self.parent[a]!=a:
            parent=self.parent[a];self.parent[a]=self.find(parent);self.offset[a]+=self.offset[parent]
        return self.parent[a]
    def join(self,a,b,difference=0.):
        ra,rb=self.find(a),self.find(b);da,db=self.offset[a],self.offset[b]
        if ra==rb:
            if abs(da-db-difference)>1e-6:raise ValueError(('Contradictory terrace levels',a,b,da-db,difference))
            return
        if self.rank[ra]<self.rank[rb]:
            self.parent[ra]=rb;self.offset[ra]=difference-da+db
        else:
            self.parent[rb]=ra;self.offset[rb]=-difference+da-db
            if self.rank[ra]==self.rank[rb]:self.rank[ra]+=1

def solve(j,water,houses,cells,band):
    w,h=j['width'],j['height'];union=Union(w*h*4)
    valid={(x,y) for a in j['areas'] for y in range(a['y'],a['y']+a['h']) for x in range(a['x'],a['x']+a['w'])}
    normal=valid-band
    def node(x,y,k):return (y*w+x)*4+k
    def merge(nodes):
        if nodes:
            for v in nodes[1:]:union.join(nodes[0],v)
    # Ordinary ground shares geometric vertices. A bank is NOT an ordinary
    # ground tile with a discontinuity at its downhill edge.
    at_vertex=defaultdict(list)
    for x,y in sorted(normal):
        for k,(u,v) in enumerate([(0,0),(1,0),(1,1),(0,1)]):at_vertex[x+u,y+v].append(node(x,y,k))
    for values in at_vertex.values():merge(values)
    for x,y in sorted(normal):
        if water[y][x]=='1':merge([node(x,y,k) for k in range(4)])
    for a in j['areas']:
        if a['id'].startswith('route') or any(a['x']<=x<a['x']+a['w'] and a['y']<=y<a['y']+a['h'] for x,y in band):continue
        merge([node(x,y,k) for y in range(a['y'],a['y']+a['h']) for x in range(a['x'],a['x']+a['w']) if (x,y) in normal for k in range(4)])
    for b in houses:
        footprint={(x,y) for y in range(max(0,int(b['z']-b['d'])),min(h,int(b['z']))) for x in range(max(0,int(b['x'])),min(w,int(b['x']+b['w'])))}
        if footprint & band:continue
        merge([node(x,y,k) for x,y in sorted(footprint & normal) for k in range(4)])
    # A native ledge can end at a flat lake (Route 22). Its shared shoreline
    # corner is an end ramp, not a second constraint lifting the entire lake.
    water_roots={union.find(node(x,y,k)) for x,y in normal if water[y][x]=='1' for k in range(4)} if j.get('world_parts') else set()
    pending=set(band);networks=[];shore_end_ramps=0
    directions={'s':([(0,0),(1,0)],[(0,1),(1,1)]),'n':([(0,1),(1,1)],[(0,0),(1,0)]),'e':([(0,0),(0,1)],[(1,0),(1,1)]),'w':([(1,0),(1,1)],[(0,0),(0,1)])}
    while pending:
        first=min(pending);pending.remove(first);queue=[first];group=[]
        while queue:
            x,y=queue.pop();group.append((x,y))
            for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
                if p in pending:pending.remove(p);queue.append(p)
        high=[];low=[]
        for x,y in group:
            if (x,y) not in cells:continue
            upper,lower=directions[cells[x,y]]
            for target,points in [(high,upper),(low,lower)]:
                for u,v in points:target.extend(at_vertex.get((x+u,y+v),[]))
            dx,dy={"s":(0,1),"n":(0,-1),"e":(1,0),"w":(-1,0)}[cells[x,y]]
            # The first walkable landing tiles belong to their terrace, not to
            # the curved transition through the blocked bank.
            for target,sign in [(high,-1),(low,1)]:
                px,py=x+dx*sign,y+dy*sign
                if (px,py) in normal and j['solid'][py][px]=='0' and water[py][px]=='0':
                    target.extend(node(px,py,k) for k in range(4))
        if water_roots:
            before=len(high)+len(low)
            high=[v for v in high if union.find(v) not in water_roots]
            low=[v for v in low if union.find(v) not in water_roots]
            shore_end_ramps+=before-len(high)-len(low)
        if high and low:
            merge(high);merge(low)
            # Exactly one level across the complete connected cliff bank. End
            # points no longer collapse high and low onto the same vertex.
            try:union.join(high[0],low[0],LEDGE_HEIGHT)
            except ValueError as error:raise ValueError((str(error), 'bank', sorted(group)))
            networks.append((group,high[0],low[0]))
    ids={}
    def term(v):
        root=union.find(v)
        if root not in ids:ids[root]=len(ids)
        return ids[root],union.offset[v]
    weights=defaultdict(float);targets=defaultdict(float)
    def edge(a,b):
        a,da=term(a);b,db=term(b)
        if a==b:return
        difference=db-da
        if a>b:a,b=b,a;difference=-difference
        weights[a,b]+=1.;targets[a,b]+=difference
    for x,y in sorted(normal):
        for a,b in [(0,1),(1,2),(2,3),(3,0)]:edge(node(x,y,a),node(x,y,b))
    base=next((a for a in j['areas'] if a['id'] in ('pallet_town','vermilion_city')),j['areas'][0])
    anchor,anchor_offset=term(node(base['x']+base['w']//2,base['y']+base['h']//2,0))
    n=len(ids);diag=[0.]*n;rhs=[0.]*n;links=[]
    for (a,b),weight in weights.items():
        diag[a]+=weight;diag[b]+=weight;rhs[a]+=targets[a,b];rhs[b]-=targets[a,b];links.append((a,b,weight))
    diag[anchor]+=100.;rhs[anchor]-=100.*anchor_offset
    def multiply(values):
        out=[diag[i]*values[i] for i in range(n)]
        for a,b,weight in links:out[a]-=weight*values[b];out[b]-=weight*values[a]
        return out
    result=[0.]*n;r=rhs[:];z=[r[i]/diag[i] if diag[i] else 0 for i in range(n)];p=z[:];rz=sum(a*b for a,b in zip(r,z));iterations=0
    for iteration in range(4000):
        ap=multiply(p);den=sum(a*b for a,b in zip(p,ap))
        if abs(den)<1e-25:break
        alpha=rz/den
        for i in range(n):result[i]+=alpha*p[i];r[i]-=alpha*ap[i]
        iterations=iteration+1
        if max(abs(v) for v in r)<1e-6:break
        z=[r[i]/diag[i] if diag[i] else 0 for i in range(n)];new_rz=sum(a*b for a,b in zip(r,z));beta=new_rz/rz;p=[z[i]+beta*p[i] for i in range(n)];rz=new_rz
    else:raise RuntimeError('Terrace height solver did not converge')
    def height(v):
        i,delta=term(v);return result[i]+delta
    shared={point:height(values[0]) for point,values in at_vertex.items()}
    nearest=dict(shared);queue=deque(shared)
    while queue:
        x,y=queue.popleft()
        for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if 0<=p[0]<=w and 0<=p[1]<=h and p not in nearest:nearest[p]=nearest[x,y];queue.append(p)
    offset=min(0.,min(shared.values()))
    corners=[[[round(nearest[x+u,y+v]-offset,5) for u,v in [(0,0),(1,0),(1,1),(0,1)]] for x in range(w)] for y in range(h)]
    levels=[dict(cells=[[x,y] for x,y in sorted(group)],upper=round(height(high)-offset,5),lower=round(height(low)-offset,5)) for group,high,low in networks]
    return corners,dict(method='full_cell_terrace_levels',variables=n,iterations=iterations,residual=max(abs(v) for v in r),reference=base['id'],banks=levels,shore_end_ramps=shore_end_ramps)
