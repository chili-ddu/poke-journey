"""Native particles and missing audio for mainland wild actions."""
from concurrent.futures import ThreadPoolExecutor
from PIL import Image, ImageDraw
import plat_fetch
import plat_fx as fx
import kanto_audio

PARTICLES=['headbutt','lick','mud_slap','icy_wind','counter','mirror_coat']

def main():
    with ThreadPoolExecutor(max_workers=6) as pool:
        list(pool.map(lambda move:plat_fetch.fetch('res/graphics/battle/particles/'+move+'.spa',False),PARTICLES))
    paths=[]
    for move in PARTICLES:
        for index,texture in enumerate(fx.spa_textures((fx.SRC/(move+'.spa')).read_bytes())):
            path=fx.OUT/f'world_{move}_{index}.png'
            if not path.exists():texture.save(path)
            paths.append(path)
    sheet=Image.new('RGB',(640,180*((len(paths)+3)//4)),(35,38,43));draw=ImageDraw.Draw(sheet)
    for i,path in enumerate(sorted(paths)):
        image=Image.open(path).convert('RGBA');image=image.resize((image.width*2,image.height*2),Image.Resampling.NEAREST)
        x,y=i%4*160,i//4*180
        sheet.paste(image,(x,y+22),image);draw.text((x,y),path.stem,fill='white')
    out=fx.ROOT/'docs/kanto_world_wild';out.mkdir(exist_ok=True);sheet.save(out/'source_particles.png')
    old=kanto_audio.MOVES
    try:
        kanto_audio.MOVES=PARTICLES+['transform','leer']
        kanto_audio.main()
    finally:kanto_audio.MOVES=old

if __name__=='__main__':main()
