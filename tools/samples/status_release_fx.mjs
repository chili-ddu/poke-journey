// Small glints use pixelfx's Sprite Fusion sparkle technique,
// MIT License, Copyright (c) 2026 Hugo Duprez.
import {fit,clamp,sparkle} from '../../../pixelfx/src/core/index.js';
export function makeRelease(round,layer){
 const meta={name:`Status release r${round} ${layer}`,desc:'A brief quiet release of a status, no HP recovery sign or hit burst.',tags:['status','release','oneshot'],size:[80,80],origin:[40,40],duration:.65,loop:false,fps:30,options:{palette:['#52736f','#8ca9a0','#c8d6be','#f3ebcf'],seed:37}};
 function draw(p,t,o){
  if(t>=.60)return;
  const C=fit(o.palette,4),n=round===1?5:round===2?3:2;
  for(let i=0;i<n;i++){
   const back=layer==='back',a=t-i*.065-(back?.04:0);
   if(a<0||a>.28)continue;
   const k=clamp(a/.035)*clamp((.28-a)/.16),x=(back?-1:1)*(10+i*2),y=6-i*9-a*8;
   sparkle(p,x,y,(round===1?4:round===2?3:2)*k,C[3],C[1],k*.85);
  }
 }
 return {meta,draw};
}
