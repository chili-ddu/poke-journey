from pathlib import Path
import json
from statistics import median
from PIL import Image,ImageDraw
from package_ember_hit_variants import gif
ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/skill_fx_bases/batch1'
KINDS=['fire','water','electric','grass']
LABELS=['FIRE / ENVELOP','WATER / RUNOFF','ELECTRIC / CURRENT','GRASS / LEAVES']

def body_crop(image,reference=None):
    # Original capture supplies one shared crop for both variants.
    source=reference if reference is not None else image
    pts=[(x,y) for y in range(55,145) for x in range(235,384)
         if (lambda c:c[0]>c[1]*1.18 and c[2]>c[1]*.93 and c[2]<c[1]*1.15 and c[0]>145)(source.getpixel((x,y))) ]
    if not pts:raise ValueError('Target pink-body crop could not be located')
    cx=int(median(p[0] for p in pts));cy=int(median(p[1] for p in pts))+5
    return image.crop((cx-45,cy-45,cx+45,cy+45))

def main():
    checks=json.loads((OUT/'native/checks.json').read_text())
    assert len(checks)==8
    captures={}
    for k in KINDS:
        rows=[r for r in checks if r['type']==k]
        assert len(rows)==2 and len({(r['damage'],r['hit_frame']) for r in rows})==1
        captures[k]={v:[Image.open(OUT/f'native/{k}/{v}/{f:03}.png').convert('RGB') for f in range(66)] for v in ['current','sample']}
    # Align comparisons to each move's real HP-decrease frame; never retime motion.
    frames=[];details={k:[] for k in KINDS};contact=Image.new('RGB',(720,208*5),(28,33,30));d=ImageDraw.Draw(contact)
    for offset in range(-4,30):
        board=Image.new('RGB',(720,408),(28,33,30));draw=ImageDraw.Draw(board)
        for col,k in enumerate(KINDS):
            hit=int(next(r['hit_frame'] for r in checks if r['type']==k))
            f=hit+offset
            draw.text((col*180+5,6),LABELS[col],fill=(238,233,218))
            # Original/sample native1x side by side, sample2x below.
            for side,v in enumerate(['current','sample']):
                crop=body_crop(captures[k][v][f],captures[k]['current'][f])
                board.paste(crop,(col*180+side*90,39))
                draw.text((col*180+side*90+4,25),'CURRENT' if side==0 else 'SAMPLE',fill=(200,204,192))
                if v=='sample':board.paste(crop.resize((180,180),Image.Resampling.NEAREST),(col*180,148))
            draw.text((col*180+8,345),'1x comparison above',fill=(200,204,192))
            draw.text((col*180+8,362),'2x sample below',fill=(200,204,192))
            draw.text((col*180+8,381),f'impact {offset:+d} frames',fill=(200,204,192))
            pair=Image.new('RGB',(540,296),(28,33,30));pd=ImageDraw.Draw(pair)
            for side,v in enumerate(['current','sample']):
                pd.text((side*270+8,8),v.upper(),fill=(238,233,218))
                crop=body_crop(captures[k][v][f],captures[k]['current'][f]).resize((270,270),Image.Resampling.NEAREST)
                pair.paste(crop,(side*270,26))
            details[k].append(pair)
        frames.append(board)
    durations=[30 if n%3<2 else 40 for n in range(len(frames))]
    gif(OUT/'four-types.gif',frames,durations)
    for k,images in details.items():gif(OUT/f'{k}-comparison.gif',images,durations)
    for row,delta in enumerate([1,4,8,13,21]):
        for col,k in enumerate(KINDS):
            hit=int(next(r['hit_frame'] for r in checks if r['type']==k))
            im=body_crop(captures[k]['sample'][hit+delta],captures[k]['current'][hit+delta]).resize((180,180),Image.Resampling.NEAREST)
            d.text((col*180+5,row*208+6),k+f' +{delta}f',fill=(238,233,218));contact.paste(im,(col*180,row*208+28))
    contact.save(OUT/'native-contact.png')
    print('Packaged four native hit comparisons, same-speed original/sample and native-size overview')

if __name__=='__main__':main()
