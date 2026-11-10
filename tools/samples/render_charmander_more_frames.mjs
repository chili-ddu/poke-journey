// Real pixelfx Painter render of supplied pixels at native size, two backgrounds.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {resolve,dirname} from 'node:path';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..'),lib=resolve(root,'../pixelfx');
const {createFrame,painterFor,composite,hex}=await import(pathToFileURL(resolve(lib,'src/core/index.js')));
const {encodePNG}=await import(pathToFileURL(resolve(lib,'tools/lib/png.mjs')));
const out=resolve(root,'docs/charmander_more_frames'),items=JSON.parse(readFileSync(resolve(out,'pixelfx-input.json'),'utf8'));
mkdirSync(resolve(out,'pixelfx-renders'),{recursive:true});
for(const item of items)for(const [bg,color,ink]of [['dark','#222a28','#f1e8d5'],['light','#d7d8c4','#30382e']]){
  const frame=createFrame(384,216),p=painterFor(frame);
  for(let side=0;side<2;side++){const a=item.variants[side];p.text(`${item.action.toUpperCase()} ${side?'4X FRAMES':'2X FRAMES'}`,side*192+7,8,hex(ink));p.text('NATIVE PIXELS',side*192+7,20,hex(ink));p.sprite(a.rows,a.palette,side*192+96-a.width/2,120-a.height/2);}
  const rgba=new Uint8ClampedArray(384*216*4);composite(frame,rgba,hex(color));
  writeFileSync(resolve(out,`pixelfx-renders/${item.action}-${String(item.key).padStart(3,'0')}-${bg}.png`),encodePNG(384,216,rgba));
}
console.log(`pixelfx: ${items.length*2} native-size 2x/4x comparisons rendered.`);
