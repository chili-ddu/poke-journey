// Contact-centred studies for the facing-right battle review. The water shot
// continues left, while the claws scrape down across the point of contact.
const mist = ["#357388","#67b4c3","#cfebe3"];
const ember = ["#9f563a","#dc8e50","#f2cb85"];
const claw = ["#877866","#c7ad7f","#f0d8af"];

function effect(name, duration, physical, draw) {
  return {meta:{name,desc:name,tags:["impact","clash"],size:[48,40],origin:[24,23],
    duration,loop:false,fps:30,bg:"ground",options:{palette:physical?[...claw,...claw]:[...mist,...ember]}},draw};
}
function chip(p,x,y,r,ink,alpha,warm) {
  if(warm) {
    p.line(x-r,y+1,x+r,y-1,ink[1],alpha);
    p.dot(x+r,y-1,ink[2],alpha*.85);
  } else {
    p.ellipse(x,y,r*1.24,r*.88,ink[0],alpha*.9);
    p.ellipse(x,y-.45,r,r*.7,ink[1],alpha);
    if(r>1.15) p.dot(x-.6,y-.7,ink[2],alpha);
  }
}
function skim(fit,physical) {
  return effect("Contact shear",.32,physical,(p,t,o)=>{
    const c=fit(o.palette,6), cool=c.slice(0,3), hot=c.slice(3);
    // The strongest chip follows the surviving shot; its neighbour leaves later.
    for(const [dx,dy,delay,life,r,lit] of [[-15,-5,0,.19,1.7,false],[-8,-10,.034,.20,1.3,true],[-10,5,.073,.18,1.1,false],[5,-6,.02,.19,1.15,true]]) {
      const u=(t-delay)/life;
      if(u<0||u>=1) continue;
      const travel=1-(1-u)**2, side=dy*travel+4*u*u;
      const x=physical ? -side*.8 : dx*travel;
      const y=physical ? -dx*travel*.82 : side;
      chip(p,x,y,Math.max(.65,r*(1-u*.55)),lit?hot:cool,Math.min(1,(1-u)*3),physical||lit);
    }
  });
}
function settle(fit,physical) {
  return effect("Contact beads",.42,physical,(p,t,o)=>{
    const c=fit(o.palette,6), cool=c.slice(0,3), hot=c.slice(3);
    if(t<.105) {
      const squeeze=Math.sin(Math.PI*t/.105);
      p.ellipse(-1,-.6,2.4-squeeze*.65,1.4+2*squeeze,cool[1],.78);
      p.dot(-1.5,-1.5-squeeze,cool[2],.8);
      p.line(1,0,2,-squeeze*2,hot[1],.86);
    }
    for(const [start,life,dx,vy,g,r,warm] of [[.059,.29,-8,-13,21,2.05,false],[.093,.23,4,-20,8,1.45,true],[.127,.24,-3,-7,15,1.2,false]]) {
      const u=(t-start)/life;
      if(u<0||u>=1) continue;
      const x=dx*(1-(1-u)**2), y=vy*u+g*u*u;
      chip(p,x,y,r*(1-.48*u),warm?hot:cool,Math.min(1,(1-u)*3.4),physical||warm);
    }
  });
}
export const skim_water=fit=>skim(fit,false);
export const skim_claw=fit=>skim(fit,true);
export const settle_water=fit=>settle(fit,false);
export const settle_claw=fit=>settle(fit,true);
