// Each layer travels along local +X. The review orients each layer separately
// from its attack's velocity, so the two materials keep their own momentum.
const materials = {
  fire: {palette:["#aa613f","#e8995b","#ffddb1"], pieces:[[20,-5,0,.22,1.6],[14,3,.026,.18,1],[10,-4,.054,.22,.9]]},
  water: {palette:["#528aa0","#8bcbd7","#d4eef0"], pieces:[[24,-4,0,.23,1.7],[16,5,.018,.23,1.3],[12,-7,.052,.19,1]]},
  normal: {palette:["#b5b5b5","#e3e3e3","#ffffff"], pieces:[[21,-6,0,.23,1.65],[15,4,.023,.20,1.15],[10,-3,.046,.18,1]]}
};
// Secondary chips retain forward travel and clear the centre in staggered groups.
const extras = {
  fire:[[16,-10,.012,.21,1.15],[8,7,.034,.16,.85],[23,3,.048,.20,1.05],[13,-2,.074,.18,.9],[18,11,.088,.19,.85]],
  water:[[18,10,.01,.24,1.4],[10,-8,.03,.16,.95],[23,5,.055,.21,1.15],[14,2,.075,.17,1],[8,7,.095,.18,.95]],
  normal:[[16,9,.013,.20,1.15],[9,-7,.032,.18,.95],[24,2,.044,.20,1.1],[13,1,.070,.17,.95],[19,-11,.085,.18,.9]]
};
// A later spray fans out farther than the first group. Keep some open lanes
// between droplets so the moving highlights have individual silhouettes.
const spray = {
  fire:[[30,-12,.005,.26,1.65],[25,8,.02,.23,1.3],[13,13,.047,.17,.95],[20,-16,.064,.23,1.1],[28,0,.081,.20,1.2],[9,-9,.105,.16,.85],[21,14,.12,.19,1.05],[16,-4,.14,.20,.9]],
  water:[[30,9,0,.27,1.85],[23,-13,.026,.26,1.4],[14,15,.042,.20,1.1],[28,-5,.061,.24,1.45],[12,-12,.082,.20,1],[19,5,.10,.19,1.05],[27,14,.12,.21,1.15],[9,-3,.14,.18,.85]],
  normal:[[31,-10,0,.25,1.65],[26,8,.021,.23,1.3],[15,-15,.039,.21,1.1],[24,-3,.057,.19,1.1],[18,14,.075,.24,1.15],[11,8,.10,.17,.9],[27,-15,.118,.22,1.05],[15,-5,.14,.19,.95]]
};
function layer(fit, type, dense, shimmer, taper) {
  const material=materials[type];
  const pieces=[...material.pieces];
  if(dense || shimmer) pieces.push(...extras[type]);
  if(shimmer) pieces.push(...spray[type]);
  return {
    meta:{name:type+" carried fragments",desc:"Small pieces carried through a clash",tags:["clash","impact"],
      size:shimmer ? [72,44] : [56,32],origin:shimmer ? [36,22] : [28,16],duration:shimmer ? .39 : .31,fps:30,loop:false,bg:"ground",options:{palette:material.palette}},
    draw(p,t,o) {
      const ink=fit(o.palette,3);
      for(const [distance,spread,delay,life,size] of pieces) {
        const u=(t-delay)/life;
        if(u<0||u>=1) continue;
        const travel=1-(1-u)**2, x=1.2+distance*travel, y=spread*travel;
        // Taper each fragment from its own release, including the late spray.
        const r=size*(taper ? 1.35*(1-u)**.88 : 1-.45*u);
        const alpha=Math.min(1,(1-u)*(taper ? 2.5 : 3.7));
        if(type==="water") {
          p.ellipse(x,y,r*(1.8-.7*u),r,ink[0],alpha);
          p.ellipse(x+.35,y-.4,r*(1.45-.45*u),r*.78,ink[1],alpha);
          p.dot(x+.65,y-.6,ink[2],alpha);
        } else {
          const tail=2.3*r*(1-.55*u);
          if(taper && r>1.05) p.disc(x-r*.65,y,r*.84,ink[1],alpha);
          p.line(x-tail,y-spread*.07,x,y,ink[1],alpha);
          p.disc(x,y,r*.76,ink[2],alpha);
        }
      }
    }
  };
}
export const fire=(fit,dense=false,shimmer=false,taper=false)=>layer(fit,"fire",dense,shimmer,taper);
export const water=(fit,dense=false,shimmer=false,taper=false)=>layer(fit,"water",dense,shimmer,taper);
export const normal=(fit,dense=false,shimmer=false,taper=false)=>layer(fit,"normal",dense,shimmer,taper);
