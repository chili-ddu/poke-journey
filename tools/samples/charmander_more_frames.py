"""Native resolution 2x/3x/4x frame-count study; keep all prior art read-only.

Existing-image processing, not image/video model generation. 4x includes every
2x PNG byte-for-byte. New 1/3 and 1/4 samples refine the existing half intervals.
"""
from pathlib import Path
from collections import Counter
import argparse,base64,hashlib,json,sys
import cv2
import numpy as np
from PIL import Image,ImageDraw

sys.path.insert(0,str(Path(__file__).parent))
from charmander_native_frames import gray,sheet
from charmander_native_actions import index_at

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'docs/charmander_native_actions'
OUT=ROOT/'docs/charmander_more_frames'
VARIANTS=['original','double','triple','quad']


def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def files(name,row,v):
    if v in ['original','double']:
        return sorted((BASE/'frames'/name/f'row-{row}'/('added' if v=='double' else 'original')).glob('*.png'))
    return sorted((OUT/'frames'/name/f'row-{row}'/v).glob('*.png'))


def tween(a,b,f,rigid_delta=None):
    if np.array_equal(a,b):return a.copy(),'identical_hold'
    h,w=a.shape[:2]
    if rigid_delta is not None:
        dx,dy=np.rint(np.asarray(rigid_delta)*f).astype(int)
        out=cv2.warpAffine(a,np.float32([[1,0,dx],[0,1,dy]]),(w,h),flags=cv2.INTER_NEAREST)
        if np.count_nonzero(out[...,3])!=np.count_nonzero(a[...,3]):return a.copy(),'edge_hold'
        return out,'rigid_pixels'
    flow=cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM);flow.setFinestScale(0)
    ab=flow.calc(gray(a),gray(b),None)
    yy,xx=np.mgrid[:h,:w].astype(np.float32)
    out=cv2.remap(a,xx-ab[...,0]*f,yy-ab[...,1]*f,cv2.INTER_NEAREST,borderMode=cv2.BORDER_CONSTANT)
    ay,ax=np.where(a[...,3]>0);by,bx=np.where(b[...,3]>0)
    cutoff=int(ay.min()+(ay.max()-ay.min()+1)*.52)
    mask=(a[...,3]>0)&(yy<cutoff)
    dx,dy=np.rint(np.median(ab[mask],axis=0)*f).astype(int)
    face=cv2.warpAffine(a,np.float32([[1,0,dx],[0,1,dy]]),(w,h),flags=cv2.INTER_NEAREST)
    out[yy<cutoff+dy]=face[yy<cutoff+dy]
    bounds=(xx>=min(ax.min(),bx.min()))&(xx<=max(ax.max(),bx.max()))&(yy>=min(ay.min(),by.min()))&(yy<=max(ay.max(),by.max()))
    out[~bounds]=0
    area=np.count_nonzero(out[...,3]);amin,amax=sorted(np.count_nonzero(x[...,3]) for x in [a,b])
    if not .85*amin<=area<=1.15*amax:return a.copy(),'area_hold'
    return out,'native_pixels'


