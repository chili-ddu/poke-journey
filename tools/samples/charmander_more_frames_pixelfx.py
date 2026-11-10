"""Real pixelfx rendering of supplied 2x/4x poses, never character generation."""
import json,sys,os
from pathlib import Path
from PIL import Image,ImageDraw
import charmander_more_frames as s
from charmander_native_actions_pixelfx import sprite

OUT=s.OUT


def prepare():
    m=json.loads((OUT/'study.json').read_text());items=[]
    for name,a in m['actions'].items():
        row=min(2,a['rows']-1);old=s.files(name,row,'double');new=s.files(name,row,'quad')
        for k,path in enumerate(new):
            inputs=[old[k//2],path]
            items.append(dict(action=name,key=k,variants=[sprite(p) for p in inputs],inputs=[dict(path=os.path.relpath(p,OUT),sha256=s.digest(p)) for p in inputs]))
    (OUT/'pixelfx-input.json').write_text(json.dumps(items)+'\n');print('Prepared',len(items),'2x/4x paired samples',flush=True)


def verify():
    items=json.loads((OUT/'pixelfx-input.json').read_text());panels=0
    for item in items:
        for bg in ['dark','light']:
            rendered=Image.open(OUT/'pixelfx-renders'/f"{item['action']}-{item['key']:03d}-{bg}.png").convert('RGB')
            for side,inp in enumerate(item['inputs']):
                p=OUT/inp['path'];assert s.digest(p)==inp['sha256'];im=Image.open(p).convert('RGBA')
                expected=Image.new('RGB',im.size,'#222a28' if bg=='dark' else '#d7d8c4');expected.paste(im,(0,0),im)
                x=side*192+96-im.width//2;y=120-im.height//2
                assert rendered.crop((x,y,x+im.width,y+im.height)).tobytes()==expected.tobytes();panels+=1
    (OUT/'pixelfx-qa.json').write_text(json.dumps(dict(renderer='pixelfx Painter.sprite/composite',comparisons=len(items)*2,
        exact_native_panels=panels,character_generated=False,anatomy_certified=False),indent=2)+'\n')
    print('Actual pixelfx native panels exact:',panels,flush=True)
    reels()


def reels():
    m=json.loads((OUT/'study.json').read_text())
    for name in ['Hop','Walk','Attack','Wake']:
        a=m['actions'][name]
        for rate in [1,.25]:
            frames=[];durations=[];cache={};last_k=None;cycle=a['duration_ticks']+(0 if a['loop'] else 360)
            total=round((a['duration_ticks']*25/6+(0 if a['loop'] else 1500))/rate)
            for ms in range(0,total,10):
                tick=(ms*.72*rate)%cycle;k=s.index_at(tick,a['ticks']['quad'],a['loop'])
                if k==last_k:
                    durations[-1]+=10;continue
                if k not in cache:
                    im=Image.open(OUT/'pixelfx-renders'/f'{name}-{k:03d}-dark.png').convert('RGB')
                    ImageDraw.Draw(im).text((7,33),f'BOTH {rate:g}X SPEED',fill='#f1e8d5')
                    cache[k]=im.resize((768,432),Image.Resampling.NEAREST)
                frames.append(cache[k]);durations.append(10);last_k=k
            frames[0].save(OUT/f'{name}-2-vs-4-{rate:g}speed.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2,optimize=False)
    print('Four normal/0.25-speed comparisons exported from actual pixelfx output.',flush=True)


if __name__=='__main__':
    if sys.argv[1]=='prepare':prepare()
    elif sys.argv[1]=='reels':reels()
    else:verify()
