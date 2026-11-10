"""Extract Wrap's native quarter mask and mirror it for continuous ribbon segments."""
import json
import plat_fx as fx
import plat_fetch

def main():
 plat_fetch.fetch('res/graphics/battle/particles/wrap.spa',False)
 data=(fx.SRC/'wrap.spa').read_bytes()
 texture=fx.spa_textures(data)[0]
 for name,image in [('kanto_wrap_0',texture),('kanto_wrap_soft',fx.mirror(texture,'quad'))]:
  target=fx.OUT/(name+'.png')
  if not target.exists():image.save(target)
 out=fx.ROOT/'docs/kanto_wrap_fx_review';out.mkdir(exist_ok=True)
 (out/'source_emitters.json').write_text(json.dumps(fx.spa_resources(data),indent=2)+'\n')
 print('Wrap: original quarter mask and mirrored soft mask extracted')
if __name__=='__main__':main()
