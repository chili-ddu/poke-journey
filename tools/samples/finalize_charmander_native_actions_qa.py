"""Recheck changed inputs and retry tool errors; retain every draft warning."""
import json
import hashlib
from collections import Counter
from concurrent.futures import ThreadPoolExecutor,as_completed
from pathlib import Path
import audit_charmander_native_actions as audit

OUT=audit.OUT


def hashes(files):return [hashlib.sha256(f.read_bytes()).hexdigest() for f in files]


def main():
    m=json.loads((OUT/'study.json').read_text());old=json.loads((OUT/'draft-v1/qa-summary.json').read_text())
    summary=audit.numeric(m);calls=[];flags=[];jobs=[]
    oldcalls={(c['action'],c.get('row'),c['variant']):c for c in old['calls'] if c['tool']=='sheet_qc'}
    for name,a in m['actions'].items():
        if a['alias_of']:continue
        for row in range(a['rows']):
            pair=[oldcalls[(name,row,v)] for v in ['original','added']]
            padded=any(c.get('error') for c in pair) and len(a['original_ticks'])>1
            for v,c in zip(['original','added'],pair):
                files=sorted((OUT/'frames'/name/f'row-{row}'/v).glob('*.png'))
                report=OUT/'forge-qa'/f'{name}-r{row}-{v}'/'sheet-qc.json'
                if len(files)<2 or padded or not report.exists():jobs.append(((name,a,row,v),padded));continue
                r=json.loads(report.read_text())
                if hashes(files)!=[i['sha256'] for i in r['input']['frames']]:jobs.append(((name,a,row,v),False));continue
                calls.append(dict(c,reused_exact_inputs=True,report=str(report.relative_to(OUT))))
                flags += [dict(action=name,row=row,variant=v,report=str(report.relative_to(OUT)),**check)
                          for check in r['checks'] if check['status'] in ['warn','fail']]
    with ThreadPoolExecutor(max_workers=4) as pool:
        futures=[pool.submit(audit.frame_check,j,'-v2',pad) for j,pad in jobs]
        for done,f in enumerate(as_completed(futures),1):
            c,ff=f.result();calls.append(c);flags+=ff
            if done%20==0:print(f'Rechecks {done}/{len(jobs)}',flush=True)
    timingjobs=[]
    for c in [c for c in old['calls'] if c['tool']=='retime']:
        name,v=c['action'],c['variant'];a=m['actions'][name];row=min(2,a['rows']-1)
        selection=OUT/'timing'/f'{name}-{v}'/'selection.json'
        current=hashes(sorted((OUT/'frames'/name/f'row-{row}'/v).glob('*.png')))
        if c['exit_code'] or not selection.exists() or json.loads(selection.read_text())['sourceHashes']!=current:
            timingjobs.append((name,a,v))
        else:calls.append(dict(c,reused_exact_inputs=True))
    with ThreadPoolExecutor(max_workers=4) as pool:
        calls+=list(pool.map(lambda j:audit.timing_check(j,'-v2'),timingjobs))
    calls+=audit.reviews(m,'-v2')
    summary.update(calls=calls,check_flags=dict(Counter(f['status'] for f in flags)),
        report_counts={v:dict(Counter(c.get('status','error') for c in calls if c['tool']=='sheet_qc' and c['variant']==v)) for v in ['original','added']},
        rechecked_frame_sets=len(jobs),retimed_sets=len(timingjobs),draft_reports_retained=True)
    summary['new_failed_check_sets']=[f for f in flags if f['status']=='fail' and f['variant']=='added' and not any(x['action']==f['action'] and x['row']==f['row'] and x['id']==f['id'] and x['status']=='fail' and x['variant']=='original' for x in flags)]
    (OUT/'qa-summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    (OUT/'qa-flags.json').write_text(json.dumps(sorted(flags,key=lambda x:(x['action'],x['row'],x['variant'],x['id'])),indent=2)+'\n')
    print(json.dumps({k:v for k,v in summary.items() if k not in ['rows','calls','new_failed_check_sets']}),flush=True)
    print('New failed checks:',len(summary['new_failed_check_sets']),flush=True)
    print('Remaining execution errors:',[c for c in calls if c.get('error') or c['tool']!='sheet_qc' and c['exit_code']],flush=True)


if __name__=='__main__':main()
