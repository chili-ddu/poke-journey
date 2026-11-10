// Existing supplied Pokémon art is processed, never reconstructed by pixelfx.
import data from '../../docs/charmeleon_charizard_skill_review/source-data.mjs';
const RAMPS={
 charmeleon:{'#ff875f':'#ed9270','#d73f00':'#cb563d','#9f0000':'#873e38',
 '#ffe79f':'#f0d8a3','#dfaf67':'#d5b17d','#bf7727':'#ab7b4f'},
 charizard:{'#ff875f':'#f4a05f','#d73f00':'#d96b3a','#9f0000':'#a45a38',
 '#dfb700':'#dabc7a','#a76f00':'#a68151'},
};
const color=c=>{const n=parseInt(c.slice(1),16);return (0xff000000|(n&255)<<16|(n&0xff00)|(n>>>16))>>>0;};
const at=(f,x,y)=>x<0||y<0||y>=f.rows.length||x>=f.rows[0].length?null:f.palette[f.rows[y][x]]??null;

export function makeStudy(name,stage=1,action='idle',variant='edited'){
 const d=data[name],clip=d.actions[action],ramp=RAMPS[name],W=d.width,H=d.height;
 const total=clip.ticks.reduce((a,b)=>a+b,0),duration=total/60;
 const size=[W*2+32,H*2+32],origin=[16,16];
 const meta={name:`Supplied ${name} sprite study`,desc:'Restrained pixel finishing of supplied source keys, preserving anatomical clusters and motion.',
   tags:['review','supplied-art'],size,origin,duration,loop:true,fps:60,bg:'dark',options:{seed:1}};
 const draw=(p,t,o)=>{
   let tick=(((t%duration)+duration)%duration)*60+1e-8,key=0;
   for(;key<clip.ticks.length-1;key++){if(tick<clip.ticks[key])break;tick-=clip.ticks[key];}
   const f=clip.frames[key];
   p.sprite(f.rows,f.palette,0,0,{scale:2});
   if(variant==='original')return;
   const protectedFlame=(x,y)=>x>=f.flame_box[0]&&x<f.flame_box[2]&&y>=f.flame_box[1]&&y<f.flame_box[3];
   for(let y=0;y<H;y++)for(let x=0;x<W;x++){
     const c=at(f,x,y);if(!c||protectedFlame(x,y))continue;
     const exposed=[at(f,x-1,y),at(f,x+1,y),at(f,x,y-1),at(f,x,y+1)].some(c=>c===null);
     let mapped=ramp[c]??c;
     // Eyes/teeth/claws stay exactly as drawn; upper head ink stays original.
     if(stage>=2&&c==='#000000'&&exposed&&y>f.eye_bottom+1){
       mapped=!at(f,x,y-1)?(name==='charmeleon'?'#653b39':'#6b4432'):
         name==='charmeleon'?'#392a2f':'#3e302a';
     }
     if(stage>=2&&name==='charizard'&&c==='#373f8f'&&y>f.eye_bottom+2)mapped='#435574';
     if(stage>=3&&name==='charizard'&&c==='#373f8f'&&x<W*.65)mapped='#435574';
     p.rect(x*2,y*2,2,2,color(mapped));
     if(stage>=3&&y>f.eye_bottom+1){
       const b=at(f,x,y-1),d0=at(f,x-1,y),f0=at(f,x+1,y),h=at(f,x,y+1);
       const inkCorner=c==='#000000'&&exposed;
       const cheek=x>W*.65&&y<f.eye_bottom+5&&c==='#d73f00';
       const belly=['#ffe79f','#dfaf67','#bf7727','#dfb700','#a76f00'].includes(c);
       for(const [dx,dy,a,b0] of [[0,0,b,d0],[1,0,b,f0],[0,1,h,d0],[1,1,h,f0]]){
         const ownBelly=['#ffe79f','#dfaf67','#bf7727','#dfb700','#a76f00'].includes(a);
         const allowed=inkCorner?!!ramp[a]:cheek?a==='#ff875f':belly&&ownBelly;
         if(a===b0&&a!==c&&allowed)p.px(x*2+dx,y*2+dy,color(ramp[a]??a));
       }
     }
   }
 };
 return {meta,draw};
}
