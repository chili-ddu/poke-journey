"""Extract original Pound, Peck and Astonish contact particles."""
import json
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageDraw
import plat_fx as fx
import plat_fetch
MOVES={'pound':'pound','peck':'peck','astonish':'astonish'}
def main():
 with ThreadPoolExecutor(max_workers=3) as pool:
  list(pool.map(lambda source:plat_fetch.fetch('res/graphics/battle/particles/'+source+'.spa',False),MOVES.values()))
 out=fx.ROOT/'docs/kanto_contact_fx_review';out.mkdir(exist_ok=True)
 records={};sheet=Image.new('RGB',(960,180*3),(40,42,48));draw=ImageDraw.Draw(sheet)
 for row,(move,source) in enumerate(MOVES.items()):
  data=(fx.SRC/(source+'.spa')).read_bytes();textures=fx.spa_textures(data)
  records[move]={'source':source,'emitters':fx.spa_resources(data)}
  for index,texture in enumerate(textures):
   target=fx.OUT/f'kanto_{move}_{index}.png'
   if not target.exists():texture.save(target)
   im=texture.resize((min(112,texture.width*3),min(112,texture.height*3)),Image.Resampling.NEAREST)
   sheet.paste(im,(index*128,row*180+28),im);draw.text((index*128,row*180+6),f'{move}:{index}',fill='white')
  print(move,[(i,t.size) for i,t in enumerate(textures)],records[move])
 sheet.save(out/'source_textures.png');(out/'source_emitters.json').write_text(json.dumps(records,indent=2)+'\n')
if __name__=='__main__':main()