def build():
    OUT.mkdir(exist_ok=True,parents=True)
    old=json.loads((BASE/'study.json').read_text())
    prior={(d['action'],d['row'],d['source_frame']):d for d in json.loads((BASE/'midpoint-decisions.json').read_text())}
    protected=[p for folder in [ROOT/'assets/sprites/0004',ROOT/'scripts/view',BASE] for p in folder.rglob('*') if p.is_file()]
    protected += [ROOT/'assets/smooth/manifest.json',ROOT/'project.godot']
    m=dict(schema='native-frame-density/v1',tick_hz=720,applied=False,art_source='existing',model_generated=False,
           protected_hashes={str(p.relative_to(ROOT)):digest(p) for p in protected},directions=old['directions'],actions={})
    decisions=[]
    for name,a in old['actions'].items():
        ts=[t//2 for t in a['original_ticks']]
        meta=dict(a)
        for legacy in ['original_ticks','added_ticks','sheet']:meta.pop(legacy,None)
        meta['ticks']={'original':[t*12 for t in ts],'double':[t*6 for t in a['added_ticks']],
            'triple':[t*4 for t in ts for _ in range(3)],'quad':[t*3 for t in ts for _ in range(4)]}
        meta['duration_ticks']=a['duration_ticks']*6
        meta['events']={tag:dict(source_frame=e['source_frame'],double_frame=e['source_frame']*2,
            triple_frame=e['source_frame']*3,quad_frame=e['source_frame']*4,at_tick=e['at_tick']*6) for tag,e in a['events'].items()}
        for row in range(a['rows']):
            original=[np.array(Image.open(f).convert('RGBA')) for f in files(name,row,'original')]
            double=[np.array(Image.open(f).convert('RGBA')) for f in files(name,row,'double')]
            op=ROOT/Path(a['source']).with_name(a['source_name']+'-Offsets.png')
            offsets=np.array(Image.open(op).convert('RGBA'))
            w,h=a['size'];roots=[]
            for k in range(len(ts)):
                yy,xx=np.where(np.all(offsets[row*h:(row+1)*h,k*w:(k+1)*w]==[0,0,0,255],axis=-1));roots.append(np.array([xx[0],yy[0]]))
            for v,phases in [('triple',[0,1/3,2/3]),('quad',[0,.25,.5,.75])]:
                result=[]
                for k,src in enumerate(original):
                    mid=double[k*2+1];end=original[(k+1)%len(ts)]
                    method=prior[(name,row,k)]['method'];delta=roots[(k+1)%len(ts)]-roots[k]
                    mid_delta=np.rint(delta*.5).astype(int)
                    for phase in phases:
                        if phase==0:im,reason=src.copy(),'source_key'
                        elif phase==.5:im,reason=mid.copy(),'preserved_double_key'
                        elif a['static'] or (k==len(ts)-1 and not a['loop']):im,reason=src.copy(),'terminal_or_static_hold'
                        elif phase<.5:im,reason=tween(src,mid,phase*2,mid_delta if method=='rigid_root_midpoint' else None)
                        else:im,reason=tween(mid,end,(phase-.5)*2,delta-mid_delta if method=='rigid_root_midpoint' else None)
                        result.append(im);decisions.append(dict(action=name,row=row,variant=v,index=len(result)-1,method=reason,source_frame=k))
                target=OUT/'frames'/name/f'row-{row}'/v;target.mkdir(exist_ok=True,parents=True)
                for k,im in enumerate(result):
                    f=target/f'{k:03d}.png'
                    # Copy existing key PNGs exactly, including PNG encoding.
                    if v=='quad' and k%2==0:f.write_bytes(files(name,row,'double')[k//2].read_bytes())
                    elif k%len(phases)==0:f.write_bytes(files(name,row,'original')[k//len(phases)].read_bytes())
                    else:Image.fromarray(im).save(f)
        meta['sheets']={}
        for v in VARIANTS:
            if v=='original':path=ROOT/a['source']
            elif v=='double':path=BASE/a['sheet']
            else:
                path=OUT/'sheets'/f'{name}-{v}.png';path.parent.mkdir(exist_ok=True)
                sheet([[np.array(Image.open(f).convert('RGBA')) for f in files(name,r,v)] for r in range(a['rows'])]).save(path)
            meta['sheets'][v]=str(path.relative_to(ROOT))
        m['actions'][name]=meta
        print('Built',name,flush=True)
    (OUT/'study.json').write_text(json.dumps(m,indent=2)+'\n')
    (OUT/'decisions.json').write_text(json.dumps(decisions,indent=2)+'\n')


def preview():
    m=json.loads((OUT/'study.json').read_text());web=dict(tick_hz=720,directions=m['directions'],actions={})
    for name,a in m['actions'].items():
        row=min(2,a['rows']-1)
        imgs={v:[Image.open(f).convert('RGBA') for f in files(name,row,v)] for v in VARIANTS}
        # Same native frame, clock and position. Integer enlargement is display only.
        for target in ['triple','quad']:
            captures=[];total_ms=a['duration_ticks']*25//6+(0 if a['loop'] else 1500)
            for ms in range(0,total_ms,10):
                tick=(ms*.72)%(a['duration_ticks']+(0 if a['loop'] else 360))
                canvas=Image.new('RGB',(384,216),'#222a28');d=ImageDraw.Draw(canvas)
                for side,v in enumerate(['double',target]):
                    k=index_at(tick,a['ticks'][v],a['loop']);im=imgs[v][k];scale=2
                    large=im.resize((im.width*scale,im.height*scale),Image.Resampling.NEAREST)
                    canvas.paste(large,(side*192+96-im.width,120-im.height),large)
                    d.text((side*192+6,7),f'{name} {v.upper()}',fill='#f1e8d5');d.text((side*192+6,22),f'{k+1}/{len(imgs[v])} / 2x VIEW',fill='#f1e8d5')
                captures.append(canvas)
            folder=OUT/'gifs';folder.mkdir(exist_ok=True)
            captures[0].save(folder/f'{name}-2-vs-{3 if target=="triple" else 4}.gif',save_all=True,append_images=captures[1:],duration=10,loop=0,disposal=2,optimize=False)
        web['actions'][name]=dict(a,sheets={v:'data:image/png;base64,'+base64.b64encode((ROOT/path).read_bytes()).decode() for v,path in a['sheets'].items()})
        print('Preview',name,flush=True)
    template=(Path(__file__).parent/'charmander_more_frames_review.html').read_text()
    (OUT/'index.html').write_text(template.replace('__DATA__',json.dumps(web)))
    overview(m)


def overview(m):
    for name,a in m['actions'].items():
        w,h=a['size'];cw,ch=max(112,w*3+12),h*3+28
        for v in ['triple','quad']:
            ims=[Image.open(f).convert('RGBA') for f in files(name,min(2,a['rows']-1),v)]
            for start in range(0,len(ims),16):
                batch=ims[start:start+16];cols=min(8,len(batch));rows=(len(batch)+7)//8
                board=Image.new('RGB',(cols*cw,rows*ch),'#222a28');d=ImageDraw.Draw(board)
                for i,im in enumerate(batch):
                    x,y=(i%8)*cw,(i//8)*ch;k=start+i;big=im.resize((w*3,h*3),Image.Resampling.NEAREST)
                    board.paste(big,(x+(cw-big.width)//2,y+26),big)
                    kind='KEY' if k%4==0 else '2X' if k%2==0 else 'NEW'
                    if v=='triple':kind='KEY' if k%3==0 else 'NEW'
                    d.text((x+4,y+4),f'{name} {k} {kind}',fill='#f1e8d5')
                folder=OUT/'contacts'/name;folder.mkdir(exist_ok=True,parents=True)
                board.save(folder/f'{v}-{start//16+1}.png')


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('command',choices=['build','preview','all'],nargs='?',default='all');a=p.parse_args()
    if a.command in ['build','all']:build()
    if a.command in ['preview','all']:preview()
