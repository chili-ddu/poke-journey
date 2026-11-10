"""Read-only source inspection. Writes only docs/source_object_audit; never runtime assets."""
import json, re, hashlib
from pathlib import Path
from PIL import Image, ImageDraw
ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / 'docs/source_object_audit'

def sources():
    text = (ROOT / 'scripts/data/dungeon_db.gd').read_text()
    return sorted(set(re.findall(r'"(\w+)": \{[^\n]*"indoor": true', text)))

def main():
    OUT.mkdir(exist_ok=True)
    inventory = []
    for name in sources():
        d = ROOT / 'assets/maps' / name
        if not (d / 'map.json').exists():
            continue
        j = json.loads((d / 'map.json').read_text())
        w,h,p = j['width'],j['height'],j.get('pad',0)
        bottom = Image.open(d/'bottom.png').convert('RGBA')
        art = bottom.crop((p*16,p*16,(p+w)*16,(p+h)*16))
        art.alpha_composite(Image.open(d/'top.png').convert('RGBA'))
        art = art.resize((w*32,h*32),Image.Resampling.NEAREST)
        sheet=Image.new('RGB',(w*32+40,h*32+40),'#242a33'); sheet.paste(art,(40,40)); draw=ImageDraw.Draw(sheet)
        draw.text((4,4),name,fill='white')
        for x in range(w):
            draw.text((42+x*32,24),str(x),fill='white'); draw.line((40+x*32,40,40+x*32,40+h*32),fill='#636363',width=1)
        for y in range(h):
            draw.text((20,42+y*32),str(y),fill='white'); draw.line((40,40+y*32,40+w*32,40+y*32),fill='#636363',width=1)
        sheet.save(OUT/(name+'.png'))
        inventory.append({'map':name,'size_tiles':[w,h],'tile_pixels':16,'source_origin':'padding excluded, x right/y down, end exclusive',
          'sha256':{f:hashlib.sha256((d/f).read_bytes()).hexdigest() for f in ['bottom.png','top.png','map.json']},
          'warps':j.get('warps',[]),'review':'pending'})
    (OUT/'inventory.json').write_text(json.dumps(inventory,ensure_ascii=False,indent=2))
    print([r['map'] for r in inventory])
if __name__=='__main__': main()
