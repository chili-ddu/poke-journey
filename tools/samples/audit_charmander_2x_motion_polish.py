"""Exact preservation checks plus real Forge QA/timing for the 2x polish."""
from pathlib import Path
from collections import Counter
from concurrent.futures import ThreadPoolExecutor,as_completed
import json,sys,os
import numpy as np
from PIL import Image
import charmander_2x_motion_polish as s
from audit_charmander_native_actions import command,SKILL

OUT=s.OUT;ROOT=s.ROOT


def numeric(m):
    rows=[];originals=0;face_checks=0
    for name,a in m['actions'].items():
        w,h=a['size'];raw=np.array(Image.open(ROOT/a['source']).convert('RGBA'));palette=set(map(tuple,raw[...,:3][raw[...,3]>0]))
        assert len(a['baseline_ticks'])==len(a['refined_ticks'])==2*len(a['original_ticks'])
        assert sum(a['baseline_ticks'])==sum(a['refined_ticks'])==a['duration_ticks']
        for ticks in [a['baseline_ticks'],a['refined_ticks']]:
            assert np.array_equal(np.cumsum([0]+a['original_ticks'][:-1]),np.cumsum([0]+ticks[:-1])[::2])
            for event in a['events'].values():assert sum(ticks[:event['added_frame']])==event['at_tick']
        for row in range(a['rows']):
            paths={v:s.files(name,row,v) for v in ['baseline','refined']}
            fs={v:[np.array(Image.open(f).convert('RGBA')) for f in pp] for v,pp in paths.items()}
            for k,im in enumerate(fs['refined']):
                assert im.shape==(h,w,4)
                assert set(np.unique(im[...,3])).issubset({0,255})
                assert set(map(tuple,im[...,:3][im[...,3]>0])).issubset(palette)
                if k%2==0:
                    assert paths['refined'][k].read_bytes()==paths['baseline'][k].read_bytes()
                    assert np.array_equal(im,raw[row*h:(row+1)*h,(k//2)*w:(k//2+1)*w]);originals+=1
            if not a['loop']:assert np.array_equal(fs['refined'][-1],fs['baseline'][-1])
            if name=='Walk' and row in [2,6]:
                for k in range(4):
                    aa,bb=fs['baseline'][k*2],fs['baseline'][((k+1)%4)*2];new=fs['refined'][k*2+1]
                    upper=fs['baseline'][k*2+1] if k%2==0 else bb
                    floor=max(np.where(aa[...,3]>0)[0].max(),np.where(bb[...,3]>0)[0].max());top=floor-2
                    crop=(slice(None,top),slice(11,None)) if row==2 else (slice(None,top),slice(None,21))
                    assert np.array_equal(new[crop],upper[crop]);face_checks+=1
                    assert np.where(new[...,3]>0)[0].max()==floor
                    assert s.components(new)==1
            if a['alias_of']:
                other=s.files(a['alias_of'],row,'refined')
                assert all(x.read_bytes()==y.read_bytes() for x,y in zip(paths['refined'],other))
            rows.append(dict(action=name,row=row,
                baseline_unique=len({im.tobytes() for im in fs['baseline']}),refined_unique=len({im.tobytes() for im in fs['refined']}),
                changed_frames=sum(not np.array_equal(x,y) for x,y in zip(fs['baseline'],fs['refined'])),
                changed_pixels=sum(np.any(x!=y,axis=-1).sum().item() for x,y in zip(fs['baseline'],fs['refined'])),
                timing_changed=a['baseline_ticks']!=a['refined_ticks']))
    changes=[]
    for path,digest in m['protected_hashes'].items():
        current=s.digest(ROOT/path)
        if current!=digest:changes.append(dict(path=path,before=digest,after=current))
    assert not [c for c in changes if c['path'].startswith(('assets/sprites/0004/','docs/charmander_native_actions/','docs/charmander_more_frames/'))],changes
    return dict(original_png_keys_exact=originals,native_palette_binary_alpha='pass',frame_counts_unchanged=True,
                original_key_onsets_hit_and_return_events='pass',side_walk_face_and_upper_body_exact=face_checks,
                prior_studies_unchanged=True,other_work_changes=changes,rows=rows)


def baseline_report(name,a,row):
    path=s.POOL/'forge-qa'/f'{name}-r{row}-double'/'sheet-qc.json';report=json.loads(path.read_text())
    padded=sorted((s.POOL/'qa-inputs'/name/f'row-{row}'/'double').glob('*.png'))
    original=s.files(name,row,'baseline')
    assert [s.digest(p) for p in padded]==[i['sha256'] for i in report['input']['frames']]
    for file,source in zip(padded,original):
        im=Image.open(file).convert('RGBA');src=Image.open(source).convert('RGBA')
        assert im.crop((16,16,16+src.width,16+src.height)).tobytes()==src.tobytes()
    return path,report


def check(job):
    name,a,row=job;oldpath,old=baseline_report(name,a,row)
    native=s.files(name,row,'refined');same=[s.digest(p) for p in native]==[s.digest(p) for p in s.files(name,row,'baseline')]
    results=[];flags=[]
    for v in ['baseline','refined']:
        if v=='baseline' or same:
            path,report=oldpath,old;call=dict(tool='sheet_qc',action=name,row=row,variant=v,status=report['status'],reused_exact_pixels=True,executed=False)
        else:
            inputs=[]
            for file in native:
                im=Image.open(file).convert('RGBA');pad=Image.new('RGBA',(im.width+32,im.height+32));pad.paste(im,(16,16))
                dest=OUT/'qa-inputs'/name/f'row-{row}'/file.name;dest.parent.mkdir(exist_ok=True,parents=True);pad.save(dest);inputs.append(dest)
            dest=OUT/'forge-qa'/f'{name}-r{row}-refined'
            code=command([SKILL/'generate2dsprite/scripts/sheet_qc.py','frames','--frames',*inputs,'--cycle','walk' if name=='Walk' else 'none',
                '--facing','left' if row in [5,6,7] else 'right','--game-pixel','1','--loop' if a['loop'] else '--no-loop','--output-dir',dest],
                OUT/'logs'/f'qc-{name}-r{row}.json')
            path=dest/'sheet-qc.json'
            if not path.exists():return [dict(tool='sheet_qc',action=name,row=row,variant=v,status='error',exit_code=code)],[]
            report=json.loads(path.read_text());call=dict(tool='sheet_qc',action=name,row=row,variant=v,status=report['status'],executed=True,exit_code=code)
        call['report']=os.path.relpath(path,OUT);results.append(call)
        flags += [dict(action=name,row=row,variant=v,report=call['report'],**c) for c in report['checks'] if c['status'] in ['warn','fail']]
    return results,flags


def timing(job):
    name,a,v=job;row=min(2,a['rows']-1);paths=s.files(name,row,v)
    args=[SKILL/'video2dsprite/scripts/retime.py','--frames-dir',paths[0].parent,'--fps','120',
        '--kind','walk' if name=='Walk' else 'idle' if a['loop'] else 'other','--spans',f'0:{len(paths)}',
        '--ticks',','.join(map(str,a[v+'_ticks'])),'--tick-hz','120','--policy','cycle' if a['loop'] else 'oneshot',
        '--output-dir',OUT/'timing'/f'{name}-{v}']
    if 'HitFrame'in a['events']:args+=['--impact-source',str(a['events']['HitFrame']['added_frame'])]
    for tag,label in [('RushFrame','rush'),('ReturnFrame','return')]:
        if tag in a['events']:args+=['--event',f"custom:{label}@{a['events'][tag]['at_tick']}t"]
    code=command(args,OUT/'logs'/f'retime-{name}-{v}.json')
    return dict(tool='retime',action=name,variant=v,exit_code=code)


def review(m):
    calls=[]
    for name in ['Walk','Strike','Hop']:
        a=m['actions'][name];row=min(2,a['rows']-1)
        for v in ['baseline','refined']:
            folder=OUT/'timeline-120hz'/f'{name}-{v}';folder.mkdir(exist_ok=True,parents=True);i=0
            for file,ticks in zip(s.files(name,row,v),a[v+'_ticks']):
                data=file.read_bytes()
                for _ in range(ticks):(folder/f'{i:04d}.png').write_bytes(data);i+=1
            code=command([SKILL/'video2dsprite/scripts/animation_review.py','review','--frames-dir',folder,
                '--out-dir',OUT/'forge-review'/f'{name}-{v}','--fps','120','--min-cycle','4','--max-cycle',str(i),'--preview-size','128'],
                OUT/'logs'/f'review-{name}-{v}.json')
            calls.append(dict(tool='animation_review',action=name,variant=v,exit_code=code))
    return calls


def main():
    m=json.loads((OUT/'study.json').read_text());result=numeric(m);(OUT/'numeric-qa.json').write_text(json.dumps(result,indent=2)+'\n')
    jobs=[(n,a,row) for n,a in m['actions'].items() if not a['alias_of'] for row in range(a['rows'])]
    calls=[];flags=[]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for done,f in enumerate(as_completed([pool.submit(check,j) for j in jobs]),1):
            cc,ff=f.result();calls+=cc;flags+=ff
            if done%30==0:print(f'QA set pairs {done}/{len(jobs)}',flush=True)
    with ThreadPoolExecutor(max_workers=4) as pool:calls+=list(pool.map(timing,[(n,a,v) for n,a in m['actions'].items() if not a['alias_of'] for v in ['baseline','refined']]))
    calls+=review(m)
    result['calls']=calls;result['report_counts']={v:dict(Counter(c['status'] for c in calls if c['tool']=='sheet_qc' and c['variant']==v)) for v in ['baseline','refined']}
    result['quality_flags']=dict(Counter(f['status'] for f in flags));result['fresh_frame_checks']=sum(c.get('executed',False) for c in calls)
    result['new_failed_sets']=[f for f in flags if f['variant']=='refined' and f['status']=='fail' and not any(x['action']==f['action'] and x['row']==f['row'] and x['id']==f['id'] and x['variant']=='baseline' and x['status']=='fail' for x in flags)]
    (OUT/'qa-summary.json').write_text(json.dumps(result,indent=2)+'\n');(OUT/'qa-flags.json').write_text(json.dumps(flags,indent=2)+'\n')
    print('Frame reports',result['report_counts'],'fresh checks',result['fresh_frame_checks'],'newfail',len(result['new_failed_sets']),flush=True)
    print('Execution errors',[c for c in calls if c.get('status')=='error' or c['tool']!='sheet_qc' and c['exit_code']],flush=True)


if __name__=='__main__':main()
