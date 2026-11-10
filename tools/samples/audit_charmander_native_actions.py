"""Actual Forge frame/timing checks for the isolated all-action study."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor, as_completed
from collections import Counter
import hashlib
import json
import subprocess
import sys

import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charmander_native_actions'
SKILL=Path('/Users/ichihun/.codex/skills')


def command(args, log):
    p=subprocess.run([sys.executable,*map(str,args)],capture_output=True,text=True,cwd=ROOT)
    log.parent.mkdir(parents=True,exist_ok=True)
    log.write_text(json.dumps(dict(command=[sys.executable,*map(str,args)],exit_code=p.returncode,
                                   stdout=p.stdout,stderr=p.stderr),indent=2)+'\n')
    return p.returncode


def numeric(m):
    rows=[];keys=0
    for name,a in m['actions'].items():
        w,h=a['size'];source=np.array(Image.open(ROOT/a['source']).convert('RGBA'))
        palette=set(map(tuple,source[...,:3][source[...,3]>0]))
        n=len(a['original_ticks'])
        assert len(a['added_ticks'])==n*2
        assert sum(a['original_ticks'])==sum(a['added_ticks'])==a['duration_ticks']
        assert np.array_equal(np.cumsum([0]+a['original_ticks'][:-1]),np.cumsum([0]+a['added_ticks'][:-1])[::2])
        for event in a['events'].values():
            assert sum(a['original_ticks'][:event['source_frame']])==sum(a['added_ticks'][:event['added_frame']])==event['at_tick']
        for row in range(a['rows']):
            fs={v:[np.array(Image.open(p).convert('RGBA')) for p in sorted((OUT/'frames'/name/f'row-{row}'/v).glob('*.png'))] for v in ['original','added']}
            for v in fs:
                for f in fs[v]:
                    assert f.shape==(h,w,4)
                    assert set(np.unique(f[...,3])).issubset({0,255})
                    assert set(map(tuple,f[...,:3][f[...,3]>0])).issubset(palette)
            for k in range(n):
                assert np.array_equal(source[row*h:(row+1)*h,k*w:(k+1)*w],fs['original'][k])
                assert np.array_equal(fs['original'][k],fs['added'][k*2]);keys+=1
            if not a['loop']:assert np.array_equal(fs['added'][-1],fs['original'][-1])
            changed=[k for k in range(n) if not (np.array_equal(fs['added'][k*2+1],fs['original'][k]) or np.array_equal(fs['added'][k*2+1],fs['original'][(k+1)%n]))]
            rows.append(dict(action=name,row=row,original_unique=len({x.tobytes() for x in fs['original']}),
                             added_unique=len({x.tobytes() for x in fs['added']}),changed_midpoints=len(changed)))
    differences=[]
    for path,digest in m['protected_hashes'].items():
        current=hashlib.sha256((ROOT/path).read_bytes()).hexdigest()
        if current!=digest:
            # Other work can edit shared runtime files while this isolated
            # study runs. Preserve/report them; never reset or conceal them.
            if path.startswith('assets/sprites/0004/'):
                raise AssertionError(f'Original source changed: {path}')
            differences.append(dict(path=path,before=digest,after=current))
    return dict(source_keys_exact=keys,sets=len(rows),native_dimensions_palette_alpha='pass',
                key_onsets_duration_and_events='pass',protected_files_unchanged=len(m['protected_hashes'])-len(differences),
                other_work_file_changes=differences,rows=rows)


def frame_check(job, revision='', padded=False):
    name,a,row,variant=job
    files=sorted((OUT/'frames'/name/f'row-{row}'/variant).glob('*.png'))
    if len(files)<2:
        return dict(tool='sheet_qc',action=name,row=row,variant=variant,exit_code=None,status='skipped_static_single_frame'),[]
    if padded:
        destfiles=[]
        for file in files:
            im=Image.open(file).convert('RGBA');pad=Image.new('RGBA',(im.width+32,im.height+32));pad.paste(im,(16,16))
            target=OUT/'qa-padding'/name/f'row-{row}'/variant/file.name
            target.parent.mkdir(exist_ok=True,parents=True);pad.save(target);destfiles.append(target)
        files=destfiles
    dest=OUT/f'forge-qa{revision}'/f'{name}-r{row}-{variant}'
    cycle='walk' if name=='Walk' else 'none'
    facing='left' if row in [5,6,7] else 'right'
    args=[SKILL/'generate2dsprite/scripts/sheet_qc.py','frames','--frames',*files,
          '--cycle',cycle,'--facing',facing,'--game-pixel','1','--output-dir',dest,
          '--loop' if a['loop'] else '--no-loop']
    code=command(args,OUT/f'logs{revision}'/f'qc-{name}-r{row}-{variant}.json')
    if not (dest/'sheet-qc.json').exists():
        return dict(tool='sheet_qc',action=name,row=row,variant=variant,exit_code=code,error='no published envelope'),[]
    report=json.loads((dest/'sheet-qc.json').read_text())
    flags=[dict(action=name,row=row,variant=variant,report=str((dest/'sheet-qc.json').relative_to(OUT)),**c)
           for c in report['checks'] if c['status'] in ['warn','fail']]
    return dict(tool='sheet_qc',action=name,row=row,variant=variant,exit_code=code,status=report['status'],
                report=str((dest/'sheet-qc.json').relative_to(OUT)),qa_only_padding=16 if padded else 0),flags


def timing_check(job,revision=''):
    name,a,variant=job;row=min(2,a['rows']-1)
    frames=OUT/'frames'/name/f'row-{row}'/variant
    ts=a[f'{variant}_ticks'];kind='walk' if name=='Walk' else 'idle' if a['loop'] else 'other'
    dest=OUT/f'timing{revision}'/f'{name}-{variant}'
    args=[SKILL/'video2dsprite/scripts/retime.py','--frames-dir',frames,'--fps','120',
          '--kind',kind,'--spans',f'0:{len(ts)}','--ticks',','.join(map(str,ts)),
          '--tick-hz','120','--policy','cycle' if a['loop'] else 'oneshot','--output-dir',dest]
    if 'HitFrame' in a['events']:
        e=a['events']['HitFrame'];args+=['--impact-source',str(e['source_frame'] if variant=='original' else e['added_frame'])]
    for tag,label in [('RushFrame','rush'),('ReturnFrame','return')]:
        if tag in a['events']:args+=['--event',f"custom:{label}@{a['events'][tag]['at_tick']}t"]
    code=command(args,OUT/f'logs{revision}'/f'retime-{name}-{variant}.json')
    return dict(tool='retime',action=name,variant=variant,exit_code=code)


def reviews(m,revision='',names=None):
    results=[]
    for name in names or ['Attack','Strike','Charge','Hurt','Hop','Wake']:
        a=m['actions'][name];row=min(2,a['rows']-1)
        for variant in ['original','added']:
            source=OUT/'frames'/name/f'row-{row}'/variant
            expanded=OUT/f'timeline-120hz{revision}'/f'{name}-{variant}'
            expanded.mkdir(exist_ok=True,parents=True);n=0
            for file,length in zip(sorted(source.glob('*.png')),a[f'{variant}_ticks']):
                data=file.read_bytes()
                for _ in range(length):
                    (expanded/f'{n:04d}.png').write_bytes(data);n+=1
            code=command([SKILL/'video2dsprite/scripts/animation_review.py','review',
                '--frames-dir',expanded,'--out-dir',OUT/f'forge-review{revision}'/f'{name}-{variant}',
                '--fps','120','--min-cycle','4','--max-cycle',str(n),'--preview-size','128'],
                OUT/f'logs{revision}'/f'review-{name}-{variant}.json')
            results.append(dict(tool='animation_review',action=name,variant=variant,exit_code=code))
    return results


def main():
    m=json.loads((OUT/'study.json').read_text());summary=numeric(m)
    (OUT/'numeric-qa.json').write_text(json.dumps(summary,indent=2)+'\n')
    jobs=[(name,a,row,v) for name,a in m['actions'].items() if not a['alias_of'] for row in range(a['rows']) for v in ['original','added']]
    calls=[];flags=[]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for done,f in enumerate(as_completed([pool.submit(frame_check,j) for j in jobs]),1):
            c,ff=f.result();calls.append(c);flags+=ff
            if done%40==0:print(f'Frame QA {done}/{len(jobs)}',flush=True)
    print('Timing checks',flush=True)
    with ThreadPoolExecutor(max_workers=4) as pool:
        calls+=list(pool.map(timing_check,[(n,a,v) for n,a in m['actions'].items() if not a['alias_of'] for v in ['original','added']]))
    print('Timing-aware Forge reviewers',flush=True);calls+=reviews(m)
    summary['calls']=calls
    summary['check_flags']=dict(Counter((f['status']) for f in flags))
    summary['report_counts']={v:dict(Counter(c.get('status','error') for c in calls if c['tool']=='sheet_qc' and c['variant']==v)) for v in ['original','added']}
    summary['new_failed_check_sets']=[]
    for f in flags:
        if f['status']=='fail' and f['variant']=='added' and not any(x['action']==f['action'] and x['row']==f['row'] and x['id']==f['id'] and x['status']=='fail' and x['variant']=='original' for x in flags):
            summary['new_failed_check_sets'].append(f)
    (OUT/'qa-flags.json').write_text(json.dumps(sorted(flags,key=lambda x:(x['action'],x['row'],x['variant'],x['id'])),indent=2)+'\n')
    (OUT/'qa-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps({k:v for k,v in summary.items() if k not in ['rows','calls','new_failed_check_sets']}),flush=True)
    print('New failed checks:',len(summary['new_failed_check_sets']),flush=True)
    print('Tool exit counts:',dict(Counter(f"{c['tool']}:{c['exit_code']}" for c in calls)),flush=True)


if __name__=='__main__':main()
