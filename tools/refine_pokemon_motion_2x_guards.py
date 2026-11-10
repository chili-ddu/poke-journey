"""Replace newly flagged passing poses with intact originals, then recheck.

Initial Forge envelopes stay immutable. Only generated atlas cells and their
anchors change. Matching frame indices in all directions and both colours
receive the same conservative fallback; original keys/metadata stay intact.
"""
from pathlib import Path
from collections import defaultdict,Counter
import hashlib,json,argparse,shutil
import xml.etree.ElementTree as ET
from concurrent.futures import ThreadPoolExecutor,as_completed
import numpy as np
from PIL import Image
import audit_pokemon_motion_2x as qa
from bake_pokemon_motion_2x import attach_native_anchors

ROOT=qa.ROOT;BASE=qa.BASE


def main():
    parser=argparse.ArgumentParser(description=__doc__);parser.add_argument('--round',type=int,default=2);parser.add_argument('--conservative-all',action='store_true');args=parser.parse_args()
    previous=BASE/'final-qa-summary.json' if args.round>2 else BASE/'forge-summary.json'
    flagfile=BASE/'final-qa-flags.json' if args.round>2 else BASE/'qa-flags.json'
    initial=json.loads(previous.read_text());flags=json.loads(flagfile.read_text())
    if args.round>2:
        shutil.copyfile(previous,BASE/f'qa-summary-round-{args.round-1}.json')
        shutil.copyfile(flagfile,BASE/f'qa-flags-round-{args.round-1}.json')
    plans=defaultdict(set);jobs=set()
    for error in initial['execution_errors']: jobs.add((error['dex'],error['action'],error['shiny']))
    for f in initial['new_failed_checks']:
        if f['id'] not in ['identity_head_ratio','leg_alternation']:continue
        data=qa.source(f['dex'],f['action'],f['shiny'])
        if not data:continue
        file,node=data;n=len(node.findall('./Durations/Duration'))
        if args.conservative_all:
            frames=set(range(n))
        elif f['id']=='identity_head_ratio':
            indices=f.get('frames',[])
            frames=set(range(n)) if any(i%2==0 for i in indices) else {i//2 for i in indices}
        else:
            indices=[i for pair in f.get('pairs',[]) if pair[-1] is True for i in pair[:2]]
            frames={i//2 for i in indices if i%2}
        if not frames:continue
        for shiny in [False,True]:
            data=qa.source(f['dex'],f['action'],shiny)
            if not data:continue
            path,node=data;count=len(node.findall('./Durations/Duration'))
            plans[path].update(k for k in frames if k<count)
            jobs.add((f['dex'],f['action'],shiny))
    catalog=json.loads((BASE/'catalog.json').read_text());changes=[]
    for file,indices in plans.items():
        path=file.relative_to(ROOT).as_posix();key=hashlib.sha256(path.encode()).hexdigest()[:20]
        cache=BASE/'bake-cache'/f'{key}.json';record=json.loads(cache.read_text());entry=record['entry'];w,h=entry['size']
        raw=Image.open(file).convert('RGBA');n=raw.width//w;rows=raw.height//h
        old=Image.open(ROOT/entry['sheet'].removeprefix('res://')).convert('RGBA');cols=entry['cols']
        cells=[old.crop(((i%cols)*w,(i//cols)*h,(i%cols+1)*w,(i//cols+1)*h)) for i in range((old.width//w)*(old.height//h))]
        slots={im.tobytes():i for i,im in enumerate(cells)};changed=0
        for row in range(rows):
            for k in indices:
                pair=f'{k*w},{row*h},{((k+1)%n)*w},{row*h}'
                if pair not in entry['pairs']:continue
                im=raw.crop((k*w,row*h,(k+1)*w,(row+1)*h));pixels=im.tobytes()
                if pixels not in slots:slots[pixels]=len(cells);cells.append(im)
                if entry['pairs'][pair]!=slots[pixels] or entry['deltas'][pair]!=[0,0,0,0]:changed+=1
                entry['pairs'][pair]=slots[pixels];entry['deltas'][pair]=[0,0,0,0]
        atlas=Image.new('RGBA',(cols*w,((len(cells)+cols-1)//cols)*h))
        for i,im in enumerate(cells):atlas.paste(im,((i%cols)*w,(i//cols)*h))
        atlas.save(ROOT/entry['sheet'].removeprefix('res://'),compress_level=3)
        entry['guard_revision']=args.round-1
        record['post_qa_guarded_intervals']=sorted(indices)
        record['post_qa_guarded_pairs']=changed
        attach_native_anchors(record)
        cache.write_text(json.dumps(record,separators=(',',':'))+'\n')
        catalog['res://'+path]=record['entry']
        changes.append(dict(source=record['source'],source_frames=sorted(indices),all_directions=True,changed_pairs=changed))
    metadata={};normalized=0
    for source,entry in catalog.items():
        file=ROOT/source.removeprefix('res://');xml=file.with_name('AnimData.xml')
        if xml not in metadata:
            metadata[xml]={n.findtext('Name'):[int(v.text) for v in n.findall('./Durations/Duration')] for n in ET.parse(xml).findall('.//Anim') if not n.findtext('CopyOf')}
        ticks=metadata[xml][file.name.removesuffix('-Anim.png')];entry['source_ticks']=ticks
        for pair,hold in entry['holds'].items():
            if ticks[int(pair.split(',')[0])//entry['size'][0]]==1 and hold!=.5:
                entry['holds'][pair]=.5;normalized+=1
    (BASE/'catalog.json').write_text(json.dumps(catalog,separators=(',',':'))+'\n')
    species={}
    for source,entry in catalog.items():species.setdefault(int(source.removeprefix('res://').split('/')[2]),{})[source]=entry
    for dex,entries in species.items():(ROOT/'assets/motion_2x'/f'{dex:04}.json').write_text(json.dumps(entries,separators=(',',':'))+'\n')
    qa.OUT=BASE/f'refinement-{args.round}';qa.OUT.mkdir(exist_ok=True)
    calls=[];new_flags=[];timing=[]
    with ThreadPoolExecutor(max_workers=4) as pool:
        for i,f in enumerate(as_completed([pool.submit(qa.forge_job,j) for j in sorted(jobs)]),1):
            cc,ff,tt=f.result();calls+=cc;new_flags+=ff;timing+=tt
            if i%20==0:print(f'Guard rechecks {i}/{len(jobs)}',flush=True)
    replaced={(c['dex'],c['action'],c['shiny']) for c in calls}
    final_calls=[c for c in initial['calls'] if (c['dex'],c['action'],c['shiny']) not in replaced]
    final_flags=[f for f in flags if (f['dex'],f['action'],f['shiny']) not in replaced]
    for c in calls:
        if 'report' in c:c['report']=f'refinement-{args.round}/'+c['report']
    for f in new_flags:f['report']=f'refinement-{args.round}/'+f['report']
    final_calls+=calls;final_flags+=new_flags
    remaining=[f for f in final_flags if f['variant']=='two' and f['status']=='fail' and not any(x['variant']=='original' and x['status']=='fail' and all(x[k]==f[k] for k in ['dex','action','shiny','id']) for x in final_flags)]
    replacements={(t['dex'],t['action'],t['shiny']):t for t in timing}
    final_timing=[replacements.pop((t['dex'],t['action'],t['shiny']),t) for t in initial['timing']]+list(replacements.values())
    unchanged=[]
    for flag in remaining:
        data=qa.source(flag['dex'],flag['action'],flag['shiny'])
        if not data:continue
        path,node=data;record=qa.cached(path);keys,added,_=qa.frames(path,node,record,min(2,record['rows']-1),True)
        if all(a.tobytes()==b.tobytes() for a,b in zip(added[::2],added[1::2])):
            unchanged.append(dict(dex=flag['dex'],action=flag['action'],shiny=flag['shiny'],id=flag['id'],reason='Every added pose is byte-identical to its source key; frame-count-sensitive heuristic, not new artwork.'))
    report=dict(changes=initial.get('changes',[])+changes,normalized_half_tick_pairs=normalized,rechecked_sets=len(jobs),calls=final_calls,timing=final_timing,
        report_counts=dict(Counter(c['status'] for c in final_calls)),quality_flags=dict(Counter(f['status'] for f in final_flags)),
        new_failed_checks=remaining,source_hold_control_matches=unchanged,execution_errors=[c for c in final_calls if c['status']=='error']+[t for t in final_timing if t['exit_code']])
    (BASE/'final-qa-summary.json').write_text(json.dumps(report,indent=2)+'\n')
    (BASE/'final-qa-flags.json').write_text(json.dumps(final_flags,indent=2)+'\n')
    print('Guarded pairs',sum(c['changed_pairs'] for c in changes),'rechecks',len(jobs),'remaining new failures',len(remaining),'errors',len(report['execution_errors']),flush=True)


if __name__=='__main__':main()
