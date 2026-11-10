"""Package actual pixelfx-authored eight-slot outputs without image warping."""
from pathlib import Path
import json
from PIL import Image,ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charizard_clean_wing_retry'


def main():
    checks=[]
    for action,ticks in [('idle',[15]*4),('walk',[8,10,8,10])]:
        folder=OUT/f'pixelfx-refined/local-review/charizard-clean-wing-{action}'
        name='charizard-clean-wing-'+action
        meta=json.loads((folder/f'{name}.json').read_text());sheet=Image.open(folder/f'{name}.png').convert('RGBA')
        (OUT/f'{action}/frames').mkdir(parents=True,exist_ok=True)
        clips=[];timing=[];start=0;ms0=0;tiles=[]
        contact=Image.new('RGB',(1056,672),(46,56,51))
        for i in range(8):
            span=ticks[i//2]/2;index=int(start+span/2);start+=span
            r=meta['frames'][index]['frame'];im=sheet.crop((r['x']+16,r['y']+16,r['x']+96,r['y']+112))
            assert all(c[3] in [0,255] for c in im.get_flattened_data())
            residue=sum(c in [(215,63,0,255),(159,0,0,255)] for c in im.get_flattened_data())
            assert residue==0
            im.save(OUT/f'{action}/frames/{i:03}.png')
            tile=Image.new('RGB',(264,336),(46,56,51));d=ImageDraw.Draw(tile)
            d.text((12,10),f'{i+1:02} '+('SOURCE POSE' if i%2==0 else 'NEW WING MIDDLE'),fill=(238,233,218))
            large=im.resize((240,288),Image.Resampling.NEAREST);tile.paste(large,(12,36),large)
            tile.save(OUT/f'{action}/frame-{i+1:02}.png');tiles.append(tile)
            contact.paste(tile,((i%4)*264,(i//4)*336));clips.append(tile)
            ms=round(start*1000/60/10)*10;timing.append(ms-ms0);ms0=ms
            checks.append(dict(action=action,slot=i+1,source_key_or_authored_mid='source' if i%2==0 else 'authored wing',
                               raw_red_residue=0,binary_alpha=True,warp_used=False))
        contact.save(OUT/f'{action}-eight-poses.png')
        for row in range(2):contact.crop((0,row*336,1056,(row+1)*336)).save(OUT/f'{action}-row-{row+1}.png')
        clips[0].save(OUT/f'{action}-motion.gif',save_all=True,append_images=clips[1:],duration=timing,loop=0,disposal=2)
        (OUT/f'{action}/timing.json').write_text(json.dumps(timing))
    (OUT/'checks.json').write_text(json.dumps(checks,indent=2))
    print('16 rendered slots: no residual raw red, binary alpha; no mesh/optical-flow processing')


if __name__=='__main__':main()
