// Directed material fronts use pixelfx / Sprite Fusion fire and water techniques,
// MIT Copyright (c) 2026 Hugo Duprez. No character art or gameplay changes.
import {fit,clamp,rng} from '../../../pixelfx/src/core/index.js';
const PAL={fire:['#995c2e','#d68b36','#e9aa49','#f0c66c','#f7dfa4'],water:['#375f76','#4f96b7','#78bdcf','#afdce0','#e1eeee']};
export function makeTravel(kind,direction,layer,round=5){
 const meta={name:`Impact travel ${kind} ${direction} ${layer}`,desc:'A compact contact front advances to the opposite surface; the entry clears first.',tags:[kind,'directional','impact','body','one-shot'],size:[64,64],origin:[32,32],duration:1,loop:false,fps:30,bg:'dark',options:{palette:PAL[kind],seed:51}};
 const draw=(p,time,o)=>{
  if(time<=0||time>=.9)return;
  const t=Math.floor(time*30)/30,C=fit(o.palette,5),front=layer==='front';
  const speedTime=kind==='fire'?.40:.25,life=kind==='fire'?(round>=6?.24:.36):.20;
  for(let x=-18;x<=18;x++){
   const lateral=x/19,depth=(front?1:-1)*Math.sqrt(1-lateral*lateral);
   const along=direction==='right'?lateral:direction==='left'?-lateral:direction==='front'?-depth:depth;
   const progress=(along+1)/2,age=t-progress*speedTime;
   if(age<0||age>life)continue;
   const attack=clamp(age/.035),fade=attack*clamp((life-age)/.10);
   const expansion=3+Math.min(9,age*(round>=6?36:20));
   const center=kind==='fire'?11-age*15:7+age*18;
   for(let y=Math.floor(center-expansion);y<=center+expansion;y++){
    const q=(y-center)/expansion;
    if(Math.abs(q)>1|| (front&&Math.abs(x)<10&&y<6))continue;
    if(kind==='fire'){
     const curl=Math.sin(x*.47+Math.sin(y*.4+t*9)*1.6)+Math.sin(y*.4+t*10)*.4;
     if(curl<-.15+Math.abs(q)*.4)continue;
     const hot=age<.10 && Math.abs(q)<.45;
     p.blend(x,y,C[hot?4:curl>.7?3:2],fade*(front?.76:.95));
    }else{
     const thick=round>=7?.65:1;
     if(Math.abs(q)>thick)continue;
     p.blend(x,y,C[q<-.35?4:q<.1?3:1],fade*(front?.6:.85));
    }
   }
  }
  // The last residue is born at the EXIT, after the crossing, never at entry.
  const exitX=direction==='right'?17:direction==='left'?-17:0;
  const exitFront=direction==='back'?true:direction==='front'?false:null;
  if(exitFront!==null&&exitFront!==front)return;
  const residue=t-speedTime-.015;
  if(residue<0||residue>.32)return;
  const R=rng(o.seed,front?1:2),k=clamp((.32-residue)/.16);
  for(let i=0;i<(kind==='fire'?2:4);i++){
   const side=direction==='right'?1:direction==='left'?-1:0;
   const x=exitX+R.range(-2,2)+residue*(side*20+R.range(-5,5));
   const y=8+(kind==='fire'?-residue*35:residue*(-12+i*3)+residue*residue*90);
   if(kind==='fire'){
    for(let j=0;j<7*k;j++)p.blend(x+Math.sin(j*.5-t*11+i)*1.2,y-j,C[j<3?3:2],k*.9);
   }else{
    p.blend(x,y,C[3],k);p.blend(x,y+1,C[1],k);
   }
  }
 };
 return {meta,draw};
}
