"""Bake one native-grid passing pose per original Pokémon frame interval.

This processes existing pixels, not image/video model output. Source PNG/XML
files are never edited. The runtime keeps its original clock and battle keys.
The approved Charmander study is adopted exactly where its source hash agrees.
Wing/serpent motion and unsafe flow use rigid source poses instead of warping.
"""
from pathlib import Path
from collections import Counter
from concurrent.futures import ProcessPoolExecutor, as_completed
import argparse
import hashlib
import json
import math
import xml.etree.ElementTree as ET
import cv2
import numpy as np
from PIL import Image
from bake_smooth_sprites import discover

ROOT = Path(__file__).resolve().parents[1]
REVIEW = ROOT/'docs/pokemon_2x_rollout'
OUT = ROOT/'assets/motion_2x'
VERSION = 3
cv2.setNumThreads(1)
SPECIES = {int(v['dex']):dict(v, sid=k) for k,v in json.loads((ROOT/'assets/data/species.json').read_text()).items()}
APPROVED = ROOT/'docs/charmander_2x_motion_polish'
STUDY = json.loads((APPROVED/'study.json').read_text())
DECISIONS = {(d['action'],d['row'],d['source_frame']):d for d in json.loads((APPROVED/'decisions.json').read_text())}
# Long linked bodies must retain every source segment, including tiny tail tips.
RIGID_DEX = {23,24,95,130,148,149,208,350,384,487}
FLIGHT_ACTIONS = {'Walk','Hover','FlapAround','SpAttack'}
ATTACKS = {'Attack','Strike','Kick','Swing','Double','Jab','Slice','Charge','SpAttack','Shoot'}


def sha(path): return hashlib.sha256(path.read_bytes()).hexdigest()


def marker(cell, color):
    yy,xx = np.where(np.all(cell == [*color,255], axis=-1))
    return np.array([xx[0],yy[0]], dtype=float) if len(xx) else None


def shift(a, delta):
    h,w = a.shape[:2]
    return cv2.warpAffine(a,np.float32([[1,0,delta[0]],[0,1,delta[1]]]),(w,h),flags=cv2.INTER_NEAREST)


def count(a): return int(np.count_nonzero(a[...,3]))
def parts(a): return cv2.connectedComponents((a[...,3]>0).astype('uint8'),8)[0]-1


def gray(a):
    alpha=a[...,3:4].astype(np.float32)/255
    return cv2.cvtColor((a[...,:3]*alpha+96*(1-alpha)).astype('uint8'),cv2.COLOR_RGB2GRAY)


def rgb32(a):
    v=a.astype(np.uint32)
    return (v[...,0]<<16)|(v[...,1]<<8)|v[...,2]


