import { fit } from "../../core/index.js";
import { drawSeam, meta as release } from "./release.js";

export const meta = { ...release, name: "Grounded ball release",
  desc: "A grounded shell opens and sixteen fine gold motes rise past its sides." };

// Keep the central face area clear. Delays are staggered so the brightest
// points travel around the silhouette rather than lighting up as one ring.
const motes = [
  [-11,-10,.06], [9,-14,.12], [16,-2,.08], [-16,1,.17],
  [-7,-16,.22], [12,6,.20], [-12,7,.09], [17,-9,.25],
  [-18,-6,.28], [5,-19,.19], [9,10,.13], [-7,11,.27],
  [14,-14,.32], [-10,-17,.15], [19,3,.21], [-16,5,.33]
];

export function draw(p,t,options) {
  if (t >= meta.duration) return;
  const colors = fit(options.palette,4);
  drawSeam(p,t,colors);
  for (const [x,y,delay] of motes) {
    const k = (t-delay)/0.32;
    if (k <= 0 || k >= 1) continue;
    const spread = 0.64 + 0.36*(1-(1-k)**2);
    const px = x*spread, py = y*spread-5*k;
    const pulse = Math.sin(Math.PI*k);
    p.light(px,py,colors[2],0.45*pulse);
    p.dot(px,py,k<0.6 ? colors[2] : colors[1],Math.min(1,pulse*1.4));
  }
}
