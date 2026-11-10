// Curved contact trails, layered barriers and tumbling fragments reference pixelfx
// / Sprite Fusion slash, fire and falling-leaves, MIT (c) 2026 Hugo Duprez.
import {fit,clamp,rng} from '../../../pixelfx/src/core/index.js';
import {solid} from '../../../pixelfx/src/fx/fire/_lib.js';
const palettes={fang:['#784533','#b26e3b','#df9c4e','#f0c279','#f6dfac'],tail:['#354f60','#547d94','#7eaabb','#b9d6d8','#ecede1'],shell:['#3e5663','#6a8b9a','#9bb7bd','#c6d4cf','#f1e7d0'],paralyze:['#64523a','#947c45','#c2a85e','#e3d18d','#f5e8b9'],petal:['#704a54','#a36c7c','#c997a5','#e1bbc3','#f0dcd2'],sleep:['#405b52','#6a8576','#9bb5a0','#cbd9ba','#eee5c9']};
export function makeCategory(kind,layer='front',round=1){
 const D=kind==='petal'?2.7:1.0,front=layer==='front';
 const meta={name:`Category ${kind} ${layer}`,desc:'Separate physical, special and status material choreography.',tags:[kind,'body','one-shot'],size:[64,64],origin:[32,32],duration:D,loop:false,fps:30,bg:'dark',options:{palette:palettes[kind],seed:37}};
 const draw=(p,time,o)=>{
  if(time<=0||time>=D-.1)return;
  const t=Math.floor(time*24)/24,C=fit(o.palette,5),fade=clamp(time/.04)*clamp((D-.1-time)/.22);
  if(kind==='fang'){
   if(!front)return;
   const close=clamp(t/.10),gap=2+(1-close)*9;
   if(t<.28){
    for(let side of [-1,1]){
     const y=8+side*gap;
     p.line(-12,y,8,y+side*2,C[2]);
     for(let j=0;j<3;j++){const x=-10+j*7;p.line(x,y,x+2,y-side*4,C[4]);p.line(x+2,y-side*4,x+4,y,C[3]);}
    }
   }
   if(t>.07&&t<.50){
    const a=t-.07,k=clamp((.5-t)/.2);
    for(let side of [-1,1]){
     for(let j=0;j<10*k;j++){
      const x=side*9+Math.sin(j*.5-t*14)*2,y=10-j-a*8;
      p.line(x-1,y,x+1,y,C[j>5?2:3]);
     }
    }
   }
   const R=rng(o.seed,2);
   for(let i=0;i<(round>=2?4:7);i++){
    const a=R.range(0,6.28),sp=R.range(18,39),age=t-.1;
    if(age<0||age>.20+R.range(0,.08))continue;
    const x=-2+Math.cos(a)*sp*age,y=7+Math.sin(a)*sp*age+age*age*30;
    p.line(x,y,x-Math.cos(a)*(round>=3?1:2),y-Math.sin(a),C[3]);
   }
  }else if(kind==='tail'){
   if(!front)return;
   const life=.40,u=clamp(t/life),head=-2.7+u*4.3,span=round>=2?1.0:1.8;
   if(t<life)for(let q=0;q<span;q+=.045){
    const a=head-q,x=Math.cos(a)*21,y=7+Math.sin(a)*11;
    p.blend(x,y,C[q<.18?4:2],clamp((life-t)/.15));
    p.blend(x,y+1,C[1],clamp((life-t)/.15)*.7);
   }
   for(let i=0;i<5;i++){
    const age=t-.10-i*.012;if(age<0||age>.45)continue;
    const x=-10+i*5+age*(i-2)*16,y=6+age*(-15+i*4)+age*age*65;
    p.blend(x,y,C[3],clamp((.45-age)/.18));p.blend(x,y+1,C[1],clamp((.45-age)/.18));
   }
  }else if(kind==='shell'){
   const closing=clamp(t/.20),rx=19+(1-closing)*7;
   for(let i=0;i<100;i++){
    const a=i/100*Math.PI*2;if((Math.sin(a)>0)!==front)continue;
    const x=Math.cos(a)*rx,y=Math.sin(a)*23;
    const sheen=Math.cos(a+t*6)>.85;
    p.blend(x,y,C[sheen?4:2],fade*(round>=2?.8:1));
    if(round>=3&&sheen)p.blend(x-1,y,C[3],fade*.55);
   }
   if(front&&t>.10){
    const w=8*closing;
    for(let side of [-1,1]){
     p.line(side*13,-12,side*w,0,C[1]);p.line(side*w,0,side*13,13,C[2]);
    }
   }
  }else if(kind==='paralyze'){
   // Status application: intermittent paired clamps, not a damage burst.
   if(front&&round>=2)return;
   const f=Math.floor(t*12),R=rng(o.seed,f),on=(f%4)<2;
   if(!on)return;
   for(let side of [-1,1]){
    let x=side*18,y=-12;
    for(let j=0;j<6;j++){
     const nx=side*18+R.range(-2.5,2.5),ny=-12+j*6;
     p.blend(x,y,C[1],fade);p.line(x,y,nx,ny,C[3]);
     if(round>=3&&j===3)p.line(nx,ny,nx+side*3,ny-2,C[4]);
     x=nx;y=ny;
    }
   }
  }else if(kind==='petal'){
   const n=round>=2?10:16;
   for(let i=0;i<n;i++){
    const a=i/n*6.28+t*(round>=3?3.8:5),back=Math.sin(a)<0;
    if(front===back)continue;
    const x=Math.cos(a)*23,y=Math.sin(a)*9+4+Math.sin(i*2+t*3)*3;
    const rad=(2.3+Math.sin(i*3+t*4)*.5)*fade;
    solid(p,x,y,rad,C[1]);solid(p,x-.6,y-.5,rad*.7,C[3]);
    if(round<3||i%3===0)p.blend(x-1,y-1,C[4],fade);
   }
  }else{
   // Sleep powder settles first, then a small status mark appears above body.
   const R=rng(o.seed,front?1:2);
   for(let i=0;i<(round>=2?8:14);i++){
    const delay=i*.016,age=t-delay;if(age<0||age>.55)continue;
    const x=R.range(-18,18)+Math.sin(age*5+i),y=R.range(-15,2)+age*25;
    p.blend(x,y,C[2],clamp(age/.04)*clamp((.55-age)/.18));
    if(i%3===0)p.blend(x+1,y,C[3],clamp((.55-age)/.18));
   }
   if(front&&t>.16){
    const y=-17-(t-.16)*9,x=8+Math.sin(t*4)*2,k=clamp((.9-t)/.2);
    p.line(x,y,x+5,y,C[3],k);p.line(x+5,y,x,y+5,C[3],k);p.line(x,y+5,x+5,y+5,C[4],k);
   }
  }
 };
 return {meta,draw};
}
