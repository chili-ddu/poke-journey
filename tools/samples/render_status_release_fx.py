from pathlib import Path
import subprocess,sys
ROOT=Path(__file__).resolve().parents[2];LIB=ROOT.parent/'pixelfx';OUT=ROOT/'docs/status_motion_followup'
r=int(sys.argv[1]);ids=[]
for layer in ['front','back']:
    id=f'status-release-r{r}-{layer}';ids.append('local-review/'+id);p=LIB/f'src/fx/local-review/{id}.js';p.parent.mkdir(exist_ok=True)
    p.write_text(f"// Temporary status followup adapter.\nimport {{makeRelease}} from '{(ROOT/'tools/samples/status_release_fx.mjs').as_uri()}';const fx=makeRelease({r},'{layer}');export const meta=fx.meta;export const draw=fx.draw;\n")
    subprocess.run(['node',str(LIB/'tools/render.mjs'),'local-review/'+id,'--sheet','--all','--zoom','2','--out',str(OUT/f'fx-round{r}')],cwd=LIB,check=True,stdout=subprocess.DEVNULL)
if r==3:
    a=subprocess.run(['node',str(LIB/'tools/check.mjs'),*ids],cwd=LIB,capture_output=True,text=True)
    (OUT/'pixelfx-final-check.txt').write_text(a.stdout+a.stderr);print(a.stdout+a.stderr);a.check_returncode()
print('Rendered status release',r)
