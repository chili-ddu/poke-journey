// Stepped material flow and gravity reference pixelfx / Sprite Fusion fire and
// water techniques, MIT Copyright (c) 2026 Hugo Duprez. No character drawing.
import {fit,clamp,rng} from '../../../pixelfx/src/core/index.js';
const PAL={fire:['#875030','#b76e32','#d9913b','#edb658','#f4d38b'],water:['#3d6376','#6398ac','#94bdc9','#c4dadb','#e7e9db']};
const ENTRY={right:Math.PI,left:0,front:Math.PI/2,back:-Math.PI/2};
const angular=(a,b)=>Math.abs(Math.atan2(Math.sin(a-b),Math.cos(a-b)));
export function makeDirectional(kind,direction,layer,round=1){
 const meta={name:`Directional ${kind} ${direction} ${layer}`,desc:'Contact spreads from the incoming surface; gravity and fire rise stay upright.',tags:[kind,'directional','impact','body','one-shot'],size:[64,64],origin:[32,32],duration:1,loop:false,fps:30,bg:'dark',options:{palette:round>=4?(kind==='fire'?['#995c2e','#d68b36','#e9aa49','#f0c66c','#f7dfa4']:['#375f76','#4f96b7','#78bdcf','#afdce0','#e1eeee']):PAL[kind],seed:51}};
 const draw=(p,time,o)=>{
  if(time<=0||time>=.9)return;
  const t=Math.floor(time*24)/24,C=fit(o.palette,5),front=layer==='front',entry=ENTRY[direction],endFade=clamp((.9-time)/.20);
  for(let x=-19;x<=19;x++){
   const theta=(front?1:-1)*Math.acos(clamp(x/19,-1,1));
   const distance=angular(theta,entry),delay=distance*(kind==='fire'?.10:.045);
   const age=t-delay;if(age<0)continue;
   const attack=clamp(age/(kind==='fire'?.06:.035));
   if(kind==='fire'){
    const localFade=clamp((.72-age)/.3)*attack*endFade;
    const top=(round>=4?-8:-3)-Math.sin(theta*3+t*7)*4-(round>=2?Math.sin(theta*5-t*9)*2:0);
    const bottom=21-Math.cos(theta*2)*2;
    for(let y=Math.ceil(top);y<bottom;y++){
     if(front && Math.abs(x)<11 && y<(round>=4?9:round>=3?5:1))continue;
     const flow=round>=4?Math.sin(theta*5+Math.sin(y*.20+t*8)*1.8)+.6*Math.sin(theta*9-y*.12+t*4):Math.sin(y*.43+t*12+theta*3)+Math.sin(y*.24+t*7-theta*4)*.75;
     if(flow<(round>=2?.05:-.3))continue;
     const heat=flow+(y-top<2?-.7:0);
     const idx=heat>1.5?4:heat>.9?3:heat>.3?2:1;
     p.blend(x,y,C[idx],localFade*(front?(round>=3?.65:.8):.95));
    }
   }else{
    if(age>.60)continue;
    const localFade=attack*clamp((.60-age)/.20)*endFade;
    const center=3+age*27+Math.sin(theta*2-t*4)*1.6;
    const thick=(round>=2?4.5:7)*(1-age/.7);
    for(let y=Math.floor(center-thick);y<=center+thick;y++){
     const q=(y-center)/Math.max(thick,.1);
     if(front&&y<1&&Math.abs(x)<8)continue;
     if(round>=3 && age>.15 && Math.sin(x*.65+theta*3)<-.35)continue;
     p.blend(x,y,C[q<-.5?4:q<0?3:1],localFade*(front?(round>=4?.55:.65):.85));
    }
   }
  }
  if(kind==='water'){
   const exit=entry+Math.PI,exitFront=Math.sin(exit)>=0;
   const sx=direction==='right'?1:direction==='left'?-1:0;
   const depth=direction==='back'?1:direction==='front'?-1:0;
   for(let i=0;i<6;i++){
    if((i%3===0?!exitFront:exitFront)!==front)continue;
    const R=rng(o.seed,i),age=t-.10-i*.016;if(age<0||age>.32)continue;
    const x=Math.cos(exit)*17+R.range(-2,2)+age*(sx*24+R.range(-9,9));
    const y=6+age*(depth*8-12+R.range(-4,4))+age*age*65;
    const k=clamp((.32-age)/.14)*endFade;
    p.blend(x,y,C[3],k);p.blend(x,y+1,C[1],k);
    if(round<3)p.blend(x+1,y,C[2],k*.5);
   }
  }
 };
 return {meta,draw};
}
