// Stream bands, leaf tumbling and thin arc techniques adapted from pixelfx / Sprite Fusion.
// MIT License, Copyright (c) 2026 Hugo Duprez. New generic FX, no character artwork.
import {fit,hex,TAU,clamp} from '../../../pixelfx/src/core/index.js';
import {drawLeaf} from '../../../pixelfx/src/fx/nature/_lib.js';

export const PALETTES={
 fire:['#6d3826','#a4522c','#cf7737','#e8a653','#f4d28b'],
 water:['#284d67','#397e9b','#66b9ce','#a8dadd','#d7ece1'],
 electric:['#726532','#ac9344','#d8bb65','#f0db98','#faf0ce'],
 leaf:['#233d26','#3f6636','#6b9351','#a7b973','#d6d49b'],
 wind:['#506465','#7e9998','#b7c8bf','#dce3d6'],
 psychic:['#574768','#7c638f','#a58db0','#c6b6ca','#dfd2d8']
};
export const CHOSEN={fire:'material',water:'ribbon',electric:'ribbon',leaf:'material',wind:'ribbon',psychic:'quiet'};

function softLine(p,points,color,alpha){
 const pixels=new Set();
 for(let i=1;i<points.length;i++){
  const [x0,y0]=points[i-1],[x1,y1]=points[i],n=Math.max(1,Math.ceil(Math.max(Math.abs(x1-x0),Math.abs(y1-y0))*2));
  for(let k=0;k<=n;k++){const x=Math.round(x0+(x1-x0)*k/n),y=Math.round(y0+(y1-y0)*k/n),key=`${x},${y}`;if(!pixels.has(key)){p.blend(x,y,color,alpha);pixels.add(key);}}
 }
}

