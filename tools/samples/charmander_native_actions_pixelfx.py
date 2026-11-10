"""Serialize supplied character pixels for actual pixelfx Painter rendering.

pixelfx is a renderer here, not a character generator or anatomy checker.
"""
from pathlib import Path
import argparse
import hashlib
import json
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charmander_native_actions'
CHARS='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!@$%^&*()_+='


def sprite(path):
    im=Image.open(path).convert('RGBA');colors=list(dict.fromkeys(c for c in im.get_flattened_data() if c[3]))
    assert len(colors)<=len(CHARS)
    ids={c:CHARS[i] for i,c in enumerate(colors)}
    return dict(width=im.width,height=im.height,
        rows=[''.join(ids[im.getpixel((x,y))] if im.getpixel((x,y))[3] else '.' for x in range(im.width)) for y in range(im.height)],
        palette={ids[c]:'#%02x%02x%02x'%c[:3] for c in colors})


def prepare():
    m=json.loads((OUT/'study.json').read_text());items=[]
    for name,a in m['actions'].items():
        row=min(2,a['rows']-1)
        for k in range(len(a['added_ticks'])):
            paths=[OUT/'frames'/name/f'row-{row}'/v/f'{i:03d}.png' for v,i in [('original',k//2),('added',k)]]
            items.append(dict(action=name,row=row,key=k,variants=[sprite(p) for p in paths],
                inputs=[dict(path=str(p.relative_to(OUT)),sha256=hashlib.sha256(p.read_bytes()).hexdigest()) for p in paths]))
    (OUT/'pixelfx-input.json').write_text(json.dumps(items)+'\n')
    print(f'{len(items)} paired poses serialized from exact supplied PNGs.')


def verify():
    items=json.loads((OUT/'pixelfx-input.json').read_text());count=0
    for item in items:
        for bg in ['dark','light']:
            rgb='#222a28' if bg=='dark' else '#d7d8c4'
            render=Image.open(OUT/'pixelfx-renders'/f"{item['action']}-{item['key']:03d}-{bg}.png").convert('RGB')
            assert render.size==(384,216)
            for side,record in enumerate(item['inputs']):
                p=OUT/record['path'];assert hashlib.sha256(p.read_bytes()).hexdigest()==record['sha256']
                im=Image.open(p).convert('RGBA');expected=Image.new('RGB',im.size,rgb);expected.paste(im,(0,0),im)
                x=side*192+96-im.width//2;y=120-im.height//2
                assert render.crop((x,y,x+im.width,y+im.height)).tobytes()==expected.tobytes(),(item['action'],item['key'],side,bg)
                count+=1
    result=dict(renderer='pixelfx Painter.sprite/createFrame/composite/encodePNG',
        generated_character_art=False,anatomy_validated_by_pixelfx=False,
        source_images_hashes='pass',native_panels_exact=count,rendered_comparisons=len(items)*2,backgrounds=['dark','light'])
    (OUT/'pixelfx-qa.json').write_text(json.dumps(result,indent=2)+'\n')
    # Two preview reels from the actual pixelfx output at original timing.
    m=json.loads((OUT/'study.json').read_text())
    for file,names in [('combat',['Attack','Kick','Strike','Swing','Double','Charge','Hurt']),
                       ('movement',['Hop','LeapForth','Rotate','Trip','Wake','Faint']),
                       ('life',['Sleep','EventSleep','Eat','DeepBreath','Nod','Sit','LookUp'])]:
        frames=[]
        for name in names:
            a=m['actions'][name];duration=a['duration_ticks']*25+(0 if a['loop'] else 1500)
            cycle=a['duration_ticks']+(0 if a['loop'] else 60)
            for ms in range(0,duration,10):
                tick=(ms*.12)%cycle
                if not a['loop']:tick=min(tick,a['duration_ticks']-1e-8)
                k=0
                for i,t in enumerate(a['added_ticks']):
                    if tick<t:k=i;break
                    tick-=t
                frames.append(Image.open(OUT/'pixelfx-renders'/f'{name}-{k:03d}-dark.png').convert('RGB'))
        frames[0].save(OUT/f'{file}-pixelfx-1x.gif',save_all=True,append_images=frames[1:],duration=10,loop=0,disposal=2,optimize=False)
    print(json.dumps(result))


if __name__=='__main__':
    p=argparse.ArgumentParser();p.add_argument('command',choices=['prepare','verify']);a=p.parse_args()
    prepare() if a.command=='prepare' else verify()