def transfer_shiny(source,path,spec,node,signature,key,report):
    """Reuse verified geometry, recolouring with this species' actual shiny.

    Only exact alpha/registration and an unambiguous full-sheet colour map
    qualify. Different shiny drawings/timings take the ordinary native route.
    """
    normal_path=path.replace('/shiny/','/')
    normal_file=ROOT/normal_path
    cache=REVIEW/'bake-cache'/f'{hashlib.sha256(normal_path.encode()).hexdigest()[:20]}.json'
    if not cache.exists() or not normal_file.exists():return None
    normal=json.loads(cache.read_text())
    if normal['source_sha256']!=sha(normal_file):return None
    if set(normal['entry']['pairs'])!={','.join(map(str,[*a,*b])) for a,b in spec['pairs']}:return None
    name=source.name.removesuffix('-Anim.png')
    normal_node=next(a for a in ET.parse(normal_file.with_name('AnimData.xml')).findall('.//Anim') if a.findtext('Name')==name)
    for tag in ['FrameWidth','FrameHeight','HitFrame','RushFrame','ReturnFrame']:
        if node.findtext(tag)!=normal_node.findtext(tag):return None
    if [x.text for x in node.findall('./Durations/Duration')]!=[x.text for x in normal_node.findall('./Durations/Duration')]:return None
    a=np.array(Image.open(normal_file).convert('RGBA'));b=np.array(Image.open(source).convert('RGBA'))
    if a.shape!=b.shape or not np.array_equal(a[...,3],b[...,3]):return None
    mask=a[...,3]>0
    mapping=np.unique((rgb32(a)[mask].astype(np.uint64)<<24)|rgb32(b)[mask].astype(np.uint64))
    old=(mapping>>24).astype(np.uint32);new=(mapping&0xffffff).astype(np.uint32)
    if len(np.unique(old))!=len(old):return None
    entry=dict(normal['entry']);atlas=np.array(Image.open(ROOT/entry['sheet'].removeprefix('res://')).convert('RGBA'))
    opaque=atlas[...,3]>0;colors=rgb32(atlas)[opaque];indices=np.searchsorted(old,colors)
    if np.any(indices>=len(old)) or not np.array_equal(old[indices],colors):return None
    colors=new[indices];atlas[opaque,:3]=np.stack([(colors>>16)&255,(colors>>8)&255,colors&255],axis=-1).astype('uint8')
    dest=OUT/f'{key}.png';Image.fromarray(atlas).save(dest,compress_level=3)
    entry.update(hash=signature,sheet='res://'+str(dest.relative_to(ROOT)))
    off=source.with_name(name+'-Offsets.png')
    # Marker geometry must agree as well, otherwise attachment anchors differ.
    normal_off=normal_file.with_name(off.name)
    if off.exists() and normal_off.exists() and off.read_bytes()!=normal_off.read_bytes():
        x=np.array(Image.open(off).convert('RGBA'));y=np.array(Image.open(normal_off).convert('RGBA'))
        if not np.array_equal(x,y):return None
    result=dict(normal,source='res://'+path,source_sha256=sha(source),offsets_sha256=sha(off) if off.exists() else None,
        shiny=True,entry=entry,methods={'verified_shiny_palette_transfer':len(entry['pairs'])},geometry_source=normal['source'])
    report.write_text(json.dumps(result,separators=(',',':')))
    return result


def timing(name, node, k, n):
    phase,hold=.5,.5
    hit=int(node.findtext('HitFrame') or '-1');rush=int(node.findtext('RushFrame') or '-1');ret=int(node.findtext('ReturnFrame') or '-1')
    if name in ATTACKS:
        if k==hit: phase,hold=.25,.75
        elif k==hit-1: phase,hold=.75,.67
        elif k==rush: phase,hold=.25,.67
        elif ret>=0 and k>=ret: phase,hold=.75,.4
    elif name in {'Hurt','Pain','Cringe'} and k==0: phase,hold=.25,.67
    # Whole original key onsets stay fixed; split its interval at 120 Hz.
    duration=int(node.findall('./Durations/Duration')[k].text)
    if duration>=2: hold=float(np.clip(round(duration*hold),1,duration-1))/duration
    else: hold=.5
    return phase,hold