export function makeDelivery(kind,style='material',round=1,stage='flight'){
 const duration=stage==='cast'?.4:.8;
 const meta={name:`${kind} ${style} ${stage}`,desc:'Caster/release/travel only. No impact art, target reaction or combat events.',
  tags:[kind,'directional','delivery',stage],size:[48,32],origin:[24,16],duration,loop:stage==='flight',fps:30,bg:'dark',
  options:{palette:PALETTES[kind],seed:17}};
 function draw(p,time,o){
  if(stage==='cast'&&(time<=0||time>=duration))return;
  const C=fit(o.palette,5),ph=((time%duration)+duration)%duration/duration,T=ph*TAU+(round>=2?(Number(o.seed)%23)*.31:0);
  const thin=style==='quiet',ribbon=style==='ribbon',refine=round>=2;
  if(stage==='cast'){
   const q=Math.sin(Math.PI*clamp(time/duration));
   if(kind==='leaf'){
    for(const sign of [-1,1])drawLeaf(p,sign*(7-4*q),sign*2,4*q,1.5,sign*.8,T,C.slice(1),.8*q);
   }else if(kind==='electric'){
    p.polyline([[-6*q,2*q],[-2*q,-3*q],[1*q,2*q],[5*q,-1*q]],C[3],q);
   }else if(kind==='psychic'||kind==='wind'){
    p.arc(0,0,3+4*q,1,-2.5+T*.2,-.1+T*.2,C[3],q*.65);
   }else{
    p.ellipse(0,0,2+3*q,1.2+q,C[2],q*.8);p.line(-2*q,-q,2*q,-q,C[4],q*.8);
   }
   return;
  }
  const length=thin?12:ribbon?30:22,half=length/2;
  if(kind==='fire'){
   // Rounded fuel lobes with heat rolling along the upper edge; no impact
   // star, triangular cone or detached physical sparks.
   const lobes=ribbon?6:thin?3:5;
   for(let i=0;i<lobes;i++){
    const u=i/(lobes-1),x=-half+2+u*(length-5),y=Math.sin(T*2+i*1.9)*1.1;
    const rx=(ribbon?3.8:3.1)+(u*.9),ry=(thin?1.2:refine?2.1:3.0)+Math.sin(T*3+i)*.4;
    p.ellipse(x,y,rx,ry,C[1]);p.ellipse(x+.4,y-.7,rx*.8,ry*.70,C[2]);
    if(i%2===0)p.line(x-1,y-1,x+1,y-1,C[3]);
    if(!thin&&i%2)p.arc(x,y-1.1,2.0,1,-2.8+T*.1,-.9+T*.1,C[3],.85);
   }
   p.line(half-6,-1,half-3,-1,C[4],.9);
   if(refine)for(const x of [-7,1,6]){
    const pts=[];for(let j=0;j<8;j++){const a=-2.8+j*.24;pts.push([x+Math.cos(a)*2.5,-2.4+Math.sin(a+T*.12)*2]);}
    softLine(p,pts,C[3],.82);
   }
   if(round>=3){
    // Heat rises inside the moving stream rather than turning into a star.
    for(let i=0;i<3;i++){const x=-8+i*6,pts=[];for(let j=0;j<9;j++){const u=j/8;pts.push([x+Math.sin(u*2.4+T*.2)*2,-.5-u*4]);}softLine(p,pts,C[3],.9);}
    p.line(0,-1,4,-1,C[4]);
   }
   if(round===1)p.glow(3,0,8,C[2],.15);
  }else if(kind==='water'){
   if(!thin){
    for(let x=-half;x<=half-2;x++){
     const u=(x+half)/length,y=.6*Math.sin(T*3-x*.42)+(refine?.3:.8)*u;
     const w=ribbon?(refine?1.4:2.0):2.5+.5*Math.sin(T*2+x*.3);
     p.line(x,y-w,x,y+w,C[1],.9);p.line(x,y-w+.6,x,y,C[2],.95);
     if(Math.sin(x*.7-T*3)>.3)p.px(x,y-w,C[4]);
    }
   }else p.line(-6,0,6,0,C[3],.9);
   const beadX=-half+((ph*3)%1)*(length-3);
   p.ellipse(beadX,-.5,1.5,.8,C[3]);
   for(let i=0;i<(refine?2:4);i++){const x=-half+3+i*6,y=3+Math.sin(T+i)*1.2;p.blend(x,y,C[2],.55);}
  }else if(kind==='electric'){
   // One carried discharge packet, preserving the game's single bolt.
   const pts=[];const n=thin?5:9;
   for(let i=0;i<n;i++){const x=-half+length*i/(n-1);pts.push([x,refine?Math.sin(T*3+i*2.31)*(1.7+(i%3)*.5):(i%2?1:-1)*3+(Math.sin(T*4+i*2)>.2?1:0)]);}
   p.polyline(pts,C[1],.85);p.polyline(pts.map(([x,y])=>[x,y-1]),C[3]);
   for(let i=1;i<pts.length-1;i+=3)p.px(pts[i][0],pts[i][1]-1,C[4]);
   if(!ribbon&&!thin){p.line(-2,0,1,4,C[2],.7);p.line(4,0,6,-4,C[2],.7);}
  }else if(kind==='leaf'){
   const spin=T*(ribbon?2:1),fl=T*2;
   const pal=[C[0],C[1],C[2],C[3]];
   drawLeaf(p,0,0,thin?8:refine?11:13,refine?2.1:3.0,Math.sin(spin)*.45,fl,pal,1);
   // A short trailing vein is attached to this leaf, never a second hit.
   if(ribbon)p.line(-12,1,-6,1,C[2],.55);
   if(Math.cos(fl)>.85)p.px(2,-1,C[4]);
  }else if(kind==='wind'){
   if(refine){
    for(let i=0;i<3;i++){
     const start=(i/3+ph)%1,points=[];
     for(let j=0;j<10;j++){const u=start+j*.017;if(u>1)break;points.push([(u-.5)*28,Math.sin(u*TAU*1.5-T*2)*(round>=3?4.6:3.8)]);}
     if(round>=3)softLine(p,points.map(([x,y])=>[x,y+1]),C[0],.72);
     softLine(p,points,C[i%2?3:2],round>=3?.92:i%2?.75:.55);
    }
    return;
   }
   // Unequal, open wind bands; the empty centre distinguishes air from water.
   const n=thin?2:ribbon?3:4;
   for(let i=0;i<n;i++){
    const cx=(i-(n-1)/2)*(ribbon?7:4),cy=Math.sin(T*2+i*1.7)*1.5;
    const r=(refine?3.6:5)+(i%2),a=-2.4+T+i*.7;
    p.arc(cx,cy,r,1,a,a+(refine?2.5:3.8),C[i%2?3:2],refine?.72:.9);
    p.line(cx-4,cy+3,cx-1,cy+3,C[1],.45);
   }
  }else if(kind==='psychic'){
   const n=thin?2:3;
   for(let i=0;i<n;i++){
    const x=(i-(n-1)/2)*(ribbon?7:5),rx=(thin?2.2:3.5)+Math.sin(T*2+i)*.5,ry=refine?5:7;
    const pts=[];for(let k=0;k<=14;k++){const a=(round>=3?Math.PI*.5:-1.4)+k/14*(round>=3?Math.PI:4.8)+Math.sin(T+i)*.15;pts.push([x+Math.cos(a)*rx,Math.sin(a)*ry]);}
    if(round>=3)softLine(p,pts.map(([x,y])=>[x+1,y]),C[0],.8);
    if(refine)softLine(p,pts,C[i?2:3],i?.58:.8);
    else for(let k=1;k<pts.length;k++)p.line(...pts[k-1],...pts[k],C[i?2:3],i?.58:.8);
   }
  }
 }
 return {meta,draw};
}
