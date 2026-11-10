"""Pack actual GPU captures, preserving their 30/30/40 ms timing."""
from pathlib import Path
import json
from PIL import Image, ImageDraw
from package_ember_hit_variants import gif

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/blink_status_review/sv'
LABELS={'scratch':'SCRATCH','ember':'EMBER','poison':'POISON','burn':'BURN','paralyze':'PARALYSIS','sleep':'SLEEP','confuse':'CONFUSION'}

def main():
    rows=json.loads((OUT/'native/checks.json').read_text())
    data={}
    for case in LABELS:
        pair={r['variant']:r for r in rows if r['case']==case}
        if len(pair)!=2:continue
        a,b=pair['current'],pair['sample']
        assert a['trace']==b['trace'] and a['event_frame']==b['event_frame']
        data[case]={}
        # One fixed frame-0 crop per case for both variants: don't recenter on flicker.
        cx,cy=a['centers'][0]
        bounds=(round(cx-48),round(cy-54),round(cx+48),round(cy+42))
        for variant in pair:
            captures=[]
            for i in range(84):
                with Image.open(OUT/f'native/{case}/{variant}/{i:03d}.png') as im:
                    captures.append(im.convert('RGB').crop(bounds))
            data[case][variant]=captures
    groups={'hit-comparison':['scratch','ember'],'status-comparison':['poison','burn','paralyze','sleep','confuse']}
    durations=[30 if i%3<2 else 40 for i in range(84)]
    for name,cases in groups.items():
        cases=[c for c in cases if c in data]
        if not cases:continue
        frames=[];small=[]
        for i in range(84):
            board=Image.new('RGB',(192*len(cases),430),(28,33,30))
            native=Image.new('RGB',(96*len(cases),238),(28,33,30))
            d=ImageDraw.Draw(board);nd=ImageDraw.Draw(native)
            for col,case in enumerate(cases):
                for row,variant in enumerate(['current','sample']):
                    label=LABELS[case]+' / '+('CURRENT' if row==0 else 'REFERENCE')
                    d.text((col*192+4,row*215+6),label,fill=(238,233,218))
                    nd.text((col*96+2,row*119+3),LABELS[case],fill=(238,233,218))
                    nd.text((col*96+2,row*119+14),'CURRENT' if row==0 else 'REFERENCE',fill=(238,233,218))
                    crop=data[case][variant][i]
                    board.paste(crop.resize((192,192),Image.Resampling.NEAREST),(col*192,row*215+23))
                    native.paste(crop,(col*96,row*119+23))
            frames.append(board);small.append(native)
        gif(OUT/(name+'.gif'),frames,durations)
        gif(OUT/(name+'-native.gif'),small,durations)
        contact=Image.new('RGB',(frames[0].width,frames[0].height*3))
        for n,frame in enumerate([8,13,19]):contact.paste(frames[frame],(0,n*frames[0].height))
        contact.save(OUT/(name+'-contact.png'))
        print(name, cases, '2800 ms', board.size)

if __name__=='__main__':main()
