"""Whole-roster preservation checks and real Sprite Forge frame/timing QA.

Numeric checks cover every baked sheet, normal and shiny. Forge reports cover
all 493 normal Walk sets plus selected body types/actions and shiny sets. Raw
WARN/FAIL checks are retained, with baseline comparisons; they are not anatomy
approval. Padding for the Forge tool is documented and never enters the game.
"""
from pathlib import Path
from collections import Counter
from concurrent.futures import ThreadPoolExecutor,as_completed
import argparse
import hashlib
import json
import subprocess
import sys
import time
import xml.etree.ElementTree as ET
import numpy as np
from PIL import Image

ROOT=Path(__file__).resolve().parents[1]
BASE=ROOT/'docs/pokemon_2x_rollout'
OUT=BASE
SKILLS=Path.home()/'.codex/skills'
LOOPS={'Walk','Idle','Sleep','Charge','Dance','Rotate','Hover','FlapAround'}
REPRESENTATIVES=[1,4,6,7,16,23,25,41,95,130,132,143,201,208,230,249,282,350,376,384,389,393,426,445,487,493]


def sha(p):return hashlib.sha256(p.read_bytes()).hexdigest()


def source(dex,action,shiny=False):
    folder=ROOT/'assets/sprites'/f'{dex:04}'
    if shiny:folder/='shiny'
    nodes={n.findtext('Name'):n for n in ET.parse(folder/'AnimData.xml').findall('.//Anim')}
    seen=set();name=action
    while name in nodes and nodes[name].findtext('CopyOf') and name not in seen:
        seen.add(name);name=nodes[name].findtext('CopyOf')
    if name not in nodes:return None
    file=folder/(name+'-Anim.png')
    return (file,nodes[name]) if file.exists() else None


def cached(file):
    path=file.relative_to(ROOT).as_posix();key=hashlib.sha256(path.encode()).hexdigest()[:20]
    report=BASE/'bake-cache'/f'{key}.json'
    deadline=time.monotonic()+3600
    while not report.exists():
        if time.monotonic()>deadline:raise TimeoutError(str(report))
        time.sleep(.5)
    return json.loads(report.read_text())


