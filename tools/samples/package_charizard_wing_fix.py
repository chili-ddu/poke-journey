from pathlib import Path
from PIL import Image,ImageDraw
import json

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charizard_wing_review'
OLD=ROOT/'docs/charmeleon_charizard_skill_review/charizard'


def main():
    (OUT/'frames').mkdir(exist_ok=True)
    checks=[];clips={};timings=json.loads((OLD/'timing.json').read_text())
    for action,ticks in [('idle',[15,15,15,15]),('walk',[8,10,8,10])]:
        id='charizard-wing-fix-'+action;folder=OUT/f'pixelfx/local-review/{id}'
        d=json.loads((folder/f'{id}.json').read_text());sheet=Image.open(folder/f'{id}.png').convert('RGBA')
        panels=[];full=[];start=0
        for k,tick in enumerate(ticks):
            index=start+tick//2;start+=tick;r=d['frames'][index]['frame']
            fixed=sheet.crop((r['x']+16,r['y']+16,r['x']+96,r['y']+112))
            raw=Image.open(OLD/f'frames/source-{action}-{k}.png').convert('RGBA')
            before=Image.open(OLD/f'frames/edited-{action}-{k}.png').convert('RGBA')
            changes=[(x,y) for y in range(96) for x in range(80) if before.getpixel((x,y))!=fixed.getpixel((x,y))]
            for xy in changes:
                assert raw.getpixel(xy)==(55,63,143,255)
                assert before.getpixel(xy)==(55,63,143,255)
                assert fixed.getpixel(xy)==(67,85,116,255)
            assert before.getchannel('A').tobytes()==fixed.getchannel('A').tobytes()
            assert all(fixed.getpixel((x,y))==(67,85,116,255)
                       for y in range(96) for x in range(80) if raw.getpixel((x,y))==(55,63,143,255))
            fixed.save(OUT/f'frames/{action}-{k}.png')
            checks.append(dict(action=action,key=k,changed_pixels=len(changes),coordinates=changes,
                               all_membrane_pixels_consistent=True,alpha_changes=0))
            board=Image.new('RGB',(480,228),(46,56,51));d0=ImageDraw.Draw(board)
            body=Image.new('RGB',(576,260),(46,56,51));d1=ImageDraw.Draw(body)
            for i,(label,im) in enumerate([('RAW ORIGINAL',raw),('BEFORE WING FIX',before),('WING COLOR FIXED',fixed)]):
                d0.text((i*160+6,10),label,fill=(238,233,218));d1.text((i*192+6,10),label,fill=(238,233,218))
                crop=im.crop((20,12,48,58)).resize((112,184),Image.Resampling.NEAREST)
                board.paste(crop,(i*160+24,32),crop)
                large=im.resize((160,192),Image.Resampling.NEAREST);body.paste(large,(i*192+16,32),large)
            panels.append(board);full.append(body)
        panels[0].save(OUT/f'{action}-wing-comparison.gif',save_all=True,append_images=panels[1:],
                       duration=timings[action],loop=0,disposal=2)
        full[0].save(OUT/f'{action}-full-comparison.gif',save_all=True,append_images=full[1:],
                     duration=timings[action],loop=0,disposal=2)
        strip=Image.new('RGB',(480,228*4))
        for k,im in enumerate(panels):strip.paste(im,(0,k*228))
        strip.save(OUT/f'{action}-wing-poses.png');clips[action]=panels
    (OUT/'checks.json').write_text(json.dumps(dict(checks=checks,production_changes=False,
        new_motion=False,geometry_changes=False),indent=2))
    print(json.dumps(checks))


if __name__=='__main__':main()
