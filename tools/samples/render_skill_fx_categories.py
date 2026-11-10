from pathlib import Path
import subprocess,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];LIB=ROOT.parent/'pixelfx'
KINDS=['fang','tail','shell','paralyze','petal','sleep']

def main():
 r=int(sys.argv[1]);base=ROOT/f'docs/skill_fx_bases/category_samples/round{r}';ids=[];images=[]
 for k in KINDS:
  for l in ['front','back']:
   id=f'category-r{r}-{k}-{l}'
   ids.append('local-review/'+id) if not (r==3 and ((k in ['fang','tail'] and l=='back') or (k=='paralyze' and l=='front'))) else None
   path=LIB/f'src/fx/local-review/{id}.js';path.parent.mkdir(exist_ok=True)
   path.write_text(f"// Temporary category FX adapter.\nimport {{makeCategory}} from '{(ROOT/'tools/samples/skill_fx_categories.mjs').as_uri()}';\nconst fx=makeCategory('{k}','{l}',{r});export const meta=fx.meta;export const draw=fx.draw;\n")
   subprocess.run(['node',str(LIB/'tools/render.mjs'),'local-review/'+id,'--sheet','--max','6','--zoom','2','--out',str(base)],cwd=LIB,check=True,stdout=subprocess.DEVNULL)
   images.append(Image.open(base/f'local-review/{id}/contact.png').convert('RGB'))
 w=max(i.width for i in images);h=max(i.height for i in images);board=Image.new('RGB',(w*2,h*len(KINDS)))
 for n,i in enumerate(images):board.paste(i,((n%2)*w,(n//2)*h))
 board.save(base/'all-contact.png')
 if r==3:
  result=subprocess.run(['node',str(LIB/'tools/check.mjs'),*ids],cwd=LIB,text=True,capture_output=True)
  (base.parent/'check.txt').write_text(result.stdout+result.stderr);print(result.stdout+result.stderr);result.check_returncode()
 print('Rendered and assembled',r,len(ids),'layers')

if __name__=='__main__':main()
