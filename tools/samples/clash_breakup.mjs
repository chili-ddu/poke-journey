// Contact silhouettes sampled along a curve. The head advances first, then the tail
// catches up, leaving clear space where the two attacks met.
const clamp = x => Math.max(0, Math.min(1, x));
const palette = ["#914238","#ed773b","#ffe5a2","#266984","#66c5d8","#e1ffef"];
function meta(name) {
  return {name,desc:name,tags:["clash","impact"],size:[80,68],origin:[40,37],
    duration:.52,loop:false,fps:30,bg:"ground",options:{palette}};
}
function ribbon(p,time,life,path,width,colors) {
  const u=time/life;
  if(u<0 || u>=1) return;
  const head=1-(1-clamp(.10+u*1.8))**2, tail=clamp((u-.18)/.82);
  const alpha=clamp((1-u)*5);
  const ridge=[];
  for(let i=0;i<=24;i++) {
    const along=i/24, s=tail+(head-tail)*along, [x,y]=path(s);
    const r=width*(.22+.78*Math.sin(Math.PI*along)**.8)*(1-.55*u);
    p.disc(x,y,r+.35,colors[0],alpha);
    ridge.push({x,y,r,along});
  }
  for(const {x,y,r} of ridge) p.disc(x,y-.55,r*.78,colors[1],alpha);
  for(const {x,y,r,along} of ridge) {
    if(along>.52 && along<.88) p.disc(x,y-r*.55,.65,colors[2],alpha);
  }
}
export function elemental(fit) {
  return {meta:meta("Cinders and a broken water crest"),draw(p,t,o) {
    const c=fit(o.palette,6), flame=c.slice(0,3), water=c.slice(3);
    ribbon(p,t,.25,s=>[-24*s, -16*Math.sin(s*2.04)+3*s*s],3.4,water);
    ribbon(p,t-.021,.24,s=>[-14*s+3*Math.sin(s*3.4),-22*Math.sin(1.55*s)],2.4,water);
    ribbon(p,t,.25,s=>[20*s+3*Math.sin(s*6),-19*s+3*Math.sin(s*6.1)],2.8,flame);
    ribbon(p,t-.026,.19,s=>[21*s,5*Math.sin(s*3.8)-1],2.1,flame);
    const drops=[[-22,-14,-9,-8,.11,.35,2.25],[-12,-21,-6,-10,.145,.36,1.9],[-15,-8,-8,-1,.16,.24,1.5],[4,2,7,-11,.07,.28,1.7]];
    for(const [x,y,vx,vy,delay,life,r] of drops) {
      const u=(t-delay)/life;
      if(u<0 || u>=1) continue;
      const px=x+vx*u, py=y+vy*u+23*u*u, fade=clamp((1-u)*4);
      p.ellipse(px,py,r*(1-.33*u),r*(1+.28*u),water[0],fade);
      p.disc(px,py-.65,r*.8,water[1],fade);
      p.disc(px-.6,py-1.1,.78,water[2],fade);
    }
    for(const [x,y,dx,dy,start,life] of [[16,-16,10,-12,.114,.33],[19,0,13,-7,.104,.25],[11,-13,-1,-14,.166,.31],[-3,2,-6,8,.06,.22]]) {
      const u=(t-start)/life;
      if(u<0 || u>=1) continue;
      const px=x+dx*u+1.8*Math.sin(u*6), py=y+dy*u, fade=clamp((1-u)*4);
      p.line(px-2,py+2,px+1,py-1,flame[1],fade);
      p.disc(px+.4,py-.5,.85,flame[2],fade);
    }
  }};
}
export function physical(fit) {
  const detail=meta("Glancing claw sparks");
  detail.options.palette=["#967055","#e9bd77","#fff0c1",...palette.slice(3)];
  return {meta:detail,draw(p,t,o) {
    const c=fit(o.palette,6), bone=[c[0],c[1],c[2]];
    // Most momentum follows one tangential scrape. Two shorter grains peel away late.
    for(const [dx,dy,delay,life,r] of [[18,-20,0,.21,1.65],[6,-24,.02,.23,1.1],[-8,13,0,.18,1.35],[-15,5,.042,.15,.85],[19,-9,.09,.19,.95]]) {
      ribbon(p,t-delay,life,s=>[dx*s,dy*s+4*s*s],r,bone);
    }
  }};
}
