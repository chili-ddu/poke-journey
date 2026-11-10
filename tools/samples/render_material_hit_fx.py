from pathlib import Path
import subprocess,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];LIB=ROOT.parent/'pixelfx'

def main():
 r=int(sys.argv[1]);base=ROOT/f'docs/material_hit_fx/round{r}';ids=[]
 for k in ['electric','ice','poison','psychic']:
  ims=[]
  for d in ['right','left']:
   for l in ['front','back']:
    id=f'material-r{r}-{k}-{d}-{l}';ids.append('local-review/'+id);p=LIB/f'src/fx/local-review/{id}.js'
    p.parent.mkdir(exist_ok=True);p.write_text(f"// Temporary material hit adapter.\nimport {{makeMaterial}} from '{(ROOT/'tools/samples/material_hit_fx.mjs').as_uri()}';\nconst fx=makeMaterial('{k}','{d}','{l}',{r});export const meta=fx.meta;export const draw=fx.draw;\n")
    subprocess.run(['node',str(LIB/'tools/render.mjs'),'local-review/'+id,'--sheet','--max','6','--zoom','2','--out',str(base)],cwd=LIB,check=True,stdout=subprocess.DEVNULL)
    ims.append(Image.open(base/f'local-review/{id}/contact.png').convert('RGB'))
  w=max(i.width for i in ims);h=max(i.height for i in ims);b=Image.new('RGB',(w*2,h*2))
  for n,im in enumerate(ims):b.paste(im,((n%2)*w,(n//2)*h))
  b.save(base/f'{k}-contact.png')
 if r>=3:
  result=subprocess.run(['node',str(LIB/'tools/check.mjs'),*ids],cwd=LIB,text=True,capture_output=True)
  (base.parent/'check.txt').write_text(result.stdout+result.stderr);print(result.stdout+result.stderr);result.check_returncode()
 print('Rendered round',r,len(ids),'layers')

if __name__=='__main__':main()
