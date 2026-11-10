"""Slice actual pixelfx exports and make synchronized paired GIFs."""
from pathlib import Path
from PIL import Image,ImageDraw
import json,hashlib

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charmeleon_charizard_skill_review'


def main():
    allchecks=[]
    for name in ['charmeleon','charizard']:
        dest=OUT/name;spec=json.loads((dest/'source-provenance.json').read_text())
        W=spec['width'];H=spec['height'];(dest/'frames').mkdir(exist_ok=True)
        clips={};timing={}
        for action,ticks in spec['actions'].items():
            id=f'{name}-fresh-r3-{action}-edited';folder=OUT/f'round3/local-review/{id}'
            meta=json.loads((folder/f'{id}.json').read_text());sheet=Image.open(folder/f'{id}.png').convert('RGBA')
            start=0;panels=[];durations=[];acc=0;prev=0
            for key,tick in enumerate(ticks):
                index=start+tick//2;start+=tick
                f=meta['frames'][index]['frame'];cell=sheet.crop((f['x'],f['y'],f['x']+f['w'],f['y']+f['h']))
                edited=cell.crop((16,16,16+W*2,16+H*2))
                source=Image.open(dest/f'source/{action}-{key}.png').convert('RGBA')
                raw=source.resize((W*2,H*2),Image.Resampling.NEAREST)
                assert raw.getchannel('A').tobytes()==edited.getchannel('A').tobytes()
                for y in range(H):
                    for x in range(W):
                        c=source.getpixel((x,y))
                        if c in [(255,255,255,255),(191,207,247,255),(0,103,183,255),(255,247,0,255)]:
                            rect=(x*2,y*2,x*2+2,y*2+2)
                            assert edited.crop(rect).tobytes()==raw.crop(rect).tobytes()
                for variant,im in [('source',raw),('edited',edited)]:im.save(dest/f'frames/{variant}-{action}-{key}.png')
                finer=sum(len(set(edited.crop((x,y,x+2,y+2)).get_flattened_data()))>1
                          for y in range(0,H*2,2) for x in range(0,W*2,2))
                allchecks.append(dict(species=name,action=action,key=key,source_ticks=tick,
                    edited_pixels=sum(a!=b for a,b in zip(raw.get_flattened_data(),edited.get_flattened_data())),
                    finer_2x2_blocks=finer,alpha_changes=0))
                board=Image.new('RGB',(512,424),(46,56,51));d=ImageDraw.Draw(board)
                for side,(label,im) in enumerate([('RAW ORIGINAL',raw),('FRESH PIXELFX STUDY',edited)]):
                    d.text((side*256+8,12),label,fill=(238,233,218))
                    large=im.resize((W*4,H*4),Image.Resampling.NEAREST)
                    board.paste(large,(side*256+(256-large.width)//2,40),large)
                    board.paste(im,(side*256+144,286),im)
                    small=im.resize((W,H),Image.Resampling.NEAREST)
                    board.paste(small,(side*256+50,320),small)
                d.text((8,267),f'{name.upper()} / {action.upper()} / {key+1}',fill=(200,207,199))
                panels.append(board)
                acc+=tick;ms=round(acc*1000/60/10)*10;durations.append(ms-prev);prev=ms
            clips[action]=panels;timing[action]=durations
            panels[0].save(dest/f'{action}-comparison.gif',save_all=True,append_images=panels[1:],duration=durations,loop=0,disposal=2)
            contact=Image.new('RGB',(512,424*len(panels)))
            for i,im in enumerate(panels):contact.paste(im,(0,424*i))
            contact.save(dest/f'{action}-pose-review.png')
            gif=Image.open(dest/f'{action}-comparison.gif');assert gif.n_frames==len(panels)
            observed=[]
            for i in range(gif.n_frames):gif.seek(i);observed.append(gif.info['duration'])
            assert observed==durations
        combined=[];dur=[]
        for action in ['idle','walk']:
            for repeat in range(3):combined.extend(clips[action]);dur.extend(timing[action])
        combined[0].save(dest/'motion-comparison.gif',save_all=True,append_images=combined[1:],duration=dur,loop=0,disposal=2)
        for path,sha in spec['hashes'].items():assert hashlib.sha256((ROOT/path).read_bytes()).hexdigest()==sha
        (dest/'timing.json').write_text(json.dumps(timing,indent=2))
    (OUT/'pixel-checks.json').write_text(json.dumps(dict(checks=allchecks,source_hashes_unchanged=True,
        white_blue_eye_colors_flame_marker_alpha_preserved=True,production_changes=False),indent=2))
    print(f'{len(allchecks)} original/edited key pairs: alpha, eye colors, flame markers, input hashes and GIF timings checked')


if __name__=='__main__':main()
