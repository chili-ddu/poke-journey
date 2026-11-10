from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[2]
LIB=ROOT.parent/'pixelfx'

def main():
    round=int(sys.argv[1]); ids=[]
    for kind in ['fire','water','electric','grass']:
        for layer in ['front','back']:
            id=f'base-r{round}-{kind}-{layer}';ids.append('local-review/'+id)
            path=LIB/f'src/fx/local-review/{id}.js';path.parent.mkdir(exist_ok=True)
            path.write_text(f"// Temporary skill-base adapter.\nimport {{makeBase}} from '{(ROOT/'tools/samples/skill_fx_batch1.mjs').as_uri()}';\nconst fx=makeBase('{kind}','{layer}',{round});export const meta=fx.meta;export const draw=fx.draw;\n")
            subprocess.run(['node',str(LIB/'tools/render.mjs'),'local-review/'+id,'--sheet','--zoom','2','--max','8','--out',str(ROOT/f'docs/skill_fx_bases/batch1/round{round}')],cwd=LIB,check=True)
    if round>=3:
        result=subprocess.run(['node',str(LIB/'tools/check.mjs'),*ids],cwd=LIB,text=True,capture_output=True)
        (ROOT/'docs/skill_fx_bases/batch1/check.txt').write_text(result.stdout+result.stderr)
        print(result.stdout+result.stderr);result.check_returncode()

if __name__=='__main__':main()
