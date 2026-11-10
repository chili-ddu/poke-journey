// Flame drawing techniques adapted from pixelfx fire/_lib.js / Sprite Fusion fire,
// MIT License, Copyright (c) 2026 Hugo Duprez. Small muted game-scale studies.
import {fit,hex} from '../../../pixelfx/src/core/index.js';
import {noiseFor,flameBlade,flameTongue} from '../../../pixelfx/src/fx/fire/_lib.js';
const D=1.2,N0=noiseFor(D);
const PAL=['#452d29','#713d2d','#9b4c2d','#c36b35','#df8b43','#edaa5b','#f1c67d','#f5dca8','#f8e7bd'];
const LAYERS=[[1,1,6],[.76,.85,4],[.46,.66,2],[.20,.38,0]];

export function makeEmberStudy(variant='b',kind='flight',round=1){
 const meta={name:`Ember ${kind} ${variant}`,desc:'Small restrained flame shapes without physical hit stars or additive bloom.',
   tags:['fire','ember','review'],size:[32,32],origin:[16,16],duration:D,loop:true,fps:30,bg:'dark',
   options:{palette:PAL,seed:17}};
 const draw=(p,time,o)=>{
   const t=round>=3?Math.floor(time*20)/20:time,H=fit(o.palette,9).reverse(),seed=o.seed;
   const layers=round>=3?[[1,1,6],[.76,.85,4],[.46,.66,2],[.14,.26,0]]:LAYERS;
   const N=(rate,n=0,off=0)=>N0(t,rate,n+seed,off);
   if(kind==='flight'){
     if(variant==='a'){
       flameBlade(p,7,0,-1,0,16+N(5,1)*2,3.4,N(3,2)*1.2,N,11,H,LAYERS,.18,.45);
       p.circle(6,0,2.3,H[2]);p.circle(6,-.5,1.2,H[0]);
     }else if(variant==='b'){
       if(round>=2){
         const cool=[[1,1,7],[.76,.83,5],[.44,.6,3]];
         for(const side of [-1,1])flameBlade(p,-6,side*2,1,side*.12,14+N(4,19+side)*2,2.3,-side*2+N(3,29+side),N,39+side,H,cool,.15,.45);
         flameBlade(p,-10,0,1,0,21+N(5,20)*2,3.7,N(4,31)*1.2,N,40,H,layers,.15,.4);
       }else for(let i=0;i<3;i++){
         const dy=(i-1)*2.2,len=20+N(5,20+i)*2-i;
         flameBlade(p,-10,dy,1,-dy*.035,len,2.4-i*.15,N(4,31+i)*1.2,N,40+i*9,H,LAYERS,.15,.4);
       }
     }else{
       for(let i=0;i<3;i++){
         const dy=(i-1)*3.2;
         flameBlade(p,6,dy,-1,-dy*.09,13+N(4,60+i)*2,2.7,N(3,65+i)*1.8,N,70+i*11,H,LAYERS,.12,.4);
       }
     }
   }else{
     if(variant==='a'){
       flameTongue(p,0,13,25+N(4,10)*2,6,N(3,11)*2,N,20,H,LAYERS,.16,.45);
     }else if(variant==='b'){
       flameTongue(p,-3,13,24+N(4,20)*2,4.2,2+N(3,21)*1.8,N,30,H,layers,.15,.4);
       flameTongue(p,4,12,18+N(5,22)*2,3.8,-3+N(3,23),N,42,H,layers,.15,.45);
     }else{
       flameTongue(p,1,13,24+N(4,40)*2,5.3,-4+N(3,41)*2,N,50,H,LAYERS,.14,.5);
       flameTongue(p,-5,11,14+N(5,42)*2,3,3+N(3,43),N,62,H,LAYERS,.14,.4);
     }
   }
 };
 return {meta,draw};
}
