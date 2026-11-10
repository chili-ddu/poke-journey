"""Compare useful poses, exact timings and actual Forge QA at 2x/3x/4x."""
from concurrent.futures import ThreadPoolExecutor,as_completed
from collections import Counter
from pathlib import Path
import json,sys,hashlib
import numpy as np
from PIL import Image
import charmander_more_frames as study
from audit_charmander_native_actions import command,SKILL

OUT=study.OUT;ROOT=study.ROOT


def numeric(m):
    rows=[];key_count=0;preserved=0
    for name,a in m['actions'].items():
        for v,factor in zip(study.VARIANTS,[1,2,3,4]):
            assert sum(a['ticks'][v])==a['duration_ticks']
            assert np.array_equal(np.cumsum([0]+a['ticks']['original'][:-1]),np.cumsum([0]+a['ticks'][v][:-1])[::factor])
            for e in a['events'].values():assert sum(a['ticks'][v][:e['source_frame']*factor])==e['at_tick']
        raw=np.array(Image.open(ROOT/a['source']).convert('RGBA'));w,h=a['size'];palette=set(map(tuple,raw[...,:3][raw[...,3]>0]))
        for row in range(a['rows']):
            fs={v:[np.array(Image.open(f).convert('RGBA')) for f in study.files(name,row,v)] for v in study.VARIANTS}
            for v,images in fs.items():
                assert len(images)==len(a['ticks'][v])
                for im in images:
                    assert im.shape==(h,w,4)
                    assert set(np.unique(im[...,3])).issubset({0,255})
                    assert set(map(tuple,im[...,:3][im[...,3]>0])).issubset(palette)
            for k,original in enumerate(fs['original']):
                assert np.array_equal(original,raw[row*h:(row+1)*h,k*w:(k+1)*w]);key_count+=1
                for v,factor in [('triple',3),('quad',4)]:assert np.array_equal(original,fs[v][k*factor])
            for old,new in zip(study.files(name,row,'double'),study.files(name,row,'quad')[::2]):
                assert old.read_bytes()==new.read_bytes();preserved+=1
            sets={v:{im.tobytes() for im in images} for v,images in fs.items()}
            rows.append(dict(action=name,row=row,unique={v:len(s) for v,s in sets.items()},
                triple_new_vs_double=len(sets['triple']-sets['double']),quad_new_vs_double=len(sets['quad']-sets['double']),
                double_missing_from_triple=len(sets['double']-sets['triple'])))
    changes=[]
    for path,digest in m['protected_hashes'].items():
        current=study.digest(ROOT/path)
        if current!=digest:changes.append(dict(path=path,before=digest,after=current))
    assert not [c for c in changes if c['path'].startswith(('assets/sprites/0004/','docs/charmander_native_actions/'))],changes
    return dict(original_keys_exact=key_count,double_pngs_preserved_exact=preserved,rows=rows,
        native_grid_palette_binary_alpha='pass',original_onsets_events_duration='pass',
        prior_study_unchanged=True,other_work_changes=changes)


def check(job):
    name,a,row,v=job;folder=OUT/'qa-inputs'/name/f'row-{row}'/v;folder.mkdir(exist_ok=True,parents=True)
    inputs=[]
    for file in study.files(name,row,v):
        im=Image.open(file).convert('RGBA');pad=Image.new('RGBA',(im.width+32,im.height+32));pad.paste(im,(16,16))
        dest=folder/file.name;pad.save(dest);inputs.append(dest)
    target=OUT/'forge-qa'/f'{name}-r{row}-{v}'
    code=command([SKILL/'generate2dsprite/scripts/sheet_qc.py','frames','--frames',*inputs,
        '--cycle','walk' if name=='Walk' else 'none','--facing','left' if row in [5,6,7] else 'right',
        '--game-pixel','1','--loop' if a['loop'] else '--no-loop','--output-dir',target],OUT/'logs'/f'qc-{name}-r{row}-{v}.json')
    report=target/'sheet-qc.json'
    call=dict(tool='sheet_qc',action=name,row=row,variant=v,exit_code=code,qa_only_padding=16)
    if not report.exists():return dict(call,status='error'),[]
    r=json.loads(report.read_text());call['status']=r['status'];call['report']=str(report.relative_to(OUT))
    flags=[dict(action=name,row=row,variant=v,report=call['report'],**c) for c in r['checks'] if c['status'] in ['warn','fail']]
    return call,flags


def timing(job,revision=''):
    name,a,v=job;row=min(2,a['rows']-1);paths=study.files(name,row,v)
    factor={'double':2,'triple':3,'quad':4}[v]
    args=[SKILL/'video2dsprite/scripts/retime.py','--frames-dir',paths[0].parent,'--fps',str(60*factor),
          '--kind','walk' if name=='Walk' else 'idle' if a['loop'] else 'other','--spans',f'0:{len(paths)}',
          '--ticks',','.join(map(str,a['ticks'][v])),'--tick-hz','720',
          '--policy','cycle' if a['loop'] else 'oneshot','--output-dir',OUT/f'timing{revision}'/f'{name}-{v}']
    if 'HitFrame'in a['events']:args+=['--impact-source',str(a['events']['HitFrame']['source_frame']*factor)]
    for tag,label in [('RushFrame','rush'),('ReturnFrame','return')]:
        if tag in a['events']:args+=['--event',f"custom:{label}@{a['events'][tag]['at_tick']}t"]
    code=command(args,OUT/f'logs{revision}'/f'retime-{name}-{v}.json')
    return dict(tool='retime',action=name,variant=v,exit_code=code)


def main():
    m=json.loads((OUT/'study.json').read_text());s=numeric(m)
    (OUT/'numeric-qa.json').write_text(json.dumps(s,indent=2)+'\n')
    jobs=[(name,a,r,v) for name,a in m['actions'].items() if not a['alias_of'] for r in range(a['rows']) for v in ['double','triple','quad']]
    calls=[];flags=[]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for done,f in enumerate(as_completed([pool.submit(check,j) for j in jobs]),1):
            c,ff=f.result();calls.append(c);flags+=ff
            if done%50==0:print(f'Frame QA {done}/{len(jobs)}',flush=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        calls+=list(pool.map(timing,[(n,a,v) for n,a in m['actions'].items() if not a['alias_of'] for v in ['double','triple','quad']]))
    s['calls']=calls;s['report_counts']={v:dict(Counter(c['status'] for c in calls if c['tool']=='sheet_qc' and c['variant']==v)) for v in ['double','triple','quad']}
    s['flags']=dict(Counter(f['status'] for f in flags))
    (OUT/'qa-summary.json').write_text(json.dumps(s,indent=2)+'\n');(OUT/'qa-flags.json').write_text(json.dumps(flags,indent=2)+'\n')
    print('Report counts',s['report_counts'],'quality flags',s['flags'],flush=True)
    print('Execution errors',[c for c in calls if c.get('status')=='error' or c['tool']=='retime' and c['exit_code']],flush=True)


if __name__=='__main__':main()
