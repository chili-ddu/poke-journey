"""Extract RAW project sheets only; no previous preview inputs or edits."""
from pathlib import Path
from PIL import Image
import xml.etree.ElementTree as ET
import json,hashlib

ROOT=Path(__file__).resolve().parents[2]
DEST=ROOT/'docs/charmander_skill_restart'
ASSET=ROOT/'assets/sprites/0004'


def main():
    (DEST/'source').mkdir(parents=True,exist_ok=True)
    anims={a.findtext('Name'):a for a in ET.parse(ASSET/'AnimData.xml').findall('./Anims/Anim')}
    actions={};inputs={}
    for action in ['Idle','Walk']:
        meta=anims[action];w=int(meta.findtext('FrameWidth'));h=int(meta.findtext('FrameHeight'))
        ticks=[int(d.text) for d in meta.findall('./Durations/Duration')]
        file=ASSET/f'{action}-Anim.png'
        inputs[str(file.relative_to(ROOT))]=hashlib.sha256(file.read_bytes()).hexdigest()
        sheet=Image.open(file).convert('RGBA');frames=[]
        for k in range(len(ticks)):
            source=sheet.crop((k*w,2*h,(k+1)*w,3*h))
            canvas=Image.new('RGBA',(32,40));canvas.paste(source,((32-w)//2,(40-h)//2))
            canvas.save(DEST/f'source/{action.lower()}-{k}.png')
            colors=list(dict.fromkeys(c for c in canvas.get_flattened_data() if c[3]))
            chars='0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz'
            ids={c:chars[i] for i,c in enumerate(colors)}
            rows=[''.join(ids[canvas.getpixel((x,y))] if canvas.getpixel((x,y))[3] else '.' for x in range(32)) for y in range(40)]
            palette={ids[c]:'#%02x%02x%02x'%c[:3] for c in colors}
            frames.append(dict(rows=rows,palette=palette))
        actions[action.lower()]=dict(ticks=ticks,frames=frames)
    data=dict(actions=actions,inputs=inputs)
    (DEST/'original-data.mjs').write_text('export default '+json.dumps(data)+';\n')
    (DEST/'source-provenance.json').write_text(json.dumps(dict(
        art_source='existing',route='raw project PNG extraction',inputs=inputs,
        previous_preview_inputs=False,source_canvas=[32,40],target_canvas=[64,80],
        actions={a:v['ticks'] for a,v in actions.items()},production_changes=False),indent=2))
    print('Raw Idle/Walk sheets extracted: no previous sample or palette input')


if __name__=='__main__':main()
