// Cold curved tongues and contact ramps reference pixelfx / Sprite Fusion fire
// and impacts, MIT Copyright (c) 2026 Hugo Duprez. No character pixels drawn.
import {fit,clamp,rng} from '../../../pixelfx/src/core/index.js';
import {solid} from '../../../pixelfx/src/fx/fire/_lib.js';
const palettes={wisp:['#39445a','#596d85','#83a5b6','#b4d4d7','#e1e7da'],punch:['#655039','#987741','#c5a15c','#e4cb87','#f7e6b7']};
export function makeFill(kind,layer='front',round=1){
 const meta={name:`Category fill ${kind} ${layer}`,desc:kind==='wisp'?'Cold wisps arrive and attach: visual study, no burn gameplay.':'A brief local physical impact with asymmetric sparks and short electric branches.',tags:[kind,'body','one-shot'],size:[64,64],origin:[32,32],duration:1,loop:false,fps:30,bg:'dark',options:{palette:palettes[kind],seed:43}};
 const draw=(p,time,o)=>{
  if(time<=0||time>=.88)return;
  const t=Math.floor(time*24)/24,C=fit(o.palette,5),fade=clamp(time/.05)*clamp((.88-time)/.22);
  if(kind==='wisp'){
   const points=layer==='front'?[[-10,14],[12,10]]:[[0,-3]];
   for(let n=0;n<points.length;n++){
    const [bx,by]=points[n],x=bx+Math.sin(t*6+n*2)*2,y=by+Math.sin(t*5+n)*2;
    const h=(round>=2?12:16)*fade,w=round>=3?3:3.6;
    for(let row=0;row<h;row++){
     const u=row/Math.max(h,1),half=Math.sin(Math.PI*u)**.7*w;
     const curl=Math.sin(u*4-t*9+n)*u*(round>=2?4:2);
     for(let q=-Math.ceil(half);q<=Math.ceil(half);q++){
      if(Math.abs(q)>half)continue;
      const r=Math.abs(q)/Math.max(half,.3);
      const c=r>.72?C[2]:r>.35?C[1]:C[u<.55?4:3];
      p.blend(x+curl+q,y-row,c,fade*.9);
     }
    }
   }
  }else{
   if(layer!=='front')return;
   const ox=-7,oy=7;
   if(t<(round>=2?.085:.14)){
    solid(p,ox,oy,(round>=3?4:5)*(1-t/.15),C[3]);
    solid(p,ox-1,oy-.5,(round>=3?2.2:3)*(1-t/.15),C[4]);
   }
   const R=rng(o.seed,4);
   for(let i=0;i<(round>=2?7:11);i++){
    const born=R.range(0,.035),age=t-born,life=R.range(.14,.32);
    const a=R.range(0,6.28),speed=R.range(28,65),x=ox+Math.cos(a)*speed*age,y=oy+Math.sin(a)*speed*age+age*age*24;
    if(age<0||age>life)continue;
    const len=(round>=3?2:3)*(1-age/life);
    p.line(x,y,x-Math.cos(a)*len,y-Math.sin(a)*len,C[age<.10?4:2]);
   }
   if(t<.26){
    const R2=rng(o.seed,Math.floor(t*18));
    for(let n=0;n<3;n++){
     let x=ox,y=oy;
     const a=n*2.1+.4;
     for(let j=1;j<=3;j++){
      const xx=ox+Math.cos(a)*j*3+R2.range(-1.4,1.4),yy=oy+Math.sin(a)*j*3+R2.range(-1.5,1.5);
      p.line(x,y,xx,yy,C[j===3?2:3]);x=xx;y=yy;
     }
    }
   }
  }
 };
 return {meta,draw};
}