def frames(file,node,record,row,loop):
    raw=Image.open(file).convert('RGBA');e=record['entry'];w,h=e['size'];n=len(node.findall('./Durations/Duration'))
    atlas=Image.open(ROOT/e['sheet'].removeprefix('res://')).convert('RGBA');keys=[];added=[];ticks=[]
    for k,duration in enumerate(node.findall('./Durations/Duration')):
        a=raw.crop((k*w,row*h,(k+1)*w,(row+1)*h));keys.append(a);added.append(a)
        pair=f'{k*w},{row*h},{((k+1)%n)*w},{row*h}'
        if pair in e['pairs'] and (loop or k<n-1):
            slot=e['pairs'][pair];x=(slot%e['cols'])*w;y=(slot//e['cols'])*h
            added.append(atlas.crop((x,y,x+w,y+h)))
        else:added.append(a)
        hold=e['holds'].get(pair,.5);total=2*int(duration.text)
        first=max(1,min(total-1,round(total*hold)));ticks.extend([first,total-first])
    return keys,added,ticks


def command(args,log):
    log.parent.mkdir(parents=True,exist_ok=True)
    result=subprocess.run([sys.executable,*map(str,args)],cwd=ROOT,text=True,capture_output=True)
    log.write_text(json.dumps(dict(argv=list(map(str,args)),exit_code=result.returncode,stdout=result.stdout,stderr=result.stderr),indent=2)+'\n')
    return result.returncode


def forge_job(job):
    dex,action,shiny=job;data=source(dex,action,shiny)
    if not data:return [],[],[]
    file,node=data;record=cached(file);row=min(2,record['rows']-1);keys,added,ticks=frames(file,node,record,row,action in LOOPS)
    name=f'{dex:04}-{action}'+('-shiny' if shiny else '')
    calls=[];flags=[];inputs={}
    for variant,images in [('original',keys),('two',added)]:
        folder=OUT/'qa-inputs'/name/variant;folder.mkdir(parents=True,exist_ok=True)
        files=[]
        for k,im in enumerate(images):
            padded=Image.new('RGBA',(im.width+32,im.height+32));padded.paste(im,(16,16))
            f=folder/f'{k:03}.png'
            if not f.exists():padded.save(f)
            files.append(f)
        inputs[variant]=files
        dest=OUT/'forge-qa'/f'{name}-{variant}';report=dest/'sheet-qc.json'
        executed=not report.exists()
        code=command([SKILLS/'generate2dsprite/scripts/sheet_qc.py','frames','--frames',*files,
            '--cycle','walk' if action=='Walk' else 'none','--facing','right','--game-pixel','1',*(['--head-frac','0.55'] if dex==50 else []),
            '--loop' if action in LOOPS else '--no-loop','--output-dir',dest],OUT/'logs'/f'forge-{name}-{variant}.json') if executed else None
        if not report.exists():
            calls.append(dict(dex=dex,action=action,shiny=shiny,variant=variant,status='error',exit_code=code));continue
        result=json.loads(report.read_text())
        call=dict(dex=dex,action=action,shiny=shiny,variant=variant,status=result['status'],exit_code=code,executed=executed,report=str(report.relative_to(OUT)))
        calls.append(call)
        flags.extend(dict(dex=dex,action=action,shiny=shiny,variant=variant,report=call['report'],**c) for c in result['checks'] if c['status'] in ['warn','fail'])
    timing=[]
    if dex in REPRESENTATIVES and action in {'Walk','Attack','Hop'}:
        # Every original key remains at the same 120-Hz onset in this selection.
        folder=OUT/'timing-inputs'/name;folder.mkdir(parents=True,exist_ok=True)
        for k,im in enumerate(added):im.save(folder/f'{k:03}.png')
        dest=OUT/'timing'/name
        if not dest.exists():
            args=[SKILLS/'video2dsprite/scripts/retime.py','--frames-dir',folder,'--fps','120','--kind','walk' if action=='Walk' else 'other',
                '--spans',f'0:{len(added)}','--ticks',','.join(map(str,ticks)),'--tick-hz','120','--policy','cycle' if action in LOOPS else 'oneshot','--output-dir',dest]
            hit=node.findtext('HitFrame')
            if hit is not None:args.extend(['--impact-source',str(int(hit)*2)])
            code=command(args,OUT/'logs'/f'retime-{name}.json')
            timing.append(dict(dex=dex,action=action,shiny=shiny,tool='retime',exit_code=code))
    return calls,flags,timing


def forge(jobs):
    calls=[];flags=[];timing=[]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for i,f in enumerate(as_completed([pool.submit(forge_job,j) for j in jobs]),1):
            cc,ff,tt=f.result();calls+=cc;flags+=ff;timing+=tt
            if i%25==0:print(f'Forge paired sets {i}/{len(jobs)}',flush=True)
    new=[]
    for flag in flags:
        if flag['variant']!='two' or flag['status']!='fail':continue
        if not any(x['variant']=='original' and x['status']=='fail' and all(x[k]==flag[k] for k in ['dex','action','shiny','id']) for x in flags):new.append(flag)
    result=dict(scope='All normal Walk right-facing sets; representative additional actions and shiny forms. Native padded by 16 pixels for QA only.',
        calls=calls,timing=timing,report_counts=dict(Counter(c['status'] for c in calls)),quality_flags=dict(Counter(f['status'] for f in flags)),
        new_failed_checks=new,execution_errors=[c for c in calls if c['status']=='error']+[t for t in timing if t['exit_code']])
    (OUT/'forge-summary.json').write_text(json.dumps(result,indent=2)+'\n')
    (OUT/'qa-flags.json').write_text(json.dumps(flags,indent=2)+'\n')
    print('Forge reports',result['report_counts'],'quality flags',result['quality_flags'],'new failed checks',len(new),'execution errors',len(result['execution_errors']),flush=True)


def numeric():
    manifest=json.loads((OUT/'catalog.json').read_text());summary=json.loads((OUT/'bake-summary.json').read_text())
    originals=json.loads((OUT/'original-art-before.json').read_text())
    changed=[p for p,h in originals.items() if sha(ROOT/p)!=h]
    assert not changed,changed
    results=[];pairs=0
    for i,(source_path,e) in enumerate(manifest.items(),1):
        file=ROOT/source_path.removeprefix('res://');raw=np.array(Image.open(file).convert('RGBA'))
        a=np.array(Image.open(ROOT/e['sheet'].removeprefix('res://')).convert('RGBA'))
        assert e['steps']==2 and set(np.unique(a[...,3])).issubset({0,255}),file
        pack=lambda x:(x[...,0].astype('uint32')<<16)|(x[...,1].astype('uint32')<<8)|x[...,2].astype('uint32')
        colors=np.unique(pack(raw)[raw[...,3]>0]);generated=np.unique(pack(a)[a[...,3]>0])
        assert np.isin(generated,colors).all(),file
        w,h=e['size'];capacity=(a.shape[0]//h)*(a.shape[1]//w)
        assert a.shape[1]==w*e['cols'] and a.shape[0]%h==0,file
        for key,slot in e['pairs'].items():
            x,y,nx,ny=map(int,key.split(','));assert all([x%w==0,nx%w==0,y%h==0,ny%h==0,0<=slot<capacity])
            assert 0<=x<raw.shape[1] and 0<=nx<raw.shape[1] and 0<=y<raw.shape[0] and 0<=ny<raw.shape[0]
            assert 0<e['holds'][key]<1 and 0<e['weights'][key]<1
            assert len(e['deltas'][key])==4 and all(isinstance(d,int) for d in e['deltas'][key])
        pairs+=len(e['pairs']);results.append(dict(source=source_path,sha256=sha(file),pairs=len(e['pairs']),palette='source_only',alpha='binary',native_cell=[w,h]))
        if i%1000==0:print(f'Numeric sheets {i}/{len(manifest)}',flush=True)
    assert len({r['dex'] for r in summary['sources']})==493
    assert len({(r['dex'],r['shiny']) for r in summary['sources']})==986
    result=dict(species=493,sets=986,sheets=len(results),pair_slots=pairs,protected_existing_files=len(originals),original_changes=changed,
        native_size_palette_alpha='pass',source_keys_xml_durations_rush_hit_return='byte_preserved',sources=results)
    (OUT/'numeric-qa.json').write_text(json.dumps(result,indent=2)+'\n')
    print({k:v for k,v in result.items() if k!='sources'},flush=True)


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('stage',choices=['numeric','forge']);args=parser.parse_args()
    if args.stage=='numeric':numeric();return
    jobs=[(d,'Walk',False) for d in range(1,494)]
    jobs += [(d,a,False) for d in REPRESENTATIVES for a in ['Idle','Attack','Hop','Hurt','Sleep']]
    jobs += [(d,'Walk',True) for d in REPRESENTATIVES]
    forge(jobs)


if __name__=='__main__':main()
