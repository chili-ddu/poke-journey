"""Package actual pixelfx-exported frames; do not repaint their pixels."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charmander_skill_restart'


def main():
    durations={'idle':[400,270,260,270],'walk':[100,130,100,140]}
    sample_indices={'idle':[12,32,48,64],'walk':[3,10,17,24]}
    (OUT/'frames').mkdir(exist_ok=True)
    clips={};checks=[]
    for action in ['idle','walk']:
        name='charmander-source-r3'+('-walk' if action=='walk' else '')
        folder=OUT/f'round3/local-review/{name}'
        meta=json.loads((folder/f'{name}.json').read_text());sheet=Image.open(folder/f'{name}.png').convert('RGBA')
        panels=[]
        for key,index in enumerate(sample_indices[action]):
            rect=meta['frames'][index]['frame']
            cell=sheet.crop((rect['x'],rect['y'],rect['x']+96,rect['y']+96))
            edited=cell.crop((16,22,80,102))
            source=Image.open(OUT/f'source/{action}-{key}.png').convert('RGBA')
            raw=source.resize((64,80),Image.Resampling.NEAREST)
            assert raw.getchannel('A').tobytes()==edited.getchannel('A').tobytes()
            # White/blue eyes, tail/flame side and internal dark pixel masks
            # are compared against RAW source, not any old sample palette.
            for y in range(40):
                for x in range(32):
                    c=source.getpixel((x,y))
                    if not c[3]:continue
                    if x<12 or c[:3] in [(255,255,255),(79,95,151),(103,135,175),(191,207,247),(255,247,0)]:
                        assert edited.crop((x*2,y*2,x*2+2,y*2+2)).tobytes()==raw.crop((x*2,y*2,x*2+2,y*2+2)).tobytes()
            raw.save(OUT/f'frames/source-{action}-{key}.png')
            edited.save(OUT/f'frames/edited-{action}-{key}.png')
            changed=sum(a!=b for a,b in zip(raw.get_flattened_data(),edited.get_flattened_data()))
            checks.append(dict(action=action,key=key,sheet_frame_index=index,changed_pixels=changed,alpha_changes=0))
            board=Image.new('RGB',(512,440),(46,56,51));d=ImageDraw.Draw(board)
            for side,(label,im) in enumerate([('RAW ORIGINAL',raw),('FRESH PIXELFX STUDY',edited)]):
                d.text((side*256+8,10),label,fill=(238,233,218))
                large=im.resize((256,320),Image.Resampling.NEAREST)
                board.paste(large,(side*256,38),large)
                board.paste(im,(side*256+140,356),im)
                tiny=im.resize((32,40),Image.Resampling.NEAREST)
                board.paste(tiny,(side*256+50,392),tiny)
            d.text((8,360),f'{action.upper()} {key+1}',fill=(200,207,199))
            panels.append(board)
        clips[action]=panels
        panels[0].save(OUT/f'{action}-comparison.gif',save_all=True,append_images=panels[1:],duration=durations[action],loop=0,disposal=2)
        contact=Image.new('RGB',(512,440*4))
        for i,im in enumerate(panels):contact.paste(im,(0,i*440))
        contact.save(OUT/f'{action}-pose-review.png')
    combined=[];times=[]
    for action in ['idle','walk']:
        for repeat in range(3):combined.extend(clips[action]);times.extend(durations[action])
    combined[0].save(OUT/'motion-comparison.gif',save_all=True,append_images=combined[1:],duration=times,loop=0,disposal=2)
    data=json.loads((OUT/'source-provenance.json').read_text())
    for path,sha in data['inputs'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha
    (OUT/'pixel-checks.json').write_text(json.dumps(dict(checks=checks,
        source_hashes_unchanged=True,eye_tail_flame_alpha_preserved=True,
        production_changes=False),indent=2))
    print(json.dumps(checks))


if __name__=='__main__':main()
