"""Bake C-style, palette-preserving optical-flow in-betweens (25/50/75%).

python tools/bake_smooth_sprites.py --jobs 4
Dependencies: Pillow, numpy, opencv-python-headless. Originals are never changed.
Add future non-PMD sprite sequences in discover(); reruns reuse content hashes.
"""
from __future__ import annotations
import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
import math
from pathlib import Path
import xml.etree.ElementTree as ET
import cv2
import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'assets/smooth'
VERSION = 1
cv2.setNumThreads(1)


def discover():
    specs = {}
    flight_rules=json.loads((ROOT/'assets/data/pokemon_flight.json').read_text())
    flight_species={int(s['dex']):sid for sid,s in json.loads((ROOT/'assets/data/species.json').read_text()).items()}
    def add(path, size, pairs, targets=None, grass=False):
        if not (ROOT / path).exists():
            return
        specs[path] = dict(size=size, pairs=pairs, targets=targets or {}, grass=grass)
    def sequence(path, size, cells, loop=True):
        pairs = [(a, b) for a, b in zip(cells, cells[1:])]
        if loop and len(cells) > 1:
            pairs.append((cells[-1], cells[0]))
        add(path, size, pairs)
    for xml in sorted((ROOT/'assets/sprites').rglob('AnimData.xml')):
        anims=ET.parse(xml).findall('.//Anim')
        by_name={a.findtext('Name'):a for a in anims}
        sid=flight_species.get(int(xml.relative_to(ROOT/'assets/sprites').parts[0]),'')
        flight_name=flight_rules['hover_animation'] if sid in flight_rules['hover'] else flight_rules['wing_animation']
        flight_name=flight_rules['animation_overrides'].get(sid,flight_name)
        cycle=flight_rules['cycles'].get(flight_name,{})
        while flight_name in by_name and by_name[flight_name].findtext('CopyOf'):
            flight_name=by_name[flight_name].findtext('CopyOf')
        for anim in anims:
            if anim.find('CopyOf') is not None:
                continue
            path = xml.parent / (anim.findtext('Name')+'-Anim.png')
            if not path.exists():
                continue
            fw, fh = int(anim.findtext('FrameWidth')), int(anim.findtext('FrameHeight'))
            n = len(anim.findall('./Durations/Duration'))
            rows = Image.open(path).height // fh
            pairs = [((i*fw, r*fh), (((i+1)%n)*fw, r*fh)) for r in range(rows) for i in range(n)] if n > 1 else []
            if anim.findtext('Name')==flight_name and cycle:
                order=cycle.get('short_frames',cycle['frames']) if n==cycle.get('short_source_frames') else cycle['frames']
                pairs += [((a*fw,r*fh),(b*fw,r*fh)) for r in range(rows) for a,b in zip(order,order[1:]+order[:1])]
                pairs=list(dict.fromkeys(pairs))
            # Charmander's grounded scratch uses an authored 0,2,2,3,4,
            # 4,4,4,1 pose order. Adjacent source cells do not cover its two
            # non-adjacent transitions. Include both normal and shiny sheets.
            if '0004' in path.parts and anim.findtext('Name') == 'Strike' and n == 9:
                pairs += [((a*fw,r*fh),(b*fw,r*fh)) for r in range(rows) for a,b in [(0,2),(4,1)]]
            add(path.relative_to(ROOT).as_posix(), (fw,fh), pairs)
    npc_manifest=ROOT/'assets/data/road_trainers.json'
    npc_frames=json.loads(npc_manifest.read_text()).get('npcs',{}) if npc_manifest.exists() else {}
    for path in sorted((ROOT/'assets/npcs').glob('*.png')):
        width,height=npc_frames.get(path.stem,{}).get('frame',[16,32])
        if Image.open(path).width >= 9*width:
            pairs = [((a*width,0),(b*width,0)) for a,b in [(3,4),(4,3),(5,6),(6,5),(7,8),(8,7)]]
            add(path.relative_to(ROOT).as_posix(),(width,height),pairs)
    for path in sorted((ROOT/'assets/ui/plat/icons').glob('*.png')):
        if Image.open(path).size == (32,64):
            sequence(path.relative_to(ROOT).as_posix(),(32,32),[(0,0),(0,32)])
    for name, n in [('g4_claw_strike',5),('g4_scary_face',4)]:
        path = 'assets/fx/'+name+'.png'
        w,h = Image.open(ROOT/path).size
        sequence(path,(w,h//n),[(0,i*(h//n)) for i in range(n)],False)
    grass = 'assets/fx/tall_grass.png'
    if (ROOT/grass).exists():
        add(grass,(16,16),[((0,a*16),(0,b*16)) for a,b in [(1,2),(2,3),(3,4),(4,0),(4,2)]],grass=True)
    # Texture swaps are also real animations; atlas entries can target another file.
    for names in [('g4_bolt_a','g4_bolt_b'),('g4_tw_bolt_a','g4_tw_bolt_b'),('evo_ring_a','evo_ring_b')]:
        for a,b in [names,names[::-1]]:
            path='assets/fx/'+a+'.png';target='assets/fx/'+b+'.png'
            if (ROOT/path).exists() and (ROOT/target).exists():
                size=Image.open(ROOT/path).size
                if size==Image.open(ROOT/target).size:
                    add(path,size,[((0,0),(0,0))],{'0,0,0,0':target})
    return specs


def inbetweens(a, b):
    if np.array_equal(a,b):
        return [Image.fromarray(a)]*3
    h,w=a.shape[:2]
    aa,bb=[cv2.resize(p,(w*4,h*4),interpolation=cv2.INTER_NEAREST).astype(np.float32)/255 for p in (a,b)]
    def gray(p):
        rgb=p[:,:,:3]*p[:,:,3:4]+.18*(1-p[:,:,3:4])
        return cv2.cvtColor((rgb*255).astype(np.uint8),cv2.COLOR_RGB2GRAY)
    dis=cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
    ab=dis.calc(gray(aa),gray(bb),None);ba=dis.calc(gray(bb),gray(aa),None)
    yy,xx=np.mgrid[:h*4,:w*4].astype(np.float32)
    for p in (aa,bb):
        p[:,:,:3]*=p[:,:,3:4]
    colors=np.unique(np.concatenate([a.reshape(-1,4),b.reshape(-1,4)]),axis=0)
    palette=colors[colors[:,3]>0,:3].astype(np.float32)
    if not len(palette):
        return [Image.new('RGBA',(w,h))]*3
    result=[]
    for t in [.25,.5,.75]:
        wa=cv2.remap(aa,xx-ab[:,:,0]*t,yy-ab[:,:,1]*t,cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
        wb=cv2.remap(bb,xx-ba[:,:,0]*(1-t),yy-ba[:,:,1]*(1-t),cv2.INTER_LINEAR,borderMode=cv2.BORDER_CONSTANT)
        blend=cv2.resize(wa*(1-t)+wb*t,(w,h),interpolation=cv2.INTER_AREA)
        alpha=blend[:,:,3];mask=alpha>=.5
        rgb=blend[:,:,:3]/np.maximum(alpha[:,:,None],.001)*255
        out=np.zeros((h,w,4),dtype=np.uint8)
        nearest=((rgb[mask,None,:]-palette[None,:,:])**2).sum(axis=2).argmin(axis=1)
        out[mask,:3]=palette[nearest].astype(np.uint8);out[mask,3]=255
        result.append(Image.fromarray(out))
    return result


def bake(item):
    path,spec=item
    fw,fh=spec['size'];pairs=spec['pairs']
    if not pairs:
        return path,None
    token=hashlib.sha256(json.dumps([VERSION,spec],sort_keys=True).encode()+(ROOT/path).read_bytes()+b''.join((ROOT/p).read_bytes() for p in spec['targets'].values())).hexdigest()
    ident=hashlib.sha256(path.encode()).hexdigest()[:20]
    record=OUT/(ident+'.json');dest=OUT/(ident+'.png')
    if record.exists() and dest.exists():
        old=json.loads(record.read_text())
        if old.get('hash')==token:
            return path,old
    image=Image.open(ROOT/path).convert('RGBA')
    if spec['grass']:
        arr=np.array(image)
        for color in [(115,205,164),(65,180,139),(164,230,197),(24,164,106)]:
            arr[(arr[:,:,:3]==color).all(axis=2)]=0
        image=Image.fromarray(arr)
    cols=max(1,min(2048//fw,math.ceil(math.sqrt(len(pairs)*3*fh/fw))))
    atlas=Image.new('RGBA',(cols*fw,math.ceil(len(pairs)*3/cols)*fh))
    lookup={}
    for i,(start,end) in enumerate(pairs):
        key=','.join(map(str,(*start,*end)))
        target=spec['targets'].get(key)
        other=Image.open(ROOT/target).convert('RGBA') if target else image
        a=np.array(image.crop((*start,start[0]+fw,start[1]+fh)))
        b=np.array(other.crop((*end,end[0]+fw,end[1]+fh)))
        for j,p in enumerate(inbetweens(a,b)):
            slot=i*3+j;atlas.paste(p,((slot%cols)*fw,(slot//cols)*fh))
        lookup[key+('@'+target if target else '')]=i*3
    atlas.save(dest)
    data=dict(hash=token,sheet='res://assets/smooth/'+dest.name,size=[fw,fh],cols=cols,pairs=lookup)
    record.write_text(json.dumps(data,separators=(',',':')))
    return path,data


def main():
    parser=argparse.ArgumentParser();parser.add_argument('--jobs',type=int,default=4);parser.add_argument('--match',default='')
    args=parser.parse_args();OUT.mkdir(exist_ok=True)
    specs=discover();items=[x for x in specs.items() if args.match in x[0]]
    manifest={}
    with ThreadPoolExecutor(max_workers=args.jobs) as pool:
        for i,(path,data) in enumerate(pool.map(bake,items),1):
            if data:manifest['res://'+path]=data
            if i%25==0:print(f'{i}/{len(items)} baked',flush=True)
    if args.match:
        existing=OUT/'manifest.json'
        prev=json.loads(existing.read_text()) if existing.exists() else {}
        prev.update(manifest);manifest=prev
    (OUT/'manifest.json').write_text(json.dumps(manifest,separators=(',',':')))
    print(f'Complete: {len(manifest)} animated textures, {sum(len(x["pairs"])*3 for x in manifest.values())} in-betweens.',flush=True)


if __name__=='__main__':main()
