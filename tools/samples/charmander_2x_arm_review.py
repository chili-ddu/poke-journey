"""Isolated revision: preserve the arm/torso contact shading in all poses."""
from pathlib import Path
import json
from PIL import Image,ImageDraw
import charmander_2x_motion as previous

OUT=previous.ROOT/'docs/charmander_2x_arm_review'
OLD=previous.ROOT/'docs/charmander_2x_motion'
original_refine=previous.refine
# Conservative union of arm/hand and contact-shading positions across keys.
ARM=(12,11,21,24)


def refine(im):
    result,qa=original_refine(im)
    nearest=im.resize((64,80),Image.Resampling.NEAREST)
    region=tuple(c*2 for c in ARM)
    result.paste(nearest.crop(region),region[:2])
    assert result.crop(region).tobytes()==nearest.crop(region).tobytes()
    coords=[(x,y) for y in range(80) for x in range(64)
            if result.getpixel((x,y))!=nearest.getpixel((x,y))]
    qa.update(changed_pixels=len(coords),coordinates=coords,protected_arm=ARM,
              original_arm_contact_shading_preserved=True)
    return result,qa


def main():
    previous.OUT=OUT
    previous.refine=refine
    previous.main()
    audit=[]
    for action in ['idle','walk']:
        panels=[]
        for key in range(4):
            source=Image.open(previous.SOURCE/f'{action}-{key}.png').convert('RGBA')
            native=source.resize((64,80),Image.Resampling.NEAREST)
            before=Image.open(OLD/f'{action}-{key}-64x80.png').convert('RGBA')
            after=Image.open(OUT/f'{action}-{key}-64x80.png').convert('RGBA')
            region=tuple(c*2 for c in ARM)
            restored=sum(a!=b for a,b in zip(before.crop(region).get_flattened_data(),
                                            after.crop(region).get_flattened_data()))
            assert after.crop(region).tobytes()==native.crop(region).tobytes()
            audit.append(dict(action=action,key=key,restored_arm_pixels=restored))
            board=Image.new('RGB',(576,240),(46,56,51));d=ImageDraw.Draw(board)
            for i,(label,im) in enumerate([('SOURCE ARM',native),('PREVIOUS EDIT',before),('ARM RESTORED',after)]):
                d.text((i*192+8,10),label,fill=(238,233,218))
                crop=im.crop((20,20,46,50)).resize((156,180),Image.Resampling.NEAREST)
                board.paste(crop,(i*192+18,32),crop)
            d.text((8,221),f'{action.upper()} / pose {key+1}',fill=(200,207,199))
            panels.append(board)
        durations=([400,270,260,270] if action=='idle' else [100,130,100,140])
        panels[0].save(OUT/f'{action}-arm-detail.gif',save_all=True,append_images=panels[1:],
                       duration=durations,loop=0,disposal=2)
        strip=Image.new('RGB',(576,240*4))
        for i,panel in enumerate(panels):strip.paste(panel,(0,i*240))
        strip.save(OUT/f'{action}-arm-poses.png')
    (OUT/'arm-audit.json').write_text(json.dumps(dict(production_changes=False,
        protected_source_region=ARM,frames=audit),indent=2))
    with (OUT/'README.md').open('a') as f:
        f.write('\n## Arm review correction\nThe previous generic color-corner rule split small dark clusters inside the arm/contact shading, making the bend look angular in motion. This revision protects source region (12,11)-(21,24), the conservative union of arm/hand and adjacent torso shading across all eight keys. It restores those pixels to exact nearest-2x source copies; it does not invent a new arm pose or alter timing. Other permitted corner edits remain. arm-audit.json lists restored pixel counts. Arm detail GIFs compare source / previous edit / restored arm at matched timing. Source-region byte equality verified for every key. Visual consistency beyond these supplied side-view keys remains unreviewed.\n')
    print(json.dumps(audit))


if __name__=='__main__':
    main()
