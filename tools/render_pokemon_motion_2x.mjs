// Actual pixelfx rendering of supplied native pixels; no character generation.
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import {resolve,dirname} from 'node:path';
import {fileURLToPath,pathToFileURL} from 'node:url';
const root=resolve(dirname(fileURLToPath(import.meta.url)),'..'),lib=resolve(root,'../pixelfx'),out=resolve(root,'docs/pokemon_2x_rollout');
const {createFrame,painterFor,composite,hex}=await import(pathToFileURL(resolve(lib,'src/core/index.js')));
const {encodePNG}=await import(pathToFileURL(resolve(lib,'tools/lib/png.mjs')));
const items=JSON.parse(readFileSync(resolve(out,'pixelfx-input.json'),'utf8'));mkdirSync(resolve(out,'pixelfx-renders'),{recursive:true});
for(const item of items)for(const [name,bg,ink]of [['dark','#222a28','#f1e8d5'],['light','#d7d8c4','#30382e']]){
 const frame=createFrame(384,216),p=painterFor(frame);
 for(let side=0;side<2;side++){const a=item.variants[side];p.text(`${item.id} ${side?'MID':'KEY'}`,side*192+7,8,hex(ink));p.sprite(a.rows,a.palette,side*192+96-Math.floor(a.width/2),110-Math.floor(a.height/2));}
 const rgba=new Uint8ClampedArray(384*216*4);composite(frame,rgba,hex(bg));
 writeFileSync(resolve(out,`pixelfx-renders/${item.id}-${name}.png`),encodePNG(384,216,rgba));
}
console.log(`Actual pixelfx native comparison renders: ${items.length*2}; no generated character art.`);
