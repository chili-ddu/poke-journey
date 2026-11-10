"""Saffron's secondary tileset: native paving, independent signs and bent rails."""
from collections import Counter
from PIL import Image
from north_terrain import source_cells, remove_cells, cut_background
from city_exteriors import SAFFRON_GROUND, SAFFRON_BACKGROUND

FENCES={0x30d,0x318,0x319,0x31a,0x31c,0x31d,0x31e,0x320,0x322,0x323,
        0x325,0x326,0x328,0x329,0x32a,0x32d,0x32e,0x344,0x345,0x346,0x347}
TURNED={0x318,0x31a,0x320,0x322,0x325,0x326,0x328,0x32a,0x32d,0x32e,
        0x344,0x345,0x346,0x347}


def build(d,j,metadata):
    p=j.get('pad',0);w,h=j['width'],j['height']
    raw=Image.open(d/'preview.png').convert('RGBA').crop((p*16,p*16,(p+w)*16,(p+h)*16))
    cells=source_cells(j,['SaffronCity'])
    ground={xy for xy,mid in cells.items() if mid in SAFFRON_GROUND}
    palette=set();donors={}
    for x,y in ground:
        art=raw.crop((x*16,y*16,(x+1)*16,(y+1)*16))
        donors[x,y]=art
        # Rear-door steps include building-outline gray. They are flat ground,
        # but their colors must not punch holes in signs and portal pillars.
        if cells[x,y] in SAFFRON_BACKGROUND:palette.update(art.getdata())
    # Flood masks alone cannot remove enclosed paving between metal rails.
    def clean(art):
        art.putdata([c if c not in palette else (0,0,0,0) for c in art.getdata()])
        return art
    rail_xy=next(xy for xy,mid in cells.items() if mid==0x319)
    rx,ry=rail_xy
    rail=clean(raw.crop((rx*16,ry*16,(rx+1)*16,(ry+1)*16)))
    strips=[];cards=[];records=[];selected=set()
    floor=Image.open(d/'hd2d_floor.png').convert('RGBA')
    for (x,y),mid in cells.items():
        if mid not in FENCES:continue
        art=rail.copy() if mid in TURNED else clean(raw.crop((x*16,y*16,(x+1)*16,(y+1)*16)))
        i=len(strips);strips.append(art);cards.append((x,y,1,i,mid))
        selected.add((x,y));records.append(dict(kind='fence',tile=[x,y],mid=mid,turned=mid in TURNED))
    signs=[]
    for (x,y),mid in cells.items():
        if mid not in {2,3,0x33c,0x304,0x327}:continue
        n=2 if mid in {0x304,0x327} else 1
        art=cut_background(raw.crop((x*16,y*16,(x+1)*16,(y+n)*16)),palette)
        tex=f'hd2d_saffron_sign_{x}_{y}';art.save(d/(tex+'_front.png'))
        metadata['tables'].append(dict(id=f'saffron_sign_{x}_{y}',card=True,x0=x,x1=x+1,
                                      z0=y+n,z1=y+n,h=n,base=0,tex=tex))
        selected.update((x,y+dy) for dy in range(n))
        signs.append(dict(tile=[x,y],rows=n,mid=mid))
    # Restore source paving at every untouched road tile, including solid but
    # visually flat margins. A collision bit must never erase a road pattern.
    buildings=[c for c in metadata['cards'] if len(c)>9 and c[9]==3]
    rest=[c for c in metadata['cards'] if not(len(c)>9 and c[9]==3)]
    metadata['cards']=buildings+remove_cells(rest,ground|selected)
    metadata['props']=[]  # Generic two-tile mailboxes were actually cliff/gate fragments.
    for x,y in ground:floor.paste(donors[x,y],((x+p)*16,(y+p)*16))
    for x,y in selected:
        source=raw.crop((x*16,y*16,(x+1)*16,(y+1)*16))
        bg=Counter(c for c in source.getdata() if c in palette)
        color=bg.most_common(1)[0][0] if bg else None
        candidates=[xy for xy,art in donors.items() if color is None or color in art.getdata()]
        if not candidates:candidates=list(donors)
        a,b=min(candidates,key=lambda xy:abs(xy[0]-x)+abs(xy[1]-y))
        donor=donors[a,b];result=source.copy()
        for yy in range(16):
            row=[xx for xx in range(16) if source.getpixel((xx,yy)) in palette]
            for xx in range(16):
                if source.getpixel((xx,yy)) in palette:continue
                value=source.getpixel((min(row,key=lambda nx:abs(nx-xx)),yy)) if row else donor.getpixel((xx,yy))
                result.putpixel((xx,yy),value)
        floor.paste(result,((x+p)*16,(y+p)*16))
    floor.save(d/'hd2d_floor.png')
    old=Image.open(d/'hd2d_atlas.png').convert('RGBA');cols=old.width//16
    atlas=Image.new('RGBA',(old.width,old.height+((len(strips)+cols-1)//cols)*16));atlas.paste(old,(0,0))
    for i,art in enumerate(strips):atlas.paste(art,((i%cols)*16,old.height+(i//cols)*16))
    atlas.save(d/'hd2d_atlas.png')
    metadata['cards'] += [[x,y,n,(i%cols)*16,old.height+(i//cols)*16,0,1,0,0,5,mid] for x,y,n,i,mid in cards]
    metadata['saffron_outdoors']=dict(fences=records,signs=signs,ground_tiles=[list(xy) for xy in sorted(ground)],
                                     rail_source=list(rail_xy),source='pret/pokefirered SaffronCity')
    return metadata
