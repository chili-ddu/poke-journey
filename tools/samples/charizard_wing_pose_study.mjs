// Supplied-art wing anatomy regions, separate from flame protection.
import data from '../../docs/charmeleon_charizard_skill_review/source-data.mjs';
import {makeWingStudy} from './charizard_wing_fix.mjs';
export const wingRegions=[
 [[15,3],[17,6],[18,12],[19,16],[16,24],[14,25],[12,23],[12,10],[14,6]],
 [[15,5],[17,9],[19,15],[19,21],[18,27],[15,26],[14,21],[13,14],[12,10]],
 [[15,3],[17,6],[18,12],[19,16],[16,24],[14,25],[12,23],[12,10],[14,6]],
 [[18,4],[20,8],[21,13],[22,18],[19,23],[12,24],[11,21],[11,15],[14,11],[16,8]],
];
const ramp={'#ff875f':0xff5fa0f4,'#d73f00':0xff3a6bd9,'#9f0000':0xff385aa4,'#373f8f':0xff745543};
const inside=(x,y,pts)=>{
 let yes=false;
 for(let i=0,j=pts.length-1;i<pts.length;j=i++){
  const [a,b]=pts[i],[c,d]=pts[j];
  if((b>y)!==(d>y)&&x<(c-a)*(y-b)/(d-b)+a)yes=!yes;
 }
 return yes;
};
export function makeWingPoseStudy(action='walk'){
 const base=makeWingStudy(action),clip=data.charizard.actions[action],D=base.meta.duration;
 return {meta:{...base.meta,name:'Supplied Charizard explicit wing regions'},draw:(p,t,o)=>{
   base.draw(p,t,o);
   let tick=(((t%D)+D)%D)*60+1e-8,key=0;
   for(;key<clip.ticks.length-1;key++){if(tick<clip.ticks[key])break;tick-=clip.ticks[key];}
   const f=clip.frames[key];
   for(let y=0;y<f.rows.length;y++)for(let x=0;x<f.rows[0].length;x++){
     const c=f.palette[f.rows[y][x]],mapped=ramp[c];
     if(mapped!==undefined&&inside(x+.5,y+.5,wingRegions[key]))p.rect(x*2,y*2,2,2,mapped);
   }
 }};
}