def native_mid(a,b,head_a,head_b,torso_a,torso_b,phase,rigid):
    hd=np.rint((head_b-head_a)*phase).astype(int)
    td=np.rint((torso_b-torso_a)*phase).astype(int)
    if np.array_equal(a,b): return a.copy(),[0,0,0,0],'identical_source'
    if not count(a) or not count(b):return a.copy(),[0,0,0,0],'empty_source_hold'
    rigid_pose=shift(a,hd)
    if count(rigid_pose)!=count(a):return a.copy(),[0,0,0,0],'canvas_guard_hold'
    if rigid or np.linalg.norm(head_b-head_a)>=6:
        return rigid_pose,[*hd,*hd],'rigid_source_pose'
    h,w=a.shape[:2]
    # DIS requires a small minimum image size; padding is temporary, never a
    # rescale and never changes the source registration or exported canvas.
    pad=16
    aa=cv2.copyMakeBorder(a,pad,pad,pad,pad,cv2.BORDER_CONSTANT,value=(0,0,0,0))
    bb=cv2.copyMakeBorder(b,pad,pad,pad,pad,cv2.BORDER_CONSTANT,value=(0,0,0,0))
    flow=cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_FAST)
    flow.setFinestScale(0)
    ab=flow.calc(gray(aa),gray(bb),None)[pad:pad+h,pad:pad+w]
    yy,xx=np.mgrid[:h,:w].astype(np.float32)
    out=cv2.remap(a,xx-ab[...,0]*phase,yy-ab[...,1]*phase,cv2.INTER_NEAREST,borderMode=cv2.BORDER_CONSTANT)
    ay,ax=np.where(a[...,3]>0);by,bx=np.where(b[...,3]>0)
    # Preserve the facial cluster as intact pixels around its authored head
    # marker, rather than imposing Charmander's upper-half mask on every body.
    rx=max(4,min(10,int((ax.max()-ax.min()+1)*.24)))
    ry=max(4,min(9,int((ay.max()-ay.min()+1)*.22)))
    face=(np.abs(xx-(head_a[0]+hd[0]))<=rx)&(np.abs(yy-(head_a[1]+hd[1]))<=ry)
    out[face]=rigid_pose[face]
    bounds=(xx>=min(ax.min(),bx.min()))&(xx<=max(ax.max(),bx.max()))&(yy>=min(ay.min(),by.min()))&(yy<=max(ay.max(),by.max()))
    out[~bounds]=0
    # Reject missing mass, disconnected new limbs and new clipped extremities.
    if not .92*min(count(a),count(b)) <= count(out) <= 1.08*max(count(a),count(b)):
        return rigid_pose,[*hd,*hd],'area_guard_rigid'
    if parts(out)>max(parts(a),parts(b)):
        return rigid_pose,[*hd,*hd],'component_guard_rigid'
    border=lambda p: int(np.count_nonzero(p[0,:,3])+np.count_nonzero(p[-1,:,3])+np.count_nonzero(p[:,0,3])+np.count_nonzero(p[:,-1,3]))
    if border(out)>max(border(a),border(b)):
        return rigid_pose,[*hd,*hd],'edge_guard_rigid'
    return out,[*hd,*td],'native_pixel_transport'


