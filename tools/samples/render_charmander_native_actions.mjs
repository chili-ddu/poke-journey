// Actual pixelfx rendering of supplied original/derived PNG pixel data.
// No stock actor, glow, new VFX or character generation is involved.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {fileURLToPath,pathToFileURL} from 'node:url';
import {resolve,dirname} from 'node:path';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const library=resolve(root,'../pixelfx');
const {createFrame,painterFor,composite,hex}=await import(pathToFileURL(resolve(library,'src/core/index.js')));
const {encodePNG}=await import(pathToFileURL(resolve(library,'tools/lib/png.mjs')));
const out=resolve(root,'docs/charmander_native_actions');
const items=JSON.parse(readFileSync(resolve(out,'pixelfx-input.json'),'utf8'));
mkdirSync(resolve(out,'pixelfx-renders'),{recursive:true});
for(const item of items){
  for(const [bg,color,text]of [['dark','#222a28','#f1e8d5'],['light','#d7d8c4','#30382e']]){
    const frame=createFrame(384,216),p=painterFor(frame);
    for(let side=0;side<2;side++){
      const art=item.variants[side];
      p.text(`${item.action.toUpperCase()} ${side?'ADDED':'ORIGINAL'}`,side*192+7,8,hex(text));
      p.text(`${side?item.key+1:Math.floor(item.key/2)+1}  1X`,side*192+7,20,hex(text));
      p.sprite(art.rows,art.palette,side*192+96-art.width/2,120-art.height/2);
    }
    const rgba=new Uint8ClampedArray(384*216*4);composite(frame,rgba,hex(color));
    writeFileSync(resolve(out,`pixelfx-renders/${item.action}-${String(item.key).padStart(3,'0')}-${bg}.png`),encodePNG(384,216,rgba));
  }
}
console.log(`pixelfx: ${items.length*2} original/new pose comparisons rendered at 384x216.`);
