// Surface-flow and stepped ramps use pixelfx core / Sprite Fusion fire, water,
// lightning and falling-leaves techniques, MIT Copyright (c) 2026 Hugo Duprez.
import {fit,clamp,rng} from '../../../pixelfx/src/core/index.js';
import {noiseFor} from '../../../pixelfx/src/fx/fire/_lib.js';
import {drawLeaf} from '../../../pixelfx/src/fx/nature/_lib.js';
const PALETTES={
 fire:['#69422f','#a35a32','#c87a39','#e5a753','#f0c679','#f5dca0'],
 water:['#294752','#3c6b7e','#5897ac','#89bfca','#bedddd','#e6ece0'],
 electric:['#665039','#967b3f','#b9a459','#dbcb81','#efdfa8','#faf0d0'],
 grass:['#314b32','#4d683d','#6b8a4b','#93aa60','#bed084','#dfdfad']};
export function makeBase(kind='fire',layer='front',round=1){
 const meta={name:`Base ${kind} ${layer}`,desc:'Body-following one-shot material response, no damage or character drawing.',
 tags:[kind,'impact','body','one-shot'],size:[64,64],origin:[32,32],duration:.9,loop:false,fps:30,bg:'dark',options:{palette:PALETTES[kind],seed:23}};
 const draw=(p,time,o)=>{
  if(time<=0||time>=.8)return;
  const t=Math.floor(time*24)/24,C=fit(o.palette,6),front=layer==='front';
  const envelope=clamp(time/.07)*clamp((.8-time)/.25),N=noiseFor(0);
  if(kind==='fire'){
   // One connected surface. Width remains attached; only its internal flow rises.
   for(let y=-22;y<25;y++)for(let x=-24;x<=24;x++){
    const root=24-Math.cos(x*.12)*3-(1-envelope)*27;
    const top=-11+Math.sin(x*.37+t*7)*3+N(t,6,o.seed,x*.21)*3;
    const width=18+Math.sin(y*.28+t*9)*2;
    const edge=width-Math.abs(x+Math.sin(y*.18-t*5)*1.6);
    if(y<top||y>root||edge<0)continue;
    const flow=Math.sin(y*.44+t*16+Math.sin(x*.29+t*5)*2)+N(t,9,o.seed+3,x*.2+y*.13)*.5;
    if(front){
     const band1=15+Math.sin(x*.20-t*7)*3;
     const band2=5+Math.sin(x*.24+t*8)*4;
     const band=Math.min(Math.abs(y-band1),Math.abs(y-band2));
     if(round===1?band>4:(band>2.2 && !(Math.abs(x)>14&&y>0)))continue;
     if(round>=3 && Math.abs(x)<9&&y<9)continue;
    }
    const heat=flow*.6+edge*.14-(y-top<3?.7:0);
    const index=heat>1.8?5:heat>.8?4:heat>-.1?3:2;
    p.blend(x,y,C[index],envelope*(front?(round>=3?.64:.8):.96));
   }
  }else if(kind==='water'){
   // A curved wet contact sheet breaks into gravity-driven runoff, not fire lobes.
   const down=t*24;
   for(let x=-19;x<=19;x++){
    const curve=round>=2?4+x*.3+Math.sin(x*.24-t*5)*1.5:7+Math.cos(x*.10)*8;
    const y=curve+Math.min(10,down);
    const thickness=(front?2:4)*envelope;
    if(round>=2 && x>14-time*8)continue;
    for(let j=0;j<thickness;j++)p.blend(x,y+j,C[j<1?4:2],envelope*(front?.65:.8));
   }
   for(let i=0;i<7;i++){
    if((i%2===0)!==front)continue;
    const x=-18+i*6+Math.sin(i*7)*1.5;
    const delay=(i%3)*.035,age=t-delay;if(age<0)continue;
    const length=(round>=2?5:9)*envelope;
    const y=-5+(i%3)*5+age*22+age*age*16;
    for(let j=0;j<length;j++)p.blend(x+Math.sin(j*.7+i)*.6,y+j,C[j<2?4:2],envelope*.85);
    if(round>=3&&time>.25&&time<.65){p.px(x+2,y+5,C[3]);p.px(x+2,y+6,C[2]);}
   }
  }else if(kind==='electric'){
   const f=Math.floor(t*15),R=rng(o.seed,f,front?1:2);
   const count=round>=2?2:3;
   if(time>.6&&(f%2))return;
   for(let i=0;i<count;i++){
    const side=i%2?1:-1,x0=side*(front?11:19),y0=R.range(-11,4);
    let px=x0,py=y0;
    for(let j=0;j<5;j++){
     const x=x0+R.range(-3,3),y=y0+j*5;
     p.line(px,py,x,y,C[2]);p.line(px,py,x-.4,y,C[4]);
     if(j===2&&round>=3)p.line(x,y,x+side*4,y-3,C[3]);
     px=x;py=y;
    }
   }
  }else{
   for(let i=0;i<8;i++){
    const age=t-i*.014;if(age<0)continue;
    const a=i*.91+age*(round>=2?5:8),back=Math.sin(a)<0;
    if(front===back)continue;
    const x=Math.cos(a)*(17+age*5),y=18-i*4-age*14+Math.sin(a)*3;
    const k=envelope*clamp((.72-age)/.2);
    drawLeaf(p,x,y,(round>=3?5:6)*k,2.1*k,a+.4,age*8+i,[C[0],C[1],C[3],C[4]],1);
   }
  }
 };
 return {meta,draw};
}