def bake(job):
    path,spec=job
    source=ROOT/path
    relative=source.relative_to(ROOT/'assets/sprites')
    dex=int(relative.parts[0]);shiny='shiny' in relative.parts
    name=source.name.removesuffix('-Anim.png')
    xml=source.with_name('AnimData.xml');off=source.with_name(name+'-Offsets.png')
    node=next(a for a in ET.parse(xml).findall('.//Anim') if a.findtext('Name')==name)
    w,h=spec['size'];n=len(node.findall('./Durations/Duration'))
    approved=STUDY['actions'].get(name) if dex==4 and not shiny else None
    if approved and approved['source_sha256']!=sha(source): approved=None
    # Include inputs and the accepted study in the cache contract.
    signature=hashlib.sha256(source.read_bytes()+xml.read_bytes()+(off.read_bytes() if off.exists() else b'')+
        json.dumps([VERSION,spec,STUDY['actions'].get(name) if approved else None],sort_keys=True).encode()).hexdigest()
    key=hashlib.sha256(path.encode()).hexdigest()[:20]
    report=REVIEW/'bake-cache'/f'{key}.json'
    if report.exists():
        previous=json.loads(report.read_text())
        if previous['entry']['hash']==signature and (ROOT/previous['entry']['sheet'].removeprefix('res://')).exists():return previous
    if shiny:
        transferred=transfer_shiny(source,path,spec,node,signature,key,report)
        if transferred is not None:return transferred
    raw=np.array(Image.open(source).convert('RGBA'));rows=raw.shape[0]//h
    offsets=np.array(Image.open(off).convert('RGBA')) if off.exists() else None
    cells={};heads={};torsos={}
    for r in range(rows):
        for k in range(n):
            at=(k*w,r*h);cells[at]=raw[r*h:(r+1)*h,k*w:(k+1)*w].copy()
            oc=offsets[r*h:(r+1)*h,k*w:(k+1)*w] if offsets is not None else None
            heads[at]=marker(oc,(0,0,0)) if oc is not None else None
            if heads[at] is None:heads[at]=np.array([w/2,h/2])
            torsos[at]=marker(oc,(0,255,0)) if oc is not None else None
            if torsos[at] is None:torsos[at]=heads[at]
    frames=[];slots={};pairs={};holds={};weights={};deltas={};methods=Counter();unique=0;warnings=[]
    rigid=dex in RIGID_DEX or ('flying' in SPECIES.get(dex,{}).get('types',[]) and name in FLIGHT_ACTIONS)
    for first,last in spec['pairs']:
        first,last=tuple(first),tuple(last)
        if first not in cells or last not in cells:
            warnings.append(dict(first=first,last=last,reason='invalid_custom_pair'));continue
        k=first[0]//w;r=first[1]//h
        adjacent=last[0]//w==(k+1)%n and first[1]==last[1]
        phase,hold=timing(name,node,k,n) if adjacent else (.5,.5)
        if approved and adjacent:
            decision=DECISIONS[(name,r,k)]
            midpath=APPROVED/'frames'/name/f'row-{r}'/'refined'/f'{2*k+1:03}.png'
            out=np.array(Image.open(midpath).convert('RGBA'))
            phase=float(decision['requested_phase']);ticks=approved['refined_ticks'][2*k:2*k+2];hold=ticks[0]/sum(ticks)
            hd=np.rint((heads[last]-heads[first])*phase).astype(int);td=np.rint((torsos[last]-torsos[first])*phase).astype(int)
            delta=[*hd,*td];method='approved_charmander'
            # The retained final pose must keep its source anchor too.
            if np.array_equal(out,cells[first]):delta=[0,0,0,0]
        else:
            out,delta,method=native_mid(cells[first],cells[last],heads[first],heads[last],torsos[first],torsos[last],phase,rigid or not adjacent)
        assert out.shape==(h,w,4)
        assert set(np.unique(out[...,3])).issubset({0,255}),source
        pixelkey=hashlib.sha256(out.tobytes()).digest()
        if pixelkey not in slots:slots[pixelkey]=len(frames);frames.append(out)
        pair=','.join(map(str,[*first,*last]));pairs[pair]=slots[pixelkey];holds[pair]=hold;weights[pair]=phase;deltas[pair]=[int(x) for x in delta]
        methods[method]+=1
        unique+=int(not np.array_equal(out,cells[first]) and not np.array_equal(out,cells[last]))
    if not frames:frames=[cells[(0,0)]]
    cols=max(1,min(4096//w,math.ceil(math.sqrt(len(frames)*h/w))))
    sheet=Image.new('RGBA',(cols*w,math.ceil(len(frames)/cols)*h))
    assert max(sheet.size)<=8192,(source,sheet.size)
    for i,frame in enumerate(frames):sheet.paste(Image.fromarray(frame),((i%cols)*w,(i//cols)*h))
    dest=OUT/f'{key}.png';sheet.save(dest,compress_level=3)
    entry=dict(hash=signature,sheet='res://'+str(dest.relative_to(ROOT)),size=[w,h],cols=cols,steps=2,pairs=pairs,holds=holds,weights=weights,deltas=deltas)
    result=dict(source='res://'+path,source_sha256=sha(source),offsets_sha256=sha(off) if off.exists() else None,
        dex=dex,shiny=shiny,action=name,rows=rows,keys=n*rows,pairs=len(pairs),new_distinct_poses=unique,
        methods=dict(methods),warnings=warnings,entry=entry)
    report.write_text(json.dumps(result,separators=(',',':')))
    return result


def attach_native_anchors(record):
    """Export the original sparse markers, avoiding per-pixel GDScript scans."""
    e=record['entry'];w,h=e['size'];rows=record['rows'];n=record['keys']//rows
    source=ROOT/record['source'].removeprefix('res://')
    off=source.with_name(source.name.replace('-Anim.png','-Offsets.png'))
    name=source.name.removesuffix('-Anim.png')
    node=next(a for a in ET.parse(source.with_name('AnimData.xml')).findall('.//Anim') if a.findtext('Name')==name)
    e['source_ticks']=[int(v.text) for v in node.findall('./Durations/Duration')]
    # One 60-Hz tick has exactly two half-tick slots; neither may be empty.
    for pair in e['holds']:
        if e['source_ticks'][int(pair.split(',')[0])//w]==1:e['holds'][pair]=.5
    markers={}
    if off.exists():
        a=np.array(Image.open(off).convert('RGBA'));yy,xx=np.where(a[...,3]>127)
        for y,x in zip(yy,xx):
            row,col=int(y)//h,int(x)//w
            if row>=rows or col>=n:continue
            r,g,b=map(int,a[y,x,:3]);color='black' if max(r,g,b)<26 else 'green' if g>229 and max(r,b)<26 else 'blue' if b>229 and max(r,g)<26 else ''
            if color:markers.setdefault((row,col,color),[int(x)%w,int(y)%h])
    e['centers']=[[markers.get((r,k,'black'),markers.get((r,k,'blue'),[w/2,h/2])) for k in range(n)] for r in range(rows)]
    e['flight_centers']=[[markers.get((r,k,'green'),e['centers'][r][k]) for k in range(n)] for r in range(rows)]


def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--jobs',type=int,default=4)
    parser.add_argument('--dex',type=int,nargs='*')
    args=parser.parse_args()
    OUT.mkdir(exist_ok=True);(REVIEW/'bake-cache').mkdir(exist_ok=True,parents=True)
    specs={p:s for p,s in discover().items() if p.startswith('assets/sprites/') and (not args.dex or int(p.split('/')[2]) in args.dex)}
    results=[]
    with ProcessPoolExecutor(max_workers=args.jobs) as pool:
        futures=[pool.submit(bake,j) for j in specs.items()]
        for i,f in enumerate(as_completed(futures),1):
            results.append(f.result())
            if i%100==0:print(f'Native 2x sheets {i}/{len(specs)}',flush=True)
    results.sort(key=lambda r:r['source'])
    for record in results:attach_native_anchors(record)
    catalog=REVIEW/'catalog.json'
    # The complete catalog is an offline review artifact. The game loads only
    # a participating species' profile, never all 493 animation dictionaries.
    old=OUT/'manifest.json'
    manifest=json.loads(catalog.read_text()) if catalog.exists() else json.loads(old.read_text()) if old.exists() else {}
    if 'schema' in manifest:manifest={}
    manifest.update({r['source']:r['entry'] for r in results})
    catalog.write_text(json.dumps(manifest,separators=(',',':'))+'\n')
    species={}
    for source,entry in manifest.items():
        dex=int(source.removeprefix('res://').split('/')[2])
        species.setdefault(dex,{})[source]=entry
    for dex,entries in species.items():
        (OUT/f'{dex:04}.json').write_text(json.dumps(entries,separators=(',',':'))+'\n')
    (OUT/'manifest.json').write_text(json.dumps(dict(schema='pokemon-motion-index/v1',steps=2,
        species=sorted(species),profile='res://assets/motion_2x/%04d.json'),separators=(',',':'))+'\n')
    stats=dict(schema='pokemon-native-motion-2x/v1',art_source='existing',model_generated=False,
        species=len({r['dex'] for r in results}),sets=len({(r['dex'],r['shiny']) for r in results}),sheets=len(results),
        original_direction_keys=sum(r['keys'] for r in results),middle_slots=sum(r['pairs'] for r in results),
        new_distinct_poses=sum(r['new_distinct_poses'] for r in results),methods=dict(sum((Counter(r['methods']) for r in results),Counter())),
        sources=[{k:v for k,v in r.items() if k!='entry'} for r in results])
    (REVIEW/('bake-summary-partial.json' if args.dex else 'bake-summary.json')).write_text(json.dumps(stats,indent=2)+'\n')
    print({k:v for k,v in stats.items() if k!='sources'},flush=True)


if __name__=='__main__':main()
