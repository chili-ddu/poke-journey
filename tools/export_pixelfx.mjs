// node tools/export_pixelfx.mjs [path/to/pixelfx]
// Render existing MIT effects into the game's vertical animation format.
import { resolve, dirname, join } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { mkdirSync, writeFileSync, copyFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '..');
const library = resolve(process.argv[2] ?? join(root, '../pixelfx'));
const { loadEffect, renderFrames } = await import(pathToFileURL(join(library, 'tools/lib/fxlib.mjs')));
const { encodePNG } = await import(pathToFileURL(join(library, 'tools/lib/png.mjs')));
const out = join(root, 'assets/fx/pixelfx');
mkdirSync(out, { recursive: true });
const specs = [
  { name: 'pickup', id: 'pickups/collect-burst', center: [56,64], first: 16, last: 32,
    rect: [8,16,96,96], output: [48,48], options: { light: 0.02,
      palette: ['#695744','#897450','#a08b65','#bfaa7a','#d0bd8c','#ede0b9','#f6eed7','#f8f4e6'] } },
  { name: 'scratch', id: 'impacts/hit-spark', center: [44, 44], options: {
    palette: ['#39343a', '#665b58', '#958678', '#c0b29c', '#d8cdb8', '#eee4ce', '#f5eedf'], aim: 1.35, seed: 17, light: 0.04 } },
  { name: 'ember', id: 'impacts/hit-spark', center: [44, 44], options: { light: 0.3, aim: -0.4 } },
  { name: 'smoke', id: 'spawn/poof', center: [56, 63], first: 3, last: 34, options: {
    palette: ['#202530', '#343d49', '#4e5864', '#6c7781', '#929ba1', '#b4bbbf'],
    stars: ['#343d49', '#4e5864', '#6c7781'], light: 0 } },
  { name: 'flame', id: 'fire/spirit-flame', center: [40,94], rect: [22,40,36,60], output: [24,40], options: {
    palette: ['#42170e','#76220f','#ab3311','#d84c16','#f57320','#ffad32','#ffcf58','#ffe99b','#fff5cf'], light: 0.16 } },
];
const manifest = { repository: 'https://github.com/patch-gg/pixelfx',
  revision: execFileSync('git', ['rev-parse', 'HEAD'], { cwd: library, encoding: 'utf8' }).trim(), effects: {} };
for (const spec of specs) {
  const effect = await loadEffect(spec.id);
  const render = renderFrames(effect, { actor: false, bg: 'none', options: spec.options });
  const frames = render.frames.slice(spec.first ?? 0, spec.last ?? render.n);
  const [cx, cy] = spec.center;
  let radius = 1;
  for (const frame of frames) {
    for (let y = 0; y < render.h; y++) for (let x = 0; x < render.w; x++) {
      if (frame.clear[(y * render.w + x) * 4 + 3] >= 16)
        radius = Math.max(radius, Math.abs(x - cx) + 2, Math.abs(y - cy) + 2);
    }
  }
  const [width,height] = spec.output ?? [64,64];
  const [left,top,sourceWidth,sourceHeight] = spec.rect ?? [cx-radius,cy-radius,radius*2,radius*2];
  const pixels = new Uint8Array(width * height * frames.length * 4);
  for (let f = 0; f < frames.length; f++) {
    for (let y = 0; y < height; y++) for (let x = 0; x < width; x++) {
      const sx = Math.floor(left + (x + 0.5) * sourceWidth / width);
      const sy = Math.floor(top + (y + 0.5) * sourceHeight / height);
      if (sx < 0 || sy < 0 || sx >= render.w || sy >= render.h) continue;
      const source = (sy * render.w + sx) * 4, dest = ((f * height + y) * width + x) * 4;
      if (frames[f].clear[source + 3] < 16) continue;
      pixels.set(frames[f].clear.subarray(source, source + 4), dest);
    }
  }
  writeFileSync(join(out, `${spec.name}.png`), encodePNG(width, height * frames.length, pixels));
  manifest.effects[spec.name] = { id: spec.id, frames: frames.length, frame_size: [width,height], pivot: [(cx-left)*width/sourceWidth,(cy-top)*height/sourceHeight], source_rect: [left,top,sourceWidth,sourceHeight], options: spec.options };
  console.log(`${spec.name}: ${frames.length} frames, ${width}x${height} cell`);
}
copyFileSync(join(library, 'LICENSE'), join(out, 'LICENSE.txt'));
writeFileSync(join(out, 'manifest.json'), JSON.stringify(manifest, null, 2) + '\n');
