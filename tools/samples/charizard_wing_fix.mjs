// Existing wing pixels, not generated motion. Fix a protection-mask overlap.
import data from '../../docs/charmeleon_charizard_skill_review/source-data.mjs';
import {makeStudy} from './evolution_skill_study.mjs';
export function makeWingStudy(action='idle'){
 const base=makeStudy('charizard',3,action,'edited');
 const clip=data.charizard.actions[action],duration=base.meta.duration;
 const draw=(p,t,o)=>{
   base.draw(p,t,o);
   let tick=(((t%duration)+duration)%duration)*60+1e-8,key=0;
   for(;key<clip.ticks.length-1;key++){if(tick<clip.ticks[key])break;tick-=clip.ticks[key];}
   const f=clip.frames[key];
   for(let y=0;y<f.rows.length;y++)for(let x=0;x<f.rows[0].length;x++){
     if(f.palette[f.rows[y][x]]==='#373f8f'){
       // This unique source blue is the membrane, never the flame.
       // Process it independently of the flame's rectangular protection.
       p.rect(x*2,y*2,2,2,0xff745543);
     }
   }
 };
 return {meta:{...base.meta,name:'Supplied Charizard wing protection fix'},draw};
}
