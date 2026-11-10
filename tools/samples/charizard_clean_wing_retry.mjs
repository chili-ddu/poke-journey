// Supplied source body, explicitly authored wing mids. No mesh or optical flow.
import data from '../../docs/charmeleon_charizard_skill_review/source-data.mjs';
import {makeWingPoseStudy,wingRegions} from './charizard_wing_pose_study.mjs';
const inside=(x,y,pts)=>{
 let yes=false;
 for(let i=0,j=pts.length-1;i<pts.length;j=i++){
  const[a,b]=pts[i],[c,d]=pts[j];
  if((b>y)!==(d>y)&&x<(c-a)*(y-b)/(d-b)+a)yes=!yes;
 }return yes;
};
const ink=0xff2a303e,skin=0xff3a6bd9,litSkin=0xff5fa0f4;
const membrane=0xff745543,memShadow=0xff5f4434;

function authoredOpenMid(p){
 // Eight-grid coordinates. One connected membrane, not warped source pixels.
 const tip=[33,7],joint=[35,27],root=[40,45],low=[26,47],edge=[26,30];
 // The upper finger is exposed skin, not a large filled membrane panel.
 // Limit the membrane to the lower fan between joint and trailing edge.
 p.poly([joint,root,low,edge],ink);
 p.poly([[33,29],[37,43],[28,44],[28,32]],membrane);
 p.poly([[28,34],[30,35],[29,44],[28,44]],memShadow);
 // Leading wing finger and trailing skin rim each remain a continuous stroke.
 p.beam(tip[0],tip[1]+1,joint[0],joint[1],4,ink);
 p.beam(tip[0],tip[1]+1,joint[0],joint[1],2,skin);
 p.beam(joint[0],joint[1],root[0]-1,root[1]-1,2,skin);
 p.beam(tip[0]-1,tip[1]+3,edge[0]+1,edge[1],2,ink);
 p.line(tip[0]-1,tip[1]+3,edge[0]+1,edge[1],skin);
 p.line(edge[0]+1,edge[1],low[0]+1,low[1]-1,skin);
 p.line(low[0]+1,low[1]-1,root[0]-1,root[1]-1,skin);
 p.line(tip[0],tip[1]+3,joint[0],joint[1]-2,litSkin);
}

export function makeRetry(action='walk'){
 const base=makeWingPoseStudy(action),clip=data.charizard.actions[action],D=base.meta.duration;
 const draw=(p,t,o)=>{
   base.draw(p,t,o);
   let ticks=(((t%D)+D)%D)*60+1e-8,k=0;
   for(;k<clip.ticks.length-1;k++){if(ticks<clip.ticks[k])break;ticks-=clip.ticks[k];}
   // The old flame rectangle kept pure source red on the tail stem. Remap
   // actual remaining source-red pixels only; luminous flame colors stay.
   for(let y=0;y<96;y++)for(let x=0;x<80;x++){
     const c=p.get(x,y);
     if(c===0xff003fd7)p.px(x,y,skin);
     if(c===0xff00009f)p.px(x,y,0xff385aa4);
   }
   if(ticks<clip.ticks[k]/2)return;
   const snapshot=new Uint32Array(80*96),mask=new Uint8Array(80*96);
   for(let y=0;y<96;y++)for(let x=0;x<80;x++){
     const i=y*80+x;snapshot[i]=p.get(x,y);
     // The face, front arm and feet are never included in wing replacement.
     mask[i]=inside((x+.5)/2,(y+.5)/2,wingRegions[k])&&!(x>=42&&y<42)&&y<52?1:0;
     if(mask[i]){
       const sx=p.cellX(x,y)-p.ox,sy=p.cellY(x,y)-p.oy;
       if(sx>=0&&sy>=0&&sx<p.w&&sy<p.h)p.C[sy*p.w+sx]=0;
     }
   }
   if(k<2){
     // Folded→folded: retain the exact source wing pixels; shift one source
     // pixel vertically instead of shearing the wing/veins into fragments.
     const dy=k===0?2:-2;
     for(let y=0;y<96;y++)for(let x=0;x<80;x++){
       const i=y*80+x;if(mask[i]&&snapshot[i]>>>24)p.px(x,y+dy,snapshot[i]);
     }
   }else authoredOpenMid(p);
   // Original foreground anatomy stays byte-exact outside the wing region.
   for(let y=0;y<96;y++)for(let x=0;x<80;x++){
     const i=y*80+x;if(!mask[i]&&snapshot[i]>>>24)p.px(x,y,snapshot[i]);
   }
 };
 return {meta:{...base.meta,name:'Supplied Charizard clean wing middle poses'},draw};
}
