// Stepped arcs, facets and material flow reference pixelfx / Sprite Fusion lightning,
// ice, acid and energy techniques, MIT Copyright (c) 2026 Hugo Duprez.
import {fit,clamp,rng} from '../../../pixelfx/src/core/index.js';
const PAL={electric:['#665237','#9b8145','#c5ad63','#e5d49a','#f8ecd0'],ice:['#3e647b','#638ca5','#8db5c9','#bdd8dd','#e6eade'],poison:['#555b2d','#7b813b','#a0a54c','#bdc272','#d9dba2'],psychic:['#57506d','#7e7398','#a293b8','#c5b6d0','#e5d8e0']};
export function makeMaterial(kind,direction,layer,round=1){
 const meta={name:`Material ${kind} ${direction} ${layer}`,desc:'Contact-origin material response, no rank icons, character editing or added damage.',tags:[kind,'body','directional','one-shot'],size:[64,64],origin:[32,32],duration:1,loop:false,fps:30,bg:'dark',options:{palette:round>=4&&kind==='poison'?['#44542c','#71883d','#a4b350','#ccd380','#dfe3b0']:round>=4&&kind==='psychic'?['#49375e','#6d518b','#9671b6','#bfa1d1','#dfcde9']:PAL[kind],seed:61}};
 const draw=(p,time,o)=>{
  if(time<=0||time>=.9)return;
  const t=Math.floor(time*24)/24,C=fit(o.palette,5),front=layer==='front',sign=direction==='right'?1:-1;
  const fade=clamp(time/.035)*clamp((.9-time)/.2);
  const X=x=>x*sign;
  if(kind==='electric'){
   if(t>.50)return;
   const f=Math.floor(t*15),R=rng(o.seed,f,front?1:2),head=-18+Math.min(1,t/.22)*36;
   const n=round>=2?3:5;
   for(let b=0;b<n;b++){
    const tail=Math.max(-18,head-(round>=3?12:18)-b*3);
    let px=tail,py=8+(b-1)*(front?5:8);
    for(let j=1;j<=5;j++){
     const x=tail+(head-tail)*j/5,y=8+(b-1)*(front?5:8)+R.range(-3,3);
     const k=clamp((.50-t)/.18);
     p.line(X(px),py,X(x),y,C[j===5?4:2],k);
     if(j===3&&b!==1)p.line(X(x),y,X(x+R.range(-3,3)),y+(b===0?-5:5),C[3],k);
     px=x;py=y;
    }
   }
  }else if(kind==='ice'){
   for(let i=0;i<8;i++){
    if((i%3!==0)!==front)continue;
    const R=rng(o.seed,i),delay=i*.033,age=t-delay;if(age<0||age>.58)continue;
    const k=clamp(age/.06)*clamp((.58-age)/.20);
    const x=-17+i*4.8+R.range(-1.5,1.5),base=front?13+R.range(-1,5):4+R.range(-9,8);
    const drop=age>.30?(age-.30)**2*100:0;
    const h=(round>=2?6:10)*k,w=round>=3?1.6:2.1;
    p.poly([[X(x-w),base+drop],[X(x-w*.6),base-h*.7+drop],[X(x+.6),base-h+drop],[X(x+w),base-h*.45+drop],[X(x+w*.5),base+drop]],C[1],k);
    p.line(X(x),base+drop,X(x+.6),base-h+drop,C[4],k);
    p.line(X(x),base-h*.45+drop,X(x+w),base-h*.45+drop,C[3],k);
   }
   // Thin frost trace follows the contact, never a full opaque fog mask.
   const head=-18+clamp(t/.30)*36;
   if(t<.6)for(let x=-18;x<head;x++){
    const a=clamp((.6-t)/.2)*.5;
    if(round>=2&&(x%4===0))continue;
    p.blend(X(x),18+Math.sin(x*.5)*1.2,C[2],a);
   }
  }else if(kind==='poison'){
   // Connected small wet patches cling and sag; no explosive particle star.
   for(let i=0;i<5;i++){
    if((i%3!==0)!==front)continue;
    const age=t-i*.055;if(age<0||age>.65)continue;
    const k=clamp(age/.07)*clamp((.65-age)/.22),x=-17+i*8;
    const y=10+(i%2)*3+age*8;
    const rx=(round>=4?7.5:round>=2?6:8)*k,ry=(round>=4?3.7:round>=3?2.2:3.5)*k;
    for(let xx=Math.floor(x-rx);xx<=x+rx;xx++)for(let yy=Math.floor(y-ry);yy<=y+ry;yy++){
     const u=(xx-x)/Math.max(rx,.1),v=(yy-y)/Math.max(ry,.1);
     if(u*u+v*v>1)continue;
     const index=round>=4?(u*u+v*v>.64?0:v<-.3?3:2):(v<-.2?3:1);
     p.blend(X(xx),yy,C[index],k*(front?(round>=4?.84:.62):.86));
    }
    if(age>.14){
     const length=clamp((age-.14)*15,0,5)*k;
     for(let j=0;j<length;j++)p.blend(X(x+1),y+1+j,C[2],k*.75);
    }
   }
  }else{
   // Smooth bowed contours contrast with the broken branches of electricity.
   for(let i=0;i<(round>=4?(front?3:2):round>=2?2:3);i++){
    const age=t-i*.07-(front?0:.035);if(age<0||age>.43)continue;
    const u=clamp(age/.35),center=-19+u*38,k=clamp(age/.04)*clamp((.43-age)/.15);
    let last=null;
    for(let y=-8;y<=20;y++){
     const bow=Math.sin((y+8)/28*Math.PI)*(round>=3?4:7)*(1-u*.5);
     const x=X(center+bow);
     if(round>=4){p.blend(x,y,C[1],k*(front?.95:.75));p.blend(x+sign,y,C[3],k*(front?.88:.7));}
     else if(round>=3)p.blend(x,y,C[y%5===0?4:2],k*(front?.75:.65));
     else if(last)p.line(last[0],last[1],x,y,C[y%5===0?4:2],k*(front?.75:.65));
     last=[x,y];
    }
   }
  }
 };
 return {meta,draw};
}
