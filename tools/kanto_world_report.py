"""Render the generated mainland's native placement for map-layout review."""
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont
import kanto_world as k

ROOT=Path(__file__).resolve().parents[1]

def run():
    manifest=json.loads((ROOT/'assets/data/kanto_world_manifest.json').read_text())
    width,height=manifest['width']*4,manifest['height']*4
    base=Image.open(ROOT/'assets/maps/kanto_world/preview.png').convert('RGB').resize((width,height),Image.Resampling.NEAREST)
    font_path=str(ROOT/'assets/fonts/Galmuri11.ttf')
    # This bundled bitmap font exposes its native 16px strike to FreeType.
    city_font=ImageFont.truetype(font_path,16)
    road_font=city_font
    world=k.read('kanto_world')
    areas={a['id']:a for a in world['areas']}
    out=ROOT/'docs/kanto_world';out.mkdir(exist_ok=True)

    def render(roads):
        image=base.copy();draw=ImageDraw.Draw(image)
        def label(x,y,text,font,road=False,saffron=False):
            bounds=draw.textbbox((0,0),text,font=font)
            w,h=bounds[2]-bounds[0]+12,bounds[3]-bounds[1]+10
            x=max(1,min(width-w-1,int(x-w/2)));y=max(1,min(height-h-1,int(y-h/2)))
            color='#78c7ed' if road else ('#e4c965' if saffron else '#e7f1e8')
            draw.rectangle((x,y,x+w,y+h),fill='#152d36',outline=color,width=1)
            draw.text((x+6,y+5-bounds[1]),text,font=font,fill=color)
        if roads:
            for a in world['areas']:
                if a['id'].startswith('route'):
                    text=a['id'].removeprefix('route').replace('_north',' 북').replace('_south',' 남')
                    label((a['x']+a['w']/2)*4,(a['y']+a['h']/2)*4,text,road_font,road=True)
        for folder in manifest['scope']:
            if folder.startswith('Route'):continue
            a=areas[k.fm.snake(folder)]
            label((a['x']+a['w']/2)*4,(a['y']+a['h']/2)*4,k.title(folder),city_font)
        x,y=manifest['positions']['SaffronCity_Connection']
        label((x+24)*4,(y+20)*4,'노랑시티 · 관문 연결',city_font,saffron=True)
        image.save(out/('mainland_routes.png' if roads else 'mainland_layout.png'))
    render(False);render(True)
    print('Mainland review maps:',width,height)

if __name__=='__main__':run()
