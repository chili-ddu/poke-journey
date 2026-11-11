// pixelfx effect module. Local origin is the glowing centre of the open ball.
import { fit, sparkle } from "../../core/index.js";

export const meta = {
  name: "Ball release", desc: "A seam of warm light opens and leaves a few rising flecks.",
  size: [64, 64], origin: [32, 32], duration: 0.70, fps: 30, loop: false,
  tags: ["release", "light"], options: { palette: ["#dc915c", "#ffd896", "#fff0cb", "#fffcf2"] }
};

const rays = [[-0.88,-0.48,17], [0.63,-0.78,16], [0.98,-0.06,13], [-0.38,0.52,9]];
const flecks = [[-13,-7,0.09],[11,-10,0.16],[-8,5,0.22],[15,3,0.11],[4,-15,0.26]];

export function drawSeam(p, t, [, gold, cream, white]) {
  if (t < 0.22) {
    const k = t / 0.22, pulse = Math.sin(Math.PI * k);
    const width = 2 + 7 * pulse;
    p.glow(0,-1,6 + pulse * 8, gold,0.47*(1-k));
    p.disc(0,-1,1 + 2 * pulse,cream,1-k);
    if (t < 0.12) p.line(-width,-1,width,-1,white,1-t/0.12);
    for (const [dx,dy,length] of rays) {
      const tip = length * (1 - (1-k)**2);
      const base = length * k*k;
      p.line(dx*base,dy*base-1,dx*tip,dy*tip-1,cream,1-k);
    }
  }
}

export function draw(p, t, options) {
  if (t >= meta.duration) return;
  const colors = fit(options.palette,4);
  const [amber, gold, cream] = colors;
  drawSeam(p,t,colors);
  for (let i=0;i<flecks.length;i++) {
    const [x,y,delay] = flecks[i];
    const k = (t-delay)/0.36;
    if (k <= 0 || k >= 1) continue;
    const spread = 0.52 + 0.48 * (1-(1-k)**2);
    const px = x*spread, py = y*spread - 5*k;
    const pulse = Math.sin(Math.PI*k);
    if (i%2 === 0 && pulse>0.75) sparkle(p,px,py,1.7*pulse,cream,gold,0.15);
    else p.dot(px,py,k<0.55 ? cream : amber,pulse);
  }
}
