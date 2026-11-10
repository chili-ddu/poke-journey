from pathlib import Path
import subprocess,sys
from PIL import Image
ROOT=Path(__file__).resolve().parents[2];LIB=ROOT.parent/'pixelfx'

def main():
 r=int(sys.argv[1]);base=ROOT/f'docs/skill_fx_bases/category_fill/round{r}';ids=[];images=[]
 for k,l in [('wisp','front'),('wisp','back'),('punch','front')]:
  id=f'fill-r{r}-{k}-{l}';ids.append('local-review/'+id);path=LIB/f'src/fx/local-review/{id}.js'
  path.parent.mkdir(exist_ok=True);path.write_text(f"// Temporary category fill adapter.\nimport {{makeFill}} from '{(ROOT/'tools/samples/skill_fx_category_fill.mjs').as_uri()}';\nconst fx=makeFill('{k}','{l}',{r});export const meta=fx.meta;export const draw=fx.draw;\n")
  subprocess.run(['node',str(LIB/'tools/render.mjs'),'local-review/'+id,'--sheet','--max','8','--zoom','3','--out',str(base)],cwd=LIB,check=True,stdout=subprocess.DEVNULL)
  images.append(Image.open(base/f'local-review/{id}/contact.png').convert('RGB'))
 w=max(i.width for i in images);h=max(i.height for i in images);b=Image.new('RGB',(w,h*3))
 for n,i in enumerate(images):b.paste(i,(0,n*h))
 b.save(base/'all-contact.png')
 if r==3:
  result=subprocess.run(['node',str(LIB/'tools/check.mjs'),*ids],cwd=LIB,capture_output=True,text=True)
  (base.parent/'check.txt').write_text(result.stdout+result.stderr);print(result.stdout+result.stderr);result.check_returncode()
 print('Rendered',r,len(ids),'active layers')

if __name__=='__main__':main()
