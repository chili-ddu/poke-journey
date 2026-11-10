// Supplied-art study adapter for pixelfx, not a new character reconstruction.
// All poses/pixels start in unmodified project PNGs extracted into data below.
import data from '../../docs/charmander_skill_restart/original-data.mjs';

const rgb=c=>parseInt(c.slice(1),16);
const packed=c=>{const n=rgb(c);return (0xff000000|(n&255)<<16|(n&0xff00)|(n>>>16))>>>0;};
const RAMPS={
 '#ff875f':'#f59661', '#d73f00':'#d96137', '#9f0000':'#9e4939',
 '#dfb700':'#dfbd78', '#a76f00':'#ad814c',
};
const ink=c=>c==='#000000';
const at=(frame,x,y)=>{
 if(x<0||y<0||x>=32||y>=40)return null;
 return frame.palette[frame.rows[y][x]]??null;
};

export function makeStudy(stage=1,variant='b',action='idle'){
 const clip=data.actions[action];
 const duration=action==='idle'?1.2:clip.ticks.reduce((a,b)=>a+b,0)/60;
 const meta={name:'Supplied sprite pixel study',desc:'Original supplied sprite keys with restrained pixel art finishing and protected anatomy.',
  tags:['review','supplied-art'],size:[96,96],origin:[48,76],duration,loop:true,fps:60,bg:'dark',options:{seed:1}};
 const shown=t=>{
   const total=clip.ticks.reduce((a,b)=>a+b,0);
   let q=((t%duration)+duration)%duration/duration*total;
   for(let i=0;i<clip.ticks.length;i++){if(q<clip.ticks[i])return i;q-=clip.ticks[i];}
   return 0;
 };
 const draw=(p,t,o)=>{
   const frame=clip.frames[shown(t)];
   const eyeMarks=[];
   for(let y=0;y<22;y++)for(let x=12;x<25;x++){
     if(['#ffffff','#4f5f97','#6787af','#bfcff7'].includes(at(frame,x,y)))eyeMarks.push([x,y]);
   }
   const eyeBottom=eyeMarks.length?Math.max(...eyeMarks.map(v=>v[1])):15;
   // Original drawing, nearest 2x, is the actual base for every frame.
   p.sprite(frame.rows,frame.palette,-32,-54,{scale:2});
   if(variant==='original')return;
   for(let y=0;y<40;y++)for(let x=12;x<32;x++){
     const c=at(frame,x,y);if(!c)continue;
     let color=RAMPS[c]??c;
     // Only exposed black silhouette gets colored ink. Eyes/mouth and
     // internal arm creases are never routed through an edge filter.
     const exposed=[at(frame,x-1,y),at(frame,x+1,y),at(frame,x,y-1),at(frame,x,y+1)].some(c=>c===null);
     if(variant!=='a' && ink(c) && exposed && (stage<2 || y>eyeBottom+1)){
       color=!at(frame,x,y-1)?'#6b3e32':'#3d2b2b';
     }
     if(variant==='c' && RAMPS[c] && x<16 && y>14){
       // Draft C explores a broad rear-facing shadow mass, not speckles.
       if(c==='#ff875f')color='#df8255';
     }
     p.rect(-32+x*2,-54+y*2,2,2,packed(color));
     if(stage>=2 && ink(c) && exposed && y>eyeBottom+1){
       // Thin only an inward corner that directly joins two equal body
       // neighbors. The other three ink pixels stay connected.
       const b=at(frame,x,y-1),d=at(frame,x-1,y),f=at(frame,x+1,y),h=at(frame,x,y+1);
       for(const [dx,dy,a,b0] of [[0,0,b,d],[1,0,b,f],[0,1,h,d],[1,1,h,f]]){
         if(a===b0 && RAMPS[a])p.px(-32+x*2+dx,-54+y*2+dy,packed(RAMPS[a]));
       }
     }
     if(stage>=3){
       // Only the cheek below the eye and the belly's own ramp. The arm's
       // shadow mass is excluded; colors always join matching neighbors.
       const cheek=x>=20 && y>eyeBottom+1 && y<eyeBottom+5 && c==='#d73f00';
       const belly=x>=16 && ['#dfb700','#a76f00'].includes(c);
       if(cheek||belly){
         const b=at(frame,x,y-1),d=at(frame,x-1,y),f=at(frame,x+1,y),h=at(frame,x,y+1);
         for(const [dx,dy,a,b0] of [[0,0,b,d],[1,0,b,f],[0,1,h,d],[1,1,h,f]]){
           const allowed=cheek?a==='#ff875f':['#dfb700','#a76f00'].includes(a);
           if(a===b0 && a!==c && allowed)p.px(-32+x*2+dx,-54+y*2+dy,packed(RAMPS[a]??a));
         }
       }
     }
   }
 };
 return {meta,draw,shown};
}
