"""One-cell-deep cliff banks with shared straight/corner/end boundaries.
Source collision and regional elevations remain untouched.
"""
import json
import math
from pathlib import Path
from PIL import Image
from north_terrain import source_cells
from terrain_ground import pixels
ROOT=Path(__file__).resolve().parents[1]
RES=16
# Keep two source pixels of ground beyond the earth foot, including end ramps.
TOE_DEPTH=.875
CORNERS=[(0,0),(1,0),(1,1),(0,1)]
DIRS={'s':(0,1),'n':(0,-1),'e':(1,0),'w':(-1,0)}

def lerp(a,b,t):return a+(b-a)*t

def bilinear(c,u,v):return lerp(lerp(c[0],c[1],u),lerp(c[3],c[2],u),v)

def profile(t):
    # Broad turf shoulder and an eased earth bank, like the native low jump lip.
    t=max(0.,min(1.,(t-.25)/.6875))
    return t*t*(3-2*t)

def native_end_profile(raw, mids, pad):
    """Native B0's rounded lower outline, measured in the eight earth rows."""
    def tile(mid):
        x,y=next(xy for xy,v in sorted(mids.items()) if v==mid)
        return raw.crop(((x+pad)*16,(y+pad)*16,(x+pad+1)*16,(y+pad+1)*16))
    straight=tile(0x87)
    earth=set(pixels(straight.crop((0,9,16,16))))
    cap=tile(0xb0)
    return [max(0.,min(1.,(max(y for y in range(16) if cap.getpixel((x,y)) in earth)+1-8)/8)) for x in range(16)]

def native_rim_profile(art, direction, earth):
    """Small turf bites from the original face's first earth pixel in each column."""
    values=[]
    for along in range(16):
        def point(depth):
            if direction=='s':return along,depth
            if direction=='n':return along,15-depth
            if direction=='e':return depth,along
            return 15-depth,along
        depth=next((depth for depth in range(16) if art.getpixel(point(depth)) in earth),8)
        values.append(.22+.095*(max(8,min(10,depth))-8))
    # Vertex samples line up with the existing 16x16 ground tessellation. The
    # tile ends share one level, so the turf lip also joins turning pieces.
    return [.22]+[round((values[i-1]+values[i])*.5,5) for i in range(1,16)]+[.22]

def foot_profile(grid, direction, caps, end_profile):
    """Keep the earth's foot inside one plan depth even on eased side ramps."""
    res=len(grid)-1
    high=max(grid[0][0],grid[0][-1],grid[-1][-1],grid[-1][0])
    low=min(grid[0][0],grid[0][-1],grid[-1][-1],grid[-1][0])
    def cap(at):
        at=max(0.,min(15.,at*16-.5));index=int(at)
        return lerp(end_profile[index],end_profile[min(15,index+1)],at-index)
    depths=[];drops=[]
    for i in range(res+1):
        along=i/res
        shape=min(cap(along) if -1 in caps else 1.,cap(1-along) if 1 in caps else 1.)
        depth=TOE_DEPTH-.5*(1-shape)
        depths.append(round(depth,5))
        u,v=(along,depth) if direction=='s' else (along,1-depth) if direction=='n' else (depth,along) if direction=='e' else (1-depth,along)
        x=u*res;y=v*res;ix=min(int(x),res-1);iy=min(int(y),res-1)
        height=bilinear([grid[iy][ix],grid[iy][ix+1],grid[iy+1][ix+1],grid[iy+1][ix]],x-ix,y-iy)
        drops.append(round(max(0.,min(1.,(high-height)/max(high-low,1e-8))),7))
    return depths,drops

