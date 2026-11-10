"""Render supplied before/after poses at both clocks with real pixelfx."""
from pathlib import Path
import json,sys,os
import numpy as np
from PIL import Image,ImageDraw
import charmander_2x_motion_polish as s
from charmander_native_actions_pixelfx import sprite

OUT=s.OUT


def prepare():
    m=json.loads((OUT/'study.json').read_text());items=[];timelines={}
    for name,a in m['actions'].items():
        row=min(2,a['rows']-1);paths={v:s.files(name,row,v) for v in ['baseline','refined']}
        starts=sorted(set(int(t) for v in paths for t in np.cumsum([0]+a[v+'_ticks'][:-1])))
        timeline=[]
        for j,t in enumerate(starts):
            indices=[s.index_at(t,a[v+'_ticks'],a['loop']) for v in ['baseline','refined']]
            inputs=[paths[v][k] for v,k in zip(['baseline','refined'],indices)]
            items.append(dict(action=name,key=j,at_tick=t,indices=indices,
                variants=[dict(sprite(p),label='OLD 2X' if i==0 else 'REFINED 2X',counter=f'{indices[i]+1}/{len(paths["baseline"])}') for i,p in enumerate(inputs)],
                inputs=[dict(path=os.path.relpath(p,OUT),sha256=s.digest(p)) for p in inputs]))
            timeline.append(dict(key=j,at_tick=t,indices=indices))
        timelines[name]=timeline
    (OUT/'pixelfx-input.json').write_text(json.dumps(items)+'\n')
    (OUT/'pixelfx-timelines.json').write_text(json.dumps(timelines,indent=2)+'\n')
    print('Prepared',len(items),'before/after pose pairs at the union of actual frame times.',flush=True)


def verify():
    items=json.loads((OUT/'pixelfx-input.json').read_text());panels=0
    for item in items:
        for bg in ['dark','light']:
            rendered=Image.open(OUT/'pixelfx-renders'/f"{item['action']}-{item['key']:03d}-{bg}.png").convert('RGB')
            for side,inp in enumerate(item['inputs']):
                p=OUT/inp['path'];assert s.digest(p)==inp['sha256'];im=Image.open(p).convert('RGBA');expected=Image.new('RGB',im.size,'#222a28' if bg=='dark' else '#d7d8c4');expected.paste(im,(0,0),im)
                x=side*192+96-im.width//2;y=120-im.height//2
                assert rendered.crop((x,y,x+im.width,y+im.height)).tobytes()==expected.tobytes();panels+=1
    result=dict(renderer='pixelfx Painter.sprite/createFrame/composite/encodePNG',comparisons=len(items)*2,exact_native_panels=panels,
                generated_character_art=False,anatomy_certified=False)
    (OUT/'pixelfx-qa.json').write_text(json.dumps(result,indent=2)+'\n');print(result,flush=True)


def gifs():
    m=json.loads((OUT/'study.json').read_text());timelines=json.loads((OUT/'pixelfx-timelines.json').read_text())
    folder=OUT/'gifs';folder.mkdir(exist_ok=True)
    for name,a in m['actions'].items():
        lookup={tuple(item['indices']):item['key'] for item in timelines[name]}
        for rate in [1,.25]:
            period=a['duration_ticks']+(0 if a['loop'] else 60)
            total_ms=round((a['duration_ticks']*25+(0 if a['loop'] else 1500))/rate)
            frames=[];durations=[];cache={};last=None
            for ms in range(0,total_ms,10):
                t=(ms*.12*rate)%period
                key=lookup[tuple(s.index_at(t,a[v+'_ticks'],a['loop']) for v in ['baseline','refined'])]
                if key==last:durations[-1]+=10;continue
                if key not in cache:
                    im=Image.open(OUT/'pixelfx-renders'/f'{name}-{key:03d}-dark.png').convert('RGB')
                    ImageDraw.Draw(im).text((7,33),f'BOTH {rate:g}X SPEED / NATIVE GRID',fill='#f1e8d5')
                    cache[key]=im.resize((768,432),Image.Resampling.NEAREST)
                frames.append(cache[key]);durations.append(10);last=key
            frames[0].save(folder/f'{name}-{rate:g}speed.gif',save_all=True,append_images=frames[1:],duration=durations,loop=0,disposal=2,optimize=False)
        print('GIF',name,flush=True)


if __name__=='__main__':
    {'prepare':prepare,'verify':verify,'gifs':gifs}[sys.argv[1]]()
