"""Run the installed sprite/animation skill tools on existing authored frames."""
from pathlib import Path
import json,sys,subprocess,hashlib,xml.etree.ElementTree as ET
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/status_motion_followup';PY=sys.executable
SKILLS=Path('/Users/ichihun/.codex/skills')

def run(args,log):
    r=subprocess.run(args,cwd=ROOT,text=True,capture_output=True)
    log.write_text(r.stdout+r.stderr)
    return {'command':args,'returncode':r.returncode,'log':str(log.relative_to(ROOT))}

def main():
    if '--encoded-only' in sys.argv:
        results=json.loads((OUT/'skill-tool-results.json').read_text())
        for job in results['jobs']:
            dex,action=job['dex'],job['action'];name=f'{dex:04d}-{action.lower()}'
            source=OUT/'frames'/name;selection=OUT/'retimed'/name/'selection.json';package=OUT/'packages-webm'/name
            commands=[]
            commands.append(run([PY,str(SKILLS/'video2dsprite/scripts/engine_export.py'),'package','--clean-dir',str(source),'--selection',str(selection),
                '--name',action.lower(),'--source-size','160,160','--source-anchor','80,104','--formats','png,webm','--crf-webm','0','--pixel-art','--sampling','nearest','--key','none',
                '--art-source','existing','--output-dir',str(package)],OUT/f'encoded-package-{dex}-{action}.log'))
            if commands[-1]['returncode']==0:
                commands.append(run([PY,str(SKILLS/'video2dsprite/scripts/engine_export.py'),'verify','--package',str(package)],OUT/f'encoded-verify-{dex}-{action}.log'))
                commands.append(run([PY,str(SKILLS/'video2dsprite/scripts/validate_animation.py'),str(package),'--require-verify'],OUT/f'encoded-validate-{dex}-{action}.log'))
            job['encoded_commands']=commands
            print('encoded',dex,action,[c['returncode'] for c in commands],flush=True)
        (OUT/'skill-tool-results-encoded.json').write_text(json.dumps(results,indent=2)+'\n')
        return
    inventory=json.loads((OUT/'source-inventory.json').read_text());checks=[]
    for row in inventory:
        folder=ROOT/Path(row['path']).parent
        metadata={a.findtext('Name'):a for a in ET.parse(folder/'AnimData.xml').getroot().findall('.//Anim')}
        for action in ['Idle','Sleep','Hurt','Charge']:
            source_name=action
            while metadata[source_name].findtext('CopyOf'):source_name=metadata[source_name].findtext('CopyOf')
            a=metadata[source_name];source=folder/(source_name+'-Anim.png')
            with Image.open(source) as im:
                fw,fh=int(a.findtext('FrameWidth')),int(a.findtext('FrameHeight'));durations=[int(x.text) for x in a.findall('Durations/Duration')];n=len(durations)
                assert im.width==fw*n and im.height%fh==0,(source,im.size)
                assert all(v>0 for v in durations)
                checks.append({'dex':row['dex'],'action':action,'rows':im.height//fh,'frames':n,'sha256':hashlib.sha256(source.read_bytes()).hexdigest()})
    (OUT/'all-species-grid-checks.json').write_text(json.dumps(checks,indent=2)+'\n')
    jobs=[]
    for dex in [4,6,25,95]:
        for action in ['Sleep','Charge','Wake']:
            folder=ROOT/f'assets/sprites/{dex:04d}' if action!='Wake' else OUT/f'source-extra/{dex:04d}'
            if not (folder/(action+'-Anim.png')).exists():continue
            meta={a.findtext('Name'):a for a in ET.parse(folder/'AnimData.xml').getroot().findall('.//Anim')}
            a=meta[action];source=a.findtext('CopyOf') or action;a=meta[source]
            fw,fh=int(a.findtext('FrameWidth')),int(a.findtext('FrameHeight'));ticks=[int(x.text) for x in a.findall('Durations/Duration')]
            # Match the live wake entry; don't include the incompatible lying frame.
            start=({4:1,25:1}.get(dex,max(0,len(ticks)-2))) if action=='Wake' else 0
            folder_out=OUT/f'frames/{dex:04d}-{action.lower()}';folder_out.mkdir(parents=True,exist_ok=True)
            im=Image.open(folder/(source+'-Anim.png')).convert('RGBA')
            for i in range(start,len(ticks)):
                cell=im.crop((i*fw,0,(i+1)*fw,fh));frame=Image.new('RGBA',(160,160));frame.paste(cell,(80-fw//2,104-fh//2));frame.save(folder_out/f'{i-start:03}.png')
            qa=OUT/f'qa/{dex:04d}-{action.lower()}';qa.parent.mkdir(exist_ok=True)
            commands=[]
            commands.append(run([PY,str(SKILLS/'generate2dsprite/scripts/sheet_qc.py'),'frames','--frames',*[str(p) for p in sorted(folder_out.glob('*.png'))],
                '--cycle','none','--loop' if action=='Sleep' else '--no-loop','--key','none','--output-dir',str(qa)],OUT/f'qa-{dex}-{action}.log'))
            retime=OUT/f'retimed/{dex:04d}-{action.lower()}'
            commands.append(run([PY,str(SKILLS/'video2dsprite/scripts/retime.py'),'--frames-dir',str(folder_out),'--fps','60','--spans',f'0:{len(ticks)-start}',
                '--ticks',','.join(map(str,ticks[start:])),'--kind','idle' if action=='Sleep' else 'other','--policy','cycle' if action=='Sleep' else 'oneshot','--output-dir',str(retime)],OUT/f'retime-{dex}-{action}.log'))
            package=OUT/f'packages/{dex:04d}-{action.lower()}'
            commands.append(run([PY,str(SKILLS/'video2dsprite/scripts/engine_export.py'),'package','--clean-dir',str(folder_out),'--selection',str(retime/'selection.json'),
                '--name',action.lower(),'--source-size','160,160','--source-anchor','80,104','--formats','png','--pixel-art','--sampling','nearest','--key','none',
                '--art-source','existing','--output-dir',str(package)],OUT/f'package-{dex}-{action}.log'))
            if commands[-1]['returncode']==0:
                commands.append(run([PY,str(SKILLS/'video2dsprite/scripts/engine_export.py'),'verify','--package',str(package)],OUT/f'verify-{dex}-{action}.log'))
                commands.append(run([PY,str(SKILLS/'video2dsprite/scripts/validate_animation.py'),str(package),'--require-verify'],OUT/f'validate-{dex}-{action}.log'))
            jobs.append({'dex':dex,'action':action,'first_source_frame':start,'commands':commands})
            print(dex,action,[c['returncode'] for c in commands],flush=True)
    (OUT/'skill-tool-results.json').write_text(json.dumps({'source_grid_checks':len(checks),'jobs':jobs},indent=2)+'\n')

if __name__=='__main__':main()
