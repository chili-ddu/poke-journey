// PixelFX review, viewed from the side with fire arriving from the left.
// Each tuple sets a fragment's travel, lift, lifespan, and starting thickness.
const drops = [[-25,19,.44,2.5],[-15,28,.48,2.2],[8,19,.37,1.9],[-19,-6,.30,1.6],[17,10,.32,1.6]];
const embers = [[23,21,.37,2.5],[8,29,.43,2],[29,-3,.25,1.5],[-9,23,.32,1.6],[-19,8,.27,1.3]];
const clamp = x => Math.max(0,Math.min(1,x));
const palette=["#843e30","#ee7937","#ffe29a","#225b85","#4db3d3","#daf4eb"];
export function fragments(fit) {
  return {
    meta:{name:"Ember and spray",desc:"Broken cinders and droplets from opposing fire and water shots",tags:["clash","fire","water"],size:[72,62],origin:[36,34],duration:.5,loop:false,fps:30,bg:"ground",options:{palette}},
    draw(p,t,o) {
      const [char,fire,gold,rim,water,glint]=fit(o.palette,6);
      if(t<.06) {
        p.ellipse(-2,-1,3.5,2.6,fire);
        p.ellipse(2,0,3.6,2.7,water);
        p.disc(0,-1,2.2,gold);
      }
      for(const [travel,lift,life,size] of drops) {
        const u=t/life;
        if(u>=1) continue;
        const fade=clamp((1-u)*4), x=travel*(1-Math.exp(-2.4*u)), y=-lift*2.4*u+(lift*2.4+9)*u*u;
        const dx=travel*2.4*Math.exp(-2.4*u), dy=-lift*2.4+2*(lift*2.4+9)*u;
        const v=Math.hypot(dx,dy)||1,r=size*(1-.34*u);
        // Thin trailing neck becomes a round falling bead.
        p.line(x,y,x-dx/v*r*2.5,y-dy/v*r*2.5,water,fade*.9);
        p.disc(x,y,r+.45,rim,fade);
        p.disc(x-.2,y-.45,r,water,fade);
        p.disc(x-.55,y-.85,Math.max(.65,r*.48),glint,fade);
      }
      for(const [travel,lift,life,size] of embers) {
        const u=t/life;
        if(u>=1) continue;
        const fade=clamp((1-u)*3.5), x=travel*(1-Math.exp(-3*u))+Math.sin(8*u)*u*1.5;
        const y=-lift*(1-Math.exp(-2.4*u))+u*u*3;
        const r=size*(1-.62*u), dx=Math.sign(travel);
        p.line(x-3*dx,y+2,x,y,char,fade);
        p.ellipse(x,y,r*1.14,r*.87,fire,fade);
        p.line(x,y,x+dx,y-1,gold,fade*(1-u*.6));
      }
    }
  };
}
