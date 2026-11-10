// Short, rising steam with a pale contact core, drawn about the contact point.
export function vapor(fit) {
  const palette=["#6e8992","#a7c4c8","#d7e8dd","#fff0d7"];
  return {
    meta:{name:"Quench",desc:"Two shots quench in a small rising wisp",tags:["steam","projectile"],size:[36,34],origin:[18,22],duration:.4,loop:false,fps:30,bg:"ground",options:{palette}},
    draw(p,t,o) {
      const c=fit(o.palette,4), u=Math.min(1,t/.4), alpha=1-u*u;
      if (u<.22) p.disc(0,0,3.2*(1-u),c[3],d=>(1-d*d)*alpha);
      for(let i=0;i<5;i++){
        const side=i%2===0?-1:1, x=side*(1+i%3)*u*2.9+Math.sin(u*5+i)*1.1;
        const y=-u*(9+i%3*3.2)+.6*Math.cos(i), r=1.5+Math.sin(Math.PI*u)*(1.6+i%2);
        p.disc(x,y,r,c[i%2],d=>(1-d*d)*alpha*.86);
        p.disc(x-.4,y-.65,r*.75,c[2],d=>(1-d)*alpha*.95);
      }
    }
  };
}
