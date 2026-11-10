"""Refine the existing 2x clips, not the character design or game runtime.

Keep every original key and its onset, all events, native grid and total time.
Choose one passing pose per interval and redistribute its two existing slots.
Side-view Walk uses source sole pixels and a delayed source tail; never redraw
the eyes, resize anatomy, blend colours or increase the number of frames.
"""
from pathlib import Path
import sys,json,hashlib,shutil,base64,math
import numpy as np
import cv2
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]
BASE=ROOT/'docs/charmander_native_actions'
POOL=ROOT/'docs/charmander_more_frames'
OUT=ROOT/'docs/charmander_2x_motion_polish'


def digest(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def files(name,row,variant):
    folder=BASE/'frames'/name/f'row-{row}'/'added' if variant=='baseline' else OUT/'frames'/name/f'row-{row}'/'refined'
    return sorted(folder.glob('*.png'))


def components(a):return cv2.connectedComponents((a[...,3]>0).astype('uint8'),8)[0]-1


def safe(candidate,a,b,old):
    areas=[np.count_nonzero(x[...,3]) for x in [a,b,old]]
    return (.85*min(areas)<=np.count_nonzero(candidate[...,3])<=1.15*max(areas) and
            components(candidate)<=max(components(x) for x in [a,b,old]))


def side_walk(a,b,old,k,row):
    # Return/passing frames lift the torso from the next original pose, while
    # the planted source sole advances only half the original local distance.
    out=old.copy() if k%2==0 else b.copy()
    tail=(slice(None),slice(None,11)) if row==2 else (slice(None),slice(21,None))
    out[tail]=a[tail]
    floor=max(np.where(a[...,3]>0)[0].max(),np.where(b[...,3]>0)[0].max())
    top=floor-2
    ax=np.where(a[top:,:,3]>0)[1];bx=np.where(b[top:,:,3]>0)[1]
    dx=int(np.clip(np.rint((bx.mean()-ax.mean())*.5),-1,1))
    sole=np.zeros_like(a);sole[top:]=a[top:]
    sole=cv2.warpAffine(sole,np.float32([[1,0,dx],[0,1,0]]),(a.shape[1],a.shape[0]),flags=cv2.INTER_NEAREST)
    out[top:]=sole[top:]
    if not safe(out,a,b,old):return old.copy(),dict(kind='side_walk_guard_hold',dx=dx)
    return out,dict(kind='source_sole_and_delayed_tail',dx=dx,sole_top=int(top),
        upper_body='previous_midpoint' if k%2==0 else 'next_original',tail_source='current_original')


def profile(name,a,k,roots):
    n=len(a['original_ticks']);canon=a['source_name']
    if k==n-1 and not a['loop'] or a['static']:return .5,None,'terminal_or_static'
    if canon=='Walk':return .5,[2,5,2,5][k],'support_and_passing'
    if canon=='Idle':return .5,[7,4,5,3][k],'calm_breath_hold'
    if canon in ['Hop','LeapForth']:
        dy=roots[(k+1)%n][1]-roots[k][1]
        if dy<=-2:return .75,(a['original_ticks'][k]/2)*.35,'quick_takeoff'
        if dy>=2:return .25,(a['original_ticks'][k]/2)*.35,'accelerating_descent'
        return .5,(a['original_ticks'][k]/2)*.65,'apex_hold'
    if canon in ['Attack','Kick','Strike','Swing','Charge']:
        events=a['events'];hit=events.get('HitFrame',{}).get('source_frame');rush=events.get('RushFrame',{}).get('source_frame');ret=events.get('ReturnFrame',{}).get('source_frame')
        if k==hit:return .25,(a['original_ticks'][k]/2)*.75,'contact_pose_hold'
        if hit is not None and k==hit-1:return .75,(a['original_ticks'][k]/2)*.67,'late_release'
        if k==rush:return .25,(a['original_ticks'][k]/2)*.67,'anticipation_hold'
        if ret is not None and k>=ret:return .75,(a['original_ticks'][k]/2)*.4,'settled_recovery'
    if canon in ['Hurt','Pain','Cringe'] and k==0:return .25,(a['original_ticks'][k]/2)*.67,'readable_reaction'
    if canon=='Wake':return (.75 if k==3 else .5),[5,4,8,1,5][k],'supported_wake'
    if canon=='Nod':return (.75 if k==0 else .25),([2,5,3][k]),'nod_down_then_hold'
    if canon=='Faint':return (.75 if k==1 else .5),[5,4,3,5][k],'stagger_then_settle'
    return .5,None,'unchanged'


def candidate(name,row,k,phase):
    if phase==.5:return files(name,row,'baseline')[k*2+1]
    return POOL/'frames'/name/f'row-{row}'/'quad'/f'{k*4+(1 if phase==.25 else 3):03d}.png'


def build():
    old=json.loads((BASE/'study.json').read_text())
    m=dict(schema='two-frame-polish/v1',applied=False,tick_hz=120,model_generated=False,art_source='existing',
        directions=old['directions'],protected_hashes=json.loads((OUT/'protected-before.json').read_text()),actions={})
    decisions=[]
    for name,a in old['actions'].items():
        w,h=a['size'];n=len(a['original_ticks'])
        meta=dict(a);meta.pop('sheet',None)
        meta['baseline_ticks']=a['added_ticks'];meta['refined_ticks']=[]
        offsets_path=ROOT/Path(a['source']).with_name(a['source_name']+'-Offsets.png')
        offsets=np.array(Image.open(offsets_path).convert('RGBA'))
        for row in range(a['rows']):
            baseline_files=files(name,row,'baseline')
            baseline=[np.array(Image.open(f).convert('RGBA')) for f in baseline_files]
            raw=baseline[::2];roots=[];row_ticks=[];refined=[]
            for k in range(n):
                yy,xx=np.where(np.all(offsets[row*h:(row+1)*h,k*w:(k+1)*w]==[0,0,0,255],axis=-1));roots.append((int(xx[0]),int(yy[0])))
            for k,a0 in enumerate(raw):
                b=raw[(k+1)%n];mid=baseline[k*2+1]
                phase,first60,reason=profile(name,a,k,roots)
                old_ticks=a['added_ticks'][k*2:k*2+2];total=a['original_ticks'][k]
                if first60 is None or total==2:ticks=old_ticks
                else:
                    total60=total//2;first=max(1,min(total60-1,int(math.floor(first60+.5))));ticks=[first*2,(total60-first)*2]
                info={};selected=candidate(name,row,k,phase)
                chosen=np.array(Image.open(selected).convert('RGBA'))
                if name=='Walk' and row in [2,6]:chosen,info=side_walk(a0,b,mid,k,row)
                elif not safe(chosen,a0,b,mid):chosen=mid.copy();info={'kind':'candidate_guard_hold'}
                refined.extend([a0.copy(),chosen]);row_ticks.extend(ticks)
                decisions.append(dict(action=name,row=row,source_frame=k,midpoint_frame=k*2+1,reason=reason,
                    requested_phase=phase,baseline_ticks=old_ticks,refined_ticks=ticks,
                    changed_pixels=int(np.any(mid!=chosen,axis=-1).sum()),
                    selected_source=str(selected.relative_to(ROOT)) if not info else None,**info))
            # Timing policy is shared across directions; artwork remains directional.
            if row==0:meta['refined_ticks']=row_ticks
            else:assert row_ticks==meta['refined_ticks'],(name,row)
            target=OUT/'frames'/name/f'row-{row}'/'refined';target.mkdir(exist_ok=True,parents=True)
            for k,im in enumerate(refined):
                dest=target/f'{k:03d}.png'
                if np.array_equal(im,baseline[k]):dest.write_bytes(baseline_files[k].read_bytes())
                else:Image.fromarray(im).save(dest)
        m['actions'][name]=meta
        print('Polished',name,flush=True)
    (OUT/'study.json').write_text(json.dumps(m,indent=2)+'\n')
    (OUT/'decisions.json').write_text(json.dumps(decisions,indent=2)+'\n')


def index_at(t,ticks,loop):
    t=t%sum(ticks) if loop else min(max(0,t),sum(ticks)-1e-8)
    for k,length in enumerate(ticks):
        if t<length:return k
        t-=length
    return len(ticks)-1


def web():
    from charmander_native_frames import sheet
    m=json.loads((OUT/'study.json').read_text());web=dict(tick_hz=120,directions=m['directions'],actions={})
    for name,a in m['actions'].items():
        images={}
        for v in ['baseline','refined']:
            if v=='baseline':path=BASE/'sheets'/f'{name}-2frames.png'
            else:
                path=OUT/'sheets'/f'{name}-2frames.png';path.parent.mkdir(exist_ok=True)
                sheet([[np.array(Image.open(f).convert('RGBA')) for f in files(name,r,v)] for r in range(a['rows'])]).save(path)
            images[v]='data:image/png;base64,'+base64.b64encode(path.read_bytes()).decode()
        decisions=json.loads((OUT/'decisions.json').read_text())
        changed=[sum(d['changed_pixels']>0 for d in decisions if d['action']==name and d['row']==r) for r in range(a['rows'])]
        web['actions'][name]=dict(a,sheets=images,row_image_changes=changed,
            timing_changed=a['baseline_ticks']!=a['refined_ticks'])
        contact(name,a)
    template=(Path(__file__).parent/'charmander_2x_motion_polish_review.html').read_text()
    (OUT/'index.html').write_text(template.replace('__DATA__',json.dumps(web)))


def contact(name,a):
    w,h=a['size'];row=min(2,a['rows']-1);cw=w*4+12;ch=h*4+26
    for start in range(0,len(a['baseline_ticks']),8):
        count=min(8,len(a['baseline_ticks'])-start);board=Image.new('RGB',(count*cw,ch*2),'#222a28');d=ImageDraw.Draw(board)
        for rr,v in enumerate(['baseline','refined']):
            for col,file in enumerate(files(name,row,v)[start:start+count]):
                im=Image.open(file).convert('RGBA').resize((w*4,h*4),Image.Resampling.NEAREST);x=col*cw+6;y=rr*ch+24
                board.paste(im,(x,y),im);d.text((x,y-20),f'{v} {start+col}',fill='#f1e8d5')
        folder=OUT/'contacts'/name;folder.mkdir(exist_ok=True,parents=True);board.save(folder/f'page-{start//8+1}.png')


if __name__=='__main__':
    if sys.argv[1]=='build':build()
    else:web()
