// Render supplied existing sprites; pixelfx does not generate the character.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { resolve, dirname } from 'node:path';

const root=resolve(dirname(fileURLToPath(import.meta.url)),'../..');
const library=resolve(root,'../pixelfx');
const {createFrame,painterFor,composite,hex}=await import(pathToFileURL(resolve(library,'src/core/index.js')));
const {encodePNG}=await import(pathToFileURL(resolve(library,'tools/lib/png.mjs')));
const dest=resolve(root,'docs/charmander_pixelfx_sample_v1');
const manifest=JSON.parse(readFileSync(resolve(dest,'render-input.json'),'utf8'));
for(const [name,bg,inkText] of [['dark',0xff33382e,'#eee9da'],['light',0xffc3d4db,'#382e2b']]){
  const ink=hex(inkText);
  for(const item of manifest.frames){
    const frame=createFrame(384,312),p=painterFor(frame);
    for(let side=0;side<2;side++){
      const offset=side*192,art=item.variants[side];
      p.text(side?'REFERENCE EDIT':'ORIGINAL',offset+8,9,ink);
      p.text(`${item.action.toUpperCase()} ${item.key+1}`,offset+8,20,ink);
      p.sprite(art.large.rows,art.large.palette,offset+32,34,{scale:2});
      p.text('32X40      64X80',offset+24,208,ink);
      p.sprite(art.small.rows,art.small.palette,offset+32,244);
      p.sprite(art.large.rows,art.large.palette,offset+100,220);
    }
    const rgba=new Uint8ClampedArray(frame.w*frame.h*4);
    composite(frame,rgba,bg);
    writeFileSync(resolve(dest,`renders/${name}-${item.action}-${item.key}.png`),encodePNG(frame.w,frame.h,rgba));
  }
}
console.log('pixelfx Painter.sprite + composite: 16 matched comparison renders (two backgrounds)');
