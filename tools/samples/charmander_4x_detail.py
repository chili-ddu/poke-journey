"""Refine chosen color-cluster corners within a copied nearest-4x still."""
from pathlib import Path
import json
from PIL import Image, ImageDraw

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'docs/charmander_4x_shading'

# Original 32x40 coordinates. Only these selected interior corners are edited.
CORNERS=[
    (15,7,'BR'),(18,7,'BL'),(14,8,'BR'),(15,8,'TL'),
    (18,8,'TR'),(19,8,'BL'),(21,10,'BL'),(21,11,'TR'),
    (22,11,'BL'),(21,13,'BR'),(22,13,'TL'),(21,14,'TL'),
    (22,14,'TL'),(15,16,'TL'),(15,16,'TR'),(16,16,'BL'),
    (19,16,'TR'),(15,17,'TR'),(16,17,'TL'),(13,18,'BR'),
    (14,18,'TR'),(14,18,'BL'),(13,19,'TR'),(14,19,'TL'),
    (16,19,'BR'),(16,20,'BR'),(17,20,'TL'),(15,21,'BL'),
    (16,21,'BL'),(13,22,'BL'),(15,22,'TR'),(15,22,'BR'),
    (13,23,'TR'),(14,23,'BL'),(15,23,'TL'),(15,24,'TL'),
]


def main():
    base=Image.open(OUT/'shading-subtle-4x.png').convert('RGBA')
    result=base.copy()
    edits=[]
    for x,y,corner in CORNERS:
        right=corner[1]=='R'
        bottom=corner[0]=='B'
        color=base.getpixel((x*4+(4 if right else -1),y*4+2))
        vertical=base.getpixel((x*4+2,y*4+(4 if bottom else -1)))
        assert color==vertical and color[3]==255
        for dx,dy in [(0,0),(1,0),(0,1)]:
            px=x*4+(3-dx if right else dx)
            py=y*4+(3-dy if bottom else dy)
            old=base.getpixel((px,py))
            assert old[3]==255
            result.putpixel((px,py),color)
            edits.append(dict(x=px,y=py,before=old,after=color))
    result.save(OUT/'shading-detailed-4x.png')
    assert base.getchannel('A').tobytes()==result.getchannel('A').tobytes()
    assert base.crop((0,0,48,160)).tobytes()==result.crop((0,0,48,160)).tobytes()
    assert base.crop((56,40,84,64)).tobytes()==result.crop((56,40,84,64)).tobytes()
    assert set(result.get_flattened_data()).issubset(set(base.get_flattened_data()))
    changed=sum(a!=b for a,b in zip(base.get_flattened_data(),result.get_flattened_data()))
    # Keep native-size views separate from the enlarged illustrations.
    board=Image.new('RGB',(576,570),(46,56,51));draw=ImageDraw.Draw(board)
    for i,(label,im) in enumerate([('4x BLOCKS / BEFORE',base),('FINER SHADE BOUNDARIES',result)]):
        draw.text((i*288+10,12),label,fill=(238,233,218))
        big=im.resize((256,320),Image.Resampling.NEAREST)
        board.paste(big,(i*288+16,36),big)
        draw.text((i*288+10,368),'128x160 native; 32x40 at right',fill=(200,207,199))
        board.paste(im,(i*288+32,395),im)
        small=im.resize((32,40),Image.Resampling.NEAREST)
        board.paste(small,(i*288+218,458),small)
    board.save(OUT/'detail-comparison.png')
    mask=Image.new('RGBA',base.size)
    for y in range(160):
        for x in range(128):
            if base.getpixel((x,y))!=result.getpixel((x,y)):
                mask.putpixel((x,y),(255,70,170,255))
    mask.save(OUT/'detail-changed-pixels.png')
    (OUT/'detail-edits.json').write_text(json.dumps(dict(
        art_source='existing',route='explicit interior pixel edits on 4x copy; no image model',
        changed_pixels=changed,selected_corners=CORNERS,patches=edits,
        new_colors=0,alpha_changes=0,eye_unchanged=True,tail_unchanged=True,
        production_changes=False),indent=2))
    with (OUT/'README.md').open('a') as f:
        f.write(f'\n## Finer interior boundaries\nshading-detailed-4x.png uses the enlarged grid: {changed} individual pixels edited at 36 explicitly selected shade-cluster corners. Three-pixel triangles soften each corner with existing neighboring colors. No new colors, blur, image model or global edge filter. Alpha/silhouette, protected eye region and tail/flame side verified identical to the preceding 4x shade copy. This changes internal shading boundaries only. detail-comparison.png shows 2x detail views, native 128x160 and downsampled 32x40 previews. No production integration.\n')
    print(f'{changed} individual 4x-grid pixels changed; original alpha, eye and tail verified unchanged')


if __name__=='__main__':
    main()
