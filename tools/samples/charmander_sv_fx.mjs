// Original pixel artwork. The matched SV recordings are linked in the review folder.
const tau = Math.PI * 2;
const clamp = (v) => Math.max(0, Math.min(1, v));
const fade = (t, end) => clamp((end - t) * 5);
const heat = ['#793552','#b84b34','#f07832','#ffbc4a','#ffe997','#fff8d9'];
const sets = {
  scratch: [[68,56],[34,28],0.32,['#487ba4','#71b9df','#b5effb','#f7ffff']],
  slash: [[94,66],[47,33],0.38,['#a35f48','#e6a571','#ffde9e','#fffae0']],
  fire_fang: [[78,62],[39,31],0.40,heat],
  smoke_screen: [[116,76],[58,68],1.3,['#24252d','#35343a','#504d4d','#6a6662']],
  dragon_breath: [[158,60],[10,30],1,['#854278','#b5509e','#e87dc1','#ffd0e4','#fff4da']],
  flamethrower: [[174,76],[10,40],1,heat],
  fire_spin: [[104,96],[52,84],1,heat],
  inferno: [[126,110],[63,93],1,heat],
  flare_blitz: [[116,86],[73,43],0.46,heat],
};
function ribbon(p, points, width, color) {
  const upper=[], lower=[];
  for (let i=0;i<points.length;i++) {
    const [x,y]=points[i], [ax,ay]=points[Math.max(0,i-1)], [bx,by]=points[Math.min(i+1,points.length-1)];
    const len=Math.hypot(bx-ax,by-ay)||1, w=width(i/(points.length-1));
    upper.push([x-(by-ay)*w/len,y+(bx-ax)*w/len]);
    lower.push([x+(by-ay)*w/len,y-(bx-ax)*w/len]);
  }
  // Fill short strips. A whole curled outline tests every edge against every pixel in its bounds.
  for(let i=1;i<upper.length;i++) {
    p.poly([upper[i-1],upper[i],lower[i],lower[i-1]],color);
  }
}
function path(count, point) { return Array.from({length:count},(_,i)=>point(i/(count-1))); }
const taper = u => Math.sin(Math.PI*u)**0.65;
function cuts(p,t,c,scratch,outward=false,descending=false,tipLift=0) {
  const end=scratch?.32:.38, head=clamp((t+.025)/.14), tail=clamp((t-.105)/(end-.105));
  if (head<=tail) return;
  const strokes=scratch?3:1;
  for(let i=0;i<strokes;i++) {
    const points=path(19,u=>{
      const progress=tail+(head-tail)*u;
      const s=outward ? progress : 1-progress;
      const offset=scratch ? i-1 : -1;
      const x=(s-.5)*(scratch?47:78)+offset*4;
      if(descending) {
        // The wrist extends first, then rolls the tips down through the stroke.
        const drop=scratch ? 27 : 33;
        // Offset across the descending stroke so the three claws stay distinct at 1x.
        const spacing=scratch ? -offset*3 : offset*3;
        // Lift the finish gradually, keeping the shoulder anchor and initial tangent.
        const lift=tipLift*s*s*(2-s);
        return [x,(s-.5)*drop-2.5*Math.sin(Math.PI*s)+spacing-lift];
      }
      return [x,(.5-s)*(scratch?37:43)+offset*3-Math.sin(s*Math.PI)*(scratch?2:1)];
    });
    for(let k=0;k<3;k++) ribbon(p,points,u=>taper(u)*(3.8-k*1.15)*(scratch?.69:1)*fade(t,end),c[k+1]);
  }
}
function dragon(p,t,c) {
  for(let strand=0;strand<3;strand++) {
    const pts=path(46,u=>[137*u,Math.sin(tau*(1.45*u-2*t)+strand*2.1)*(1+u*7)]);
    ribbon(p,pts,u=>(1+2*taper(u))*(strand===0?1.5:.68),c[strand+1]);
  }
  ribbon(p,path(36,u=>[137*u,Math.sin(tau*(u-2*t))*1.3]),u=>1+1.4*taper(u),c[4]);
  for(let i=0;i<7;i++){
    const x=((t*2+i/7)%1)*140,y=Math.sin(i*8.3+tau*t)*9;
    p.line(x-4,y+1,x,y,c[2],.75);
  }
}
function jet(p,t,c) {
  const center=u=>Math.sin(tau*(1.6*u-2*t))*(2+4*u)-2*u;
  for(let k=0;k<3;k++){
    const pts=path(60,u=>[149*u,center(u)-k*.6]);
    ribbon(p,pts,u=>(2+8*u+2*Math.sin(tau*(2.2*u-2*t)))*(1-.29*k)*Math.min(1,(1-u)*10+.06),c[k+2]);
  }
  for(let i=0;i<11;i++){
    const u=(t*2+i/11)%1, x=u*145, y=center(u), s=(4+u*12)*Math.sin(Math.PI*u);
    const bend=.42+.46*Math.sin(i*5.3+tau*t);
    const arc=path(12,a=>[x-s*.67+Math.sin(a*1.65)*s*(1+bend)-a*a*s*.54,y-1-Math.sin(a*1.95)*s*(1+.3*Math.cos(i*2.3))]);
    if(i%3===0) p.disc(x,y+1,s*.8,c[2],d=>(1-d)*.32);
    ribbon(p,arc,a=>.2+taper(a)*(.7+s*.13),c[2+i%3]);
  }
}
function ring(p,x,y,rx,ry,phase,sweep,width,color) {
  const pts=path(42,u=>[x+rx*Math.cos(phase+sweep*u),y+ry*Math.sin(phase+sweep*u)]);
  ribbon(p,pts,u=>width*taper(u),color);
}
function whirl(p,t,c) {
  for(let i=0;i<5;i++){
    const u=(i/5+t)%1, a=tau*(t*2+u*.7);
    const width=Math.sin(Math.PI*u)*2.8+.4,rx=19+15*u, y=-3-u*61;
    const band=path(34,v=>{
      const angle=a+v*4.8, radius=rx+1.6*Math.sin(3*angle+u*9);
      return [Math.cos(angle)*radius+Math.sin(u*6)*1.7,y+Math.sin(angle)*(6+u*3)-7*v+1.3*Math.sin(angle*4)];
    });
    ribbon(p,band,v=>width*taper(v)*(1+.35*Math.sin(v*13)),c[2]);
    ribbon(p,band.slice(6,26),v=>width*.57*taper(v),c[4]);
    for(let j=0;j<3;j++) {
      const k=(7+j*9+i)%30, [x,b]=band[k], side=Math.cos(a+k*.14);
      const tongue=path(8,v=>[x+side*(v*6+Math.sin(v*4)*2),b-v*(4+4*Math.sin(i+j)**2)]);
      ribbon(p,tongue,v=>taper(v)*1.4,c[3]);
    }
  }
}
function inferno(p,t,c) {
  const rise=clamp((t-.08)/.32), decay=fade(t,1);
  for(let i=0;i<10;i++) {
    const x=(i-4.5)*7, mid=1-Math.abs(x)/40, w=(5+mid*5)*decay;
    const h=(21+mid*44+12*Math.sin(i*4+t*13))*rise*decay;
    const pts=path(22,u=>[x+Math.sin(6*u+i*3-t*10)*u*(7+4*Math.cos(i))+Math.sin(t*8+i)*u*u*9,-4-u*h]);
    p.disc(x,-h*.28,Math.max(0,w*1.65),c[1],d=>(1-d)*.64*decay);
    for(let k=0;k<3;k++) ribbon(p,pts,u=>w*(1-u**1.5)*(1-k*.29),c[1+k]);
    if(t>.2 && t<.88){
      const v=((t*1.7+i*.31)%1), sx=x+Math.sin(i*4+v*3)*6, sy=-6-v*(h+14);
      p.disc(sx,sy,1.7+i%2,c[3],d=>(1-d)*decay);
    }
  }
  const r=45*clamp(t*5)*decay;
  ring(p,0,-3,r,r*.22,t*11,5.8,3*decay,c[3]);
  ring(p,0,-3,r*.8,r*.16,-t*13,5,1.7*decay,c[4]);
}
function charge(p,t,c) {
  const amount=Math.min(clamp((t+.025)/.09),clamp((.46-t)/.11)), r=21*amount;
  p.disc(2,0,r*1.19,c[2],d=>(1-d*d)*.49);
  p.disc(5,-1,r*.72,c[4],d=>(1-d)*.83);
  for(let i=0;i<6;i++){
    const a=t*14+tau*i/6, x=r*Math.cos(a), y=.78*r*Math.sin(a);
    const tongue=path(12,u=>[x-u*(11+i%3*5)*amount+2*Math.sin(u*3),y+u*Math.sin(a)*6-u*u*5]);
    ribbon(p,tongue,u=>2.7*amount*taper(u),c[2+i%3]);
  }
  for(let i=0;i<3;i++) {
    ring(p,0,0,r*(1+i*.06),r*(.68+i*.10),t*14+i*tau/3,3.7,3.1*amount,c[2+i]);
    const line=path(15,u=>[-r*.3-u*(23+i*6)*amount, (i-1)*r*.42+Math.sin(u*4+t*18+i)*u*4]);
    ribbon(p,line,u=>taper(u)*2.8*amount,c[2+i%2]);
  }
}
function smoke(p,t,c) {
  const spread=clamp(t/.28), f=clamp((1.3-t)/.55);
  for(let i=0;i<16;i++){
    const a=i*2.4,r=(i%5)/4, x=Math.cos(a)*r*34*spread, y=-8-Math.sin(a)**2*10-r*12*spread-t*(4+i%4);
    const rad=(8+i%5)*(.35+.75*spread)*(.6+.4*f);
    p.disc(x,y,rad,c[1+(i%3)],d=>f*(1-d*d)*.84);
  }
}
function bite(p,t,c) {
  const u=t/.4;
  for(let i=0;i<10;i++){
    const a=tau*i/10+.18*Math.sin(i*4), rad=9+u*(17+i%4);
    const x=Math.cos(a)*rad,y=Math.sin(a)*rad*.66-u*u*8;
    const r=(4+i%3)*Math.sin(Math.PI*u);
    p.disc(x,y,r,c[2],d=>(1-d)*.9);
    p.ellipse(x,y,r*.52,r*.75,c[3]);
  }
}
const drawMoves={scratch:(p,t,c)=>cuts(p,t,c,true),slash:(p,t,c)=>cuts(p,t,c,false),
  dragon_breath:dragon,flamethrower:jet,fire_spin:whirl,inferno,flare_blitz:charge,smoke_screen:smoke,fire_fang:bite};
export function effect(id,fit,outward=false,descending=false,tipLift=0) {
  const [size,origin,duration,palette]=sets[id],loop=['dragon_breath','flamethrower','fire_spin'].includes(id);
  const drawMove=outward && (id==='scratch' || id==='slash')
    ? (p,t,c)=>cuts(p,t,c,id==='scratch',true,descending,tipLift)
    : drawMoves[id];
  return {meta:{name:id,desc:'Front-facing Charmander move study',tags:['directional'],size,origin,duration,loop,fps:30,bg:'ground',options:{palette}},
    draw(p,t,o){if(loop||t<duration)drawMove(p,t,fit(o.palette,palette.length));}};
}
