// Tongue techniques from pixelfx / Sprite Fusion fire, MIT, Hugo Duprez 2026.
// One-shot body-centered flame layers; no physical hit star or character art.
import {fit,clamp} from '../../../pixelfx/src/core/index.js';
import {flameTongue,noiseFor,solid} from '../../../pixelfx/src/fx/fire/_lib.js';
const PAL=['#4a2c26','#773c2b','#a74e2c','#cc6d32','#e68f40','#efad59','#f3c676','#f7dca0','#f8e4b3'];
const D=.85;

export function makeHit(style='wrap',layer='front',round=1){
 const meta={name:`Ember ${style} ${layer}`,desc:'One-shot flames wrap the target or sweep across it, leaving the face readable.',
  tags:['fire','impact','body','one-shot'],size:[64,64],origin:[32,32],duration:D,loop:false,fps:30,bg:'dark',
  options:{palette:PAL,seed:17}};
 const draw=(p,time,o)=>{
  if(time<=0||time>=.76)return;
  const t=Math.floor(time*24)/24,H=fit(o.palette,9).reverse(),noise=noiseFor(0);
  const N=(rate,n=0,off=0)=>noise(t,rate,n+o.seed,off);
  // Rounded rolling lobes: no tapered tongue primitive in this revision.
  if(round>=6 && style==='wrap'){
   const front=layer==='front';
   const lobes=front?[[-15,17,6.8,.00],[-19,10,5.5,.045],[15,20,7,.025],[19,8,5.8,.08],[-6,23,5,.03],[5,24,5.5,.07]]:
    [[-13,13,9,0],[-19,1,7.5,.025],[-10,-6,7,.07],[9,-5,8,.04],[18,4,8,.095],[12,17,9,.055],[0,20,8,.015]];
   const shapes=[];
   for(let i=0;i<lobes.length;i++){
    const [bx,by,size,delay]=lobes[i],age=time-delay;
    if(age<=0||age>=.64)continue;
    const k=clamp(age/.055)*Math.pow(clamp((.64-age)/.42),.65);
    const rise=age*(round>=7?18:10);
    const x=bx+Math.sin(age*9+i*1.7)*(round>=7?2.5:1.2);
    const y=by-rise;
    const r=size*k;
    shapes.push([x,y,r,i]);
    // An off-centre second lobe makes each flame curl instead of a circle.
    shapes.push([x+(i%2?2.5:-3),y-r*.65,r*(round>=8?.58:.72),i]);
   }
   // Draw each colour across the whole mass before inset hot regions.
   for(const [scale,index,ox,oy] of [[1,front?5:6,0,0],[.78,front?3:4,-.7,-.6],[round>=8?.38:.52,front?1:3,-1.1,-1]]){
    for(const [x,y,r,i] of shapes){
     if(r<.8)continue;
     solid(p,x+ox,y+oy,r*scale,H[index]);
    }
   }
   return;
  }
  const hot=[[1,1,6],[.73,.87,4],[.40,.62,2],[round>=3?.12:.18,.30,0]];
  const cool=[[1,1,7],[.76,.84,5],[.40,.60,3]];
  const decay=Math.pow(clamp((.72-time)/.42),round>=3?.8:.6);
  const attack=clamp(time/.04),power=attack*decay;
  const rise=round>=3?clamp((time-.3)/.4)*5:0;
  const tongue=(x,y,h,w,bend,n,warm=true,k=1)=>{
   const q=power*k;if(q<.045)return;
   flameTongue(p,x,y-rise,h*q,w*Math.sqrt(q),bend,N,n,H,warm?hot:cool,.16,.5);
  };
  if(style==='wrap'){
   if(layer==='back'){
    for(let i=0;i<4;i++)tongue((i-1.5)*8,22,(round>=5?28:35)+N(5,10+i)*4+(i%2)*(round>=5?3:5),round>=5?8:5.6,(1.5-i)*3,20+i*7,false);
   }else{
    tongue(-15,21,(round>=4?25:34)+N(6,51)*3,round>=5?6:4.7,round>=4?-5:3,60);
    tongue(15,21,(round>=4?28:38)+N(5,52)*3,round>=5?6:4.5,round>=4?5:-3,70);
    tongue(-4,23,round>=4?9:round>=2?14:25,4,2,80,true,.85);
    tongue(6,23,round>=4?12:round>=2?17:24,4,-2,90,true,.8);
   }
  }else if(style==='sweep'){
   if(layer==='back'){
    const wave=clamp(time/.22),x=-17+wave*31;
    tongue(x,21,39,6,-5,100,false);
    tongue(x-8,22,29,4.5,-3,110,false,.85);
   }else{
    for(let i=0;i<5;i++){
     const age=time-(round>=2?i*.036:i*.015);if(age<0||age>.42)continue;
     const k=clamp(age/.035)*Math.pow(clamp((.42-age)/.24),.7);
     tongue(-16+i*8,22,round>=2?18+(i%2)*5:28,4.3,4-i*1.5,120+i*11,true,k);
    }
   }
  }else{
   for(let i=0;i<5;i++){
    if((layer==='front')!==(i%2===0))continue;
    tongue((i-2)*8,24,16+N(5,180+i)*3,5,(2-i)*2,190+i*9,true);
   }
  }
 };
 return {meta,draw};
}