def build(name):
    d=ROOT/'assets/maps'/name
    from terrain_tile_audit import clean_floor
    clean_floor(name)
    j=json.loads((d/'map.json').read_text());e=json.loads((d/'elevation.json').read_text());w,h=j['width'],j['height']
    from terrain_topology import topology
    ledges,turns,mids=topology(j)
    band=set(ledges)|turns
    field=ROOT/'assets/maps/kanto_field'
    fj=json.loads((field/'map.json').read_text())
    fm=source_cells(fj,['Route1','Route2','Route3','Route4','Route5'])
    raw=Image.open(field/'bottom.png').convert('RGBA')
    pad=fj['pad']
    end_profile=native_end_profile(raw,fm,pad)
    from terrain_ground import tile as source_tile
    straight=source_tile(raw,next(xy for xy,mid in sorted(fm.items()) if mid==0x87),pad)
    earth=set(pixels(straight.crop((0,9,16,16))))
    regional_raw=Image.open(d/'bottom.png').convert('RGBA')
    corner_rim=native_rim_profile(straight,'s',earth)
    def original(x,y):return e['corners'][max(0,min(h-1,y))][max(0,min(w-1,x))]
    vertices={}
    for x,y in sorted(band):
        for u,v in CORNERS:
            key=(x+u,y+v)
            if key in vertices:continue
            outside=[];inside=[]
            for dx,dy,k in [(0,0,0),(-1,0,1),(-1,-1,2),(0,-1,3)]:
                tx,ty=key[0]+dx,key[1]+dy
                if not 0<=tx<w or not 0<=ty<h:continue
                (inside if (tx,ty) in band else outside).append(original(tx,ty)[k])
            if outside and max(outside)-min(outside)>1e-4:raise ValueError(('Conflicting exterior cliff corner',key,outside))
            values=outside or inside
            vertices[key]=sum(values)/len(values)
    tile_corners={xy:[vertices[x+u,y+v] for u,v in CORNERS] for xy in band for x,y in [xy]}
    kinds={}
    for xy in sorted(band):
        if xy in turns:
            kinds[xy]='inner' if mids.get(xy) not in {0x8d,0x8e} else 'outer'
        else:
            x,y=xy;code=ledges[xy];tx,ty=(1,0) if code in 'sn' else (0,1)
            joins=sum((x+tx*s,y+ty*s) in band for s in [-1,1])
            kinds[xy]='straight' if joins==2 else 'end'
    def base(xy,u,v):
        c=tile_corners[xy]
        if xy in ledges:
            code=ledges[xy]
            if code=='s':return lerp(lerp(c[0],c[1],u),lerp(c[3],c[2],u),profile(v))
            if code=='n':return lerp(lerp(c[3],c[2],u),lerp(c[0],c[1],u),profile(1-v))
            if code=='e':return lerp(lerp(c[0],c[3],v),lerp(c[1],c[2],v),profile(u))
            return lerp(lerp(c[1],c[2],v),lerp(c[0],c[3],v),profile(1-u))
        lo,hi=min(c),max(c);index=c.index(lo if kinds[xy]=='inner' else hi);cx,cy=CORNERS[index]
        def shaped(a,b):
            distance=math.hypot(a-cx,b-cy)
            t=profile(distance)
            return lerp(lo,hi,t) if kinds[xy]=='inner' else lerp(hi,lo,t)
        correction=[c[k]-shaped(a,b) for k,(a,b) in enumerate(CORNERS)]
        return shaped(u,v)+bilinear(correction,u,v)
    def edge(xy,side,t):
        x,y=xy
        if side=='n':u,v=t,0;neighbor=(x,y-1);nu,nv=t,1
        elif side=='s':u,v=t,1;neighbor=(x,y+1);nu,nv=t,0
        elif side=='w':u,v=0,t;neighbor=(x-1,y);nu,nv=1,t
        else:u,v=1,t;neighbor=(x+1,y);nu,nv=0,t
        own=base(xy,u,v)
        if neighbor not in band:return bilinear(original(*neighbor),nu,nv)
        other=base(neighbor,nu,nv)
        # A straight face supplies the mating edge of a turning piece.
        if xy in ledges and neighbor not in ledges:return own
        if neighbor in ledges and xy not in ledges:return other
        return (own+other)*.5
    patches=[]
    for xy in sorted(band):
        x,y=xy;c=tile_corners[xy];grid=[]
        bounds=[edge(xy,side,t/RES) for side in 'nswe' for t in range(RES+1)]
        lo,hi=min(bounds),max(bounds)
        for iy in range(RES+1):
            row=[];v=iy/RES
            for ix in range(RES+1):
                u=ix/RES
                # Transfinite correction preserves the chosen bank shape while
                # sharing all four boundaries with its neighbors exactly.
                value=base(xy,u,v)
                value+=(edge(xy,'n',u)-base(xy,u,0))*(1-v)+(edge(xy,'s',u)-base(xy,u,1))*v
                value+=(edge(xy,'w',v)-base(xy,0,v))*(1-u)+(edge(xy,'e',v)-base(xy,1,v))*u
                row.append(round(max(lo,min(hi,value)),5))
            grid.append(row)
        patch=dict(x=x,y=y,kind=kinds[xy],direction=ledges.get(xy,''),heights=grid,source_mid=mids.get(xy))
        patch['rim_top']=native_rim_profile(source_tile(regional_raw,xy,j['pad']),ledges[xy],earth) if xy in ledges else corner_rim
        patch['toe_level']=round(profile(TOE_DEPTH),7)
        if xy in ledges:
            tx,ty=(1,0) if ledges[xy] in 'sn' else (0,1)
            caps=[side for side in [-1,1] if (x+tx*side,y+ty*side) not in band]
            if caps:
                # Keep the full terrace height and shared mesh boundaries. Only
                # the exposed earth outline curls up into the grassy side ramp.
                patch['caps']=caps
            patch['toe_depth'],patch['toe_drop']=foot_profile(grid,ledges[xy],caps,end_profile)
        patches.append(patch)
    data=dict(version=5,resolution=RES,patches=patches,collision='native full-cell ledges and solid corner cells',profile='native uneven rim; restrained foot at fixed plan depth; circular elbows and raised end closures',uv='native earth pixels across the local drop; world-space horizontal blending at elbows')
    (d/'ledge_geometry.json').write_text(json.dumps(data,separators=(',',':'))+'\n')
    # Original grass and rock pixels, isolated from path borders and directional
    # ledge artwork. Both turn directions share one world-space rock material.
    def tile(xy):
        x,y=xy;return raw.crop(((x+pad)*16,(y+pad)*16,(x+pad+1)*16,(y+pad+1)*16))
    grass=tile(next(xy for xy,mid in sorted(fm.items()) if mid==8))
    rock=tile(next(xy for xy,mid in sorted(fm.items()) if mid==0x87)).crop((0,9,16,16)).resize((16,16),Image.Resampling.NEAREST)
    grass.save(d/'ledge_grass.png');rock.save(d/'ledge_rock.png')
    print(name,'cliff banks',len(ledges),'turns',len(turns),{k:sum(p['kind']==k for p in patches) for k in ['straight','end','outer','inner']})
    return data

if __name__=='__main__':
    import sys
    for name in sys.argv[1:] or ['kanto_field','kanto_east']:build(name)
