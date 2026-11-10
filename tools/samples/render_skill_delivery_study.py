"""Use actual pixelfx CLI on generic cast/travel studies, never hit art."""
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import argparse,json,subprocess
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2];LIB=ROOT.parent/'pixelfx';OUT=ROOT/'docs/skill_delivery_study'
KINDS=['fire','water','electric','leaf','wind','psychic']
CHOSEN=dict(fire='material',water='ribbon',electric='ribbon',leaf='material',wind='ribbon',psychic='quiet')


def main():
    parser=argparse.ArgumentParser();parser.add_argument('round',type=int);args=parser.parse_args();r=args.round
    base=OUT/f'round{r}';base.mkdir(parents=True,exist_ok=True);adapters=LIB/'src/fx/local-review';adapters.mkdir(exist_ok=True)
    jobs=[]
    for kind in KINDS:
        styles=['material','ribbon','quiet'] if r==1 else [CHOSEN[kind]]
        for style in styles:
            for stage in (['flight'] if r==1 else ['flight','cast']):
                name=f'delivery-r{r}-{kind}-{style}-{stage}';id='local-review/'+name
                adapter=adapters/f'{name}.js';adapter.write_text(f"// Temporary generic delivery adapter.\nimport {{makeDelivery}} from '{(ROOT/'tools/samples/skill_delivery_study.mjs').as_uri()}';\nconst fx=makeDelivery('{kind}','{style}',{r},'{stage}');export const meta=fx.meta;export const draw=fx.draw;\n")
                jobs.append(dict(kind=kind,style=style,stage=stage,id=id,adapter=str(adapter)))
    def render(job):
        command=['node',str(LIB/'tools/render.mjs'),job['id'],'--sheet','--max','6','--zoom','3','--no-actor','--out',str(base)]
        p=subprocess.run(command,cwd=LIB,capture_output=True,text=True)
        (base/(job['id'].split('/')[1]+'.log')).write_text(p.stdout+p.stderr)
        assert p.returncode==0,(job,p.stderr)
        return job
    with ThreadPoolExecutor(max_workers=3) as pool:list(pool.map(render,jobs))
    # Contact strips keep the renderer's own frames and names visible.
    for kind in KINDS:
        selected=[j for j in jobs if j['kind']==kind]
        images=[Image.open(base/j['id']/'contact.png').convert('RGB') for j in selected]
        w=max(i.width for i in images);h=max(i.height for i in images);board=Image.new('RGB',(w,h*len(images)),(20,22,26))
        for i,im in enumerate(images):board.paste(im,(0,i*h))
        board.save(base/f'{kind}-contact.png')
    (base/'jobs.json').write_text(json.dumps(jobs,indent=2)+'\n')
    if r>=3:
        p=subprocess.run(['node',str(LIB/'tools/check.mjs'),*[j['id'] for j in jobs]],cwd=LIB,capture_output=True,text=True)
        (OUT/'check-final.txt').write_text(p.stdout+p.stderr);print(p.stdout+p.stderr);assert p.returncode==0
    print(f'Actual pixelfx delivery round {r}: {len(jobs)} assets',flush=True)


if __name__=='__main__':main()
