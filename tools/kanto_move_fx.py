"""Extract original particle textures for the first Kanto wild-skill FX pass."""
import json
from concurrent.futures import ThreadPoolExecutor
from PIL import Image,ImageDraw
import plat_fx as fx
import plat_fetch
MOVES=['absorb','mega_drain','acid','supersonic']
def main():
 with ThreadPoolExecutor(max_workers=4) as pool:
  list(pool.map(lambda move:plat_fetch.fetch('res/graphics/battle/particles/'+move+'.spa',False),MOVES))
 records={};sheet=Image.new('RGB',(768,128*len(MOVES)),(40,42,48));draw=ImageDraw.Draw(sheet)
 for row,move in enumerate(MOVES):
  data=(fx.SRC/(move+'.spa')).read_bytes();textures=fx.spa_textures(data)
  records[move]=fx.spa_resources(data)
  for index,texture in enumerate(textures):
   target=fx.OUT/f'kanto_{move}_{index}.png'
   if not target.exists():texture.save(target)
   size=texture.size;im=texture.resize((min(96,size[0]*3),min(96,size[1]*3)),Image.Resampling.NEAREST)
   x=index*120;sheet.paste(im,(x,row*128+24),im);draw.text((x,row*128+4),f'{move}:{index}',fill='white')
  print(move,[(i,t.size) for i,t in enumerate(textures)],records[move])
 out=fx.ROOT/'docs/kanto_move_fx_review';out.mkdir(exist_ok=True)
 sheet.save(out/'source_textures.png');(out/'source_emitters.json').write_text(json.dumps(records,indent=2)+'\n')
if __name__=='__main__':main()
