"""Export the selected forward casts and a time-aligned original for each clip."""
import argparse
from pathlib import Path
import json
from PIL import Image, ImageDraw, ImageFont

project = Path(__file__).resolve().parents[2]
output = project / 'docs/charmander_forward_casts'
before = project / 'docs/charmander_move_audit/no-target'
names = json.loads((project/'assets/data/names_ko.json').read_text())['moves']
groups = [('scratch','slash','fire_fang'), ('smoke_screen','dragon_breath','flamethrower'), ('fire_spin','inferno','flare_blitz')]
parser = argparse.ArgumentParser()
parser.add_argument('group', type=int, choices=[1,2,3])
parser.add_argument('--sv',action='store_true',help='Compare the previous study with the SV-based study')
args = parser.parse_args()
group = args.group
if args.sv:
    before = output/'native'
    output = project/'docs/charmander_sv_forward'
previous_label = '이전 시안' if args.sv else '본편'
new_label = '원작 참고 시안' if args.sv else '수정안'
rows = {r['move']: r for r in json.loads((output/'native.json').read_text())}
font = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 15)
small_font = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 12)
new, pairs, durations, samples = [], [], [], []
highlights = {'scratch':11,'slash':11,'fire_fang':13,'smoke_screen':29,'dragon_breath':14,'flamethrower':19,'fire_spin':29,'inferno':18,'flare_blitz':11}
if args.sv:
    highlights.update(dragon_breath=22,flare_blitz=17,inferno=25,fire_fang=16)
for move in groups[group-1]:
    row = rows[move]
    assert row['spent'] and row['art_frames'] and row['enemies']==0
    count = int(row['frames'])
    original, updated = [], []
    for base, frames in [(before,original),(output/'native',updated)]:
        for i in range(count):
            with Image.open(base/move/f'{i:03}.png') as im:
                assert im.size == (384,216)
                frames.append(im.convert('RGB').crop((108,20,360,162)))
    atlas = Image.new('RGB',(252*8,142*((2*count+7)//8)+20),'#26312b')
    for i,f in enumerate(original+updated):
        atlas.paste(f,(i%8*252,i//8*142))
    ImageDraw.Draw(atlas).text((12,atlas.height-18),names[move],font=small_font,fill='white')
    base = atlas.quantize(160, dither=Image.Dither.NONE)
    extra = atlas.resize((504, max(142,atlas.height//4)),Image.Resampling.NEAREST).quantize(96, method=Image.Quantize.MAXCOVERAGE)
    palette = Image.new('P',(1,1))
    palette.putpalette(base.getpalette()[:480]+extra.getpalette()[:288])
    samples.append(len(new)+highlights[move])
    for i,(a,b) in enumerate(zip(original,updated)):
        pair = Image.new('RGB',(504,163),'#26312b')
        pair.paste(a,(0,21)); pair.paste(b,(252,21))
        draw=ImageDraw.Draw(pair)
        draw.text((6,2),previous_label+'  ·  '+names[move],font=small_font,fill='white')
        draw.text((258,2),new_label+'  ·  '+names[move],font=small_font,fill='white')
        draw.line((252,21,252,162),fill='#535f58')
        single=Image.new('RGB',(504,306),'#26312b')
        single.paste(b.resize((504,284),Image.Resampling.NEAREST),(0,22))
        ImageDraw.Draw(single).text((8,0),names[move],font=font,fill='white')
        new.append(single.quantize(palette=palette,dither=Image.Dither.NONE))
        pairs.append(pair.quantize(palette=palette,dither=Image.Dither.NONE))
        durations.append((round((i+1)*40/9)-round(i*40/9))*10)
for label,frames in [('sample',new),('compare',pairs)]:
    path=output/f'{label}-{group}.gif'
    frames[0].save(path,save_all=True,append_images=frames[1:],duration=durations,disposal=1,optimize=False,loop=0)
    marks=[sum(durations[:i]) for i in samples]
    proof=Image.new('RGB',(504,frames[0].height*3))
    with Image.open(path) as decoded:
        elapsed=0
        for i in range(decoded.n_frames):
            decoded.seek(i)
            if marks and elapsed<=marks[0]<elapsed+decoded.info['duration']:
                proof.paste(decoded.convert('RGB'),(0,(3-len(marks))*frames[0].height))
                marks.pop(0)
            elapsed+=decoded.info['duration']
        assert not marks and elapsed==sum(durations)
    if label=='compare': proof.save(output/f'proof-{group}.png')
    print(label,group,elapsed,'ms',flush=True)
