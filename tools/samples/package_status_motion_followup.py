"""Same-speed comparisons from untouched native PNG captures."""
from pathlib import Path
import json,math
from PIL import Image,ImageDraw,ImageSequence
ROOT=Path(__file__).resolve().parents[2];OUT=ROOT/'docs/status_motion_followup'

def save_gif(path,frames):
    # Learn one palette from every frame of BOTH variants.
    small=(min(320,frames[0].width),round(frames[0].height*min(320,frames[0].width)/frames[0].width))
    sample=Image.new('RGB',(small[0]*8,small[1]*math.ceil(len(frames)/8)))
    for i,frame in enumerate(frames):sample.paste(frame.resize(small,Image.Resampling.NEAREST),(i%8*small[0],i//8*small[1]))
    palette=sample.quantize(colors=256,method=Image.Quantize.MEDIANCUT,dither=Image.Dither.NONE)
    indexed=[im.quantize(palette=palette,dither=Image.Dither.NONE) for im in frames]
    indexed[0].save(path,save_all=True,append_images=indexed[1:],duration=[30 if i%3<2 else 40 for i in range(len(frames))],loop=0,disposal=2)

def main():
    rows=json.loads((OUT/'native/checks.json').read_text());data={};meta={}
    for case in dict.fromkeys(r['case'] for r in rows):
        pair={r['variant']:r for r in rows if r['case']==case}
        if len(pair)!=2:continue
        # JSON round trips of tiny residual timers can differ by <1e-18 s.
        assert len(pair['current']['trace'])==len(pair['sample']['trace'])==84
        assert all(math.isclose(x,y,rel_tol=0.0,abs_tol=1e-12) for a,b in zip(pair['current']['trace'],pair['sample']['trace']) for x,y in zip(a,b))
        assert pair['current']['events']==pair['sample']['events']
        cx,cy=pair['current']['centers'][0];box=(round(cx-48),round(cy-50),round(cx+48),round(cy+46));data[case]={};meta[case]=pair
        for variant in pair:
            data[case][variant]=[Image.open(OUT/f'native/{case}/{variant}/{i:03d}.png').convert('RGB').crop(box) for i in range(84)]
        frames=[]
        for i in range(84):
            b=Image.new('RGB',(384,334),(28,33,30));d=ImageDraw.Draw(b)
            for col,v in enumerate(['current','sample']):
                d.text((col*192+4,5),'GAME CURRENT' if v=='current' else 'NEW STUDY',fill=(238,233,218))
                c=data[case][v][i];b.paste(c,(col*192+48,23));b.paste(c.resize((192,192),Image.Resampling.NEAREST),(col*192,142))
            frames.append(b)
        save_gif(OUT/(case+'-comparison.gif'),frames)
    groups={
        'sleep-and-wake':['sleep_charmander','sleep_charizard','sleep_pikachu','sleep_onix'],
        'blocked-and-selfhit':['paralysis_block','confusion_self_hit'],
        'status-clears':['cure_poison','cure_burn','cure_paralyze','cure_sleep','cure_confuse']}
    for group,cases in groups.items():
        cases=[c for c in cases if c in data]
        if not cases:continue
        for scale in [1,2]:
            width=96*scale;rowh=96*scale+23;frames=[]
            for i in range(84):
                b=Image.new('RGB',(len(cases)*width,rowh*2),(28,33,30));d=ImageDraw.Draw(b)
                for col,c in enumerate(cases):
                    label=meta[c]['sample']['species'].upper() if group=='sleep-and-wake' else c.removeprefix('cure_').replace('paralysis_','PARA ').replace('confusion_','CONF ')
                    for row,v in enumerate(['current','sample']):
                        d.text((col*width+3,row*rowh+3),label,fill=(238,233,218))
                        d.text((col*width+3,row*rowh+13),'CURRENT' if v=='current' else 'NEW',fill=(238,233,218))
                        b.paste(data[c][v][i].resize((width,width),Image.Resampling.NEAREST),(col*width,row*rowh+23))
                frames.append(b)
            save_gif(OUT/(group+('-native' if scale==1 else '')+'.gif'),frames)
            if scale==2:
                contact=Image.new('RGB',(frames[0].width,frames[0].height*3))
                for j,i in enumerate([20,31,54]):contact.paste(frames[i],(0,j*frames[0].height))
                contact.save(OUT/(group+'-contact.png'))
    for f in OUT.glob('*comparison.gif'):
        with Image.open(f) as im:assert sum(fr.info.get('duration',0) for fr in ImageSequence.Iterator(im))==2800
    print('Packaged',len(data),'native before/after pairs; 2800 ms, all cases same gameplay timing')

if __name__=='__main__':main()
