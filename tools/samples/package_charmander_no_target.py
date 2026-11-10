"""Show each empty cast on its own, with the same nearest-neighbour 2x scale."""
import argparse
import json
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont

project = Path(__file__).resolve().parents[2]
out = project / 'docs/charmander_move_audit/no-target'
font = ImageFont.truetype('/System/Library/Fonts/AppleSDGothicNeo.ttc', 18)
names = json.loads((project/'assets/data/names_ko.json').read_text())['moves']
parser = argparse.ArgumentParser()
parser.add_argument('group', type=int, choices=[1, 2, 3])
group = parser.parse_args().group
learnset = json.loads((project/'assets/data/species.json').read_text())['charmander']['learnset']
frames, durations = [], []
for level, move in learnset[(group-1)*4:group*4]:
    files = sorted((out/move).glob('[0-9][0-9][0-9].png'))
    count = 120 if move == 'fire_spin' else 84 if move in ('smoke_screen', 'scary_face') else 54
    assert len(files) == count, move
    left = 63 if move == 'fire_spin' else 118
    small = []
    for i, path in enumerate(files):
        with Image.open(path) as image:
            assert image.size == (384,216)
            small.append(image.convert('RGB').crop((left, 42, left+252, 172)))
    # Share a palette for the entire move, including the title strip.
    atlas = Image.new('RGB', (252*8, 130*((count+7)//8)+26), '#24302b')
    for i, frame in enumerate(small):
        atlas.paste(frame, (252*(i%8), 130*(i//8)))
    ImageDraw.Draw(atlas).text((6,atlas.height-24),names[move],font=font,fill='#fff7e5')
    # Ground colours dominate the full-frame histogram. Reserve colours for
    # brief, bright effects so the flame's internal shading survives GIF export.
    base = atlas.quantize(160, dither=Image.Dither.NONE)
    swatches = atlas.resize((630, max(130, atlas.height//3)), Image.Resampling.NEAREST)
    accents = swatches.quantize(96, method=Image.Quantize.MAXCOVERAGE)
    palette = Image.new('P', (1,1))
    palette.putpalette(base.getpalette()[:480] + accents.getpalette()[:288])
    for i, frame in enumerate(small):
        canvas = Image.new('RGB',(504,288),'#24302b')
        canvas.paste(frame.resize((504,260), Image.Resampling.NEAREST), (0,28))
        ImageDraw.Draw(canvas).text((9,2),f'Lv.{level}   {names[move]}',font=font,fill='#fff7e5')
        frames.append(canvas.quantize(palette=palette, dither=Image.Dither.NONE))
        # 30 simulated frames in 1.333 s: 0.75x playback, GIF centisecond clock.
        durations.append((round((i+1)*40/9)-round(i*40/9))*10)
dest = out / f'empty-{group}.gif'
frames[0].save(dest, save_all=True, append_images=frames[1:], duration=durations, loop=0,
               optimize=False, disposal=1)
proof = Image.new('RGB',(504,288*4))
with Image.open(dest) as im:
    assert im.size == (504,288)
    samples=[]
    start=0
    for level,move in learnset[(group-1)*4:group*4]:
        n=120 if move=='fire_spin' else 84 if move in ('smoke_screen','scary_face') else 54
        k={'scratch':13,'growl':18,'ember':19,'smoke_screen':32,'dragon_breath':16,'fire_fang':11,'slash':12,'flamethrower':18,'scary_face':28,'fire_spin':31,'inferno':17,'flare_blitz':13}[move]
        samples.append(sum(durations[:start+k]))
        start+=n
    elapsed=0
    for i in range(im.n_frames):
        im.seek(i)
        if samples and elapsed<=samples[0]<elapsed+im.info['duration']:
            proof.paste(im.convert('RGB'),(0,(4-len(samples))*288))
            samples.pop(0)
        elapsed+=im.info['duration']
    assert not samples and elapsed==sum(durations)
proof.save(out/f'proof-{group}.png')
print(dest.name, len(frames),'frames verified', flush=True)
