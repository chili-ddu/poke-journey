"""원본 꽃/관목/울타리/표지판을 분리한다. 내부 색은 유지하고 연결된 배경만 제거한다."""
from collections import Counter
import math
from PIL import Image
from north_terrain import source_cells, remove_cells, cut_background
from city_exteriors import GROUND

FENCES={0xd6,0xd7,0xdf,0xe7,0xec,0xed,0xef,0xf4,0xf5,0xfc,0xfd,0x135}
HEDGES={0x13d,0x13e,0x13f}
SIGNS={2,3,0x168}

def build(d,j,name,metadata):
    city='cerulean_city' if name=='kanto_north' else 'vermilion_city'
    folder='CeruleanCity' if name=='kanto_north' else 'VermilionCity'
    cells=source_cells(j,[folder]);p=j.get('pad',0);w,h=j['width'],j['height']
    raw=Image.open(d/'preview.png').convert('RGBA').crop((p*16,p*16,(p+w)*16,(p+h)*16))
    buildings=metadata['city_exteriors']['buildings']
    owned=set()
    for b in buildings:
        x,y,bw,bh=b['world_rect'];owned.update((xx,yy) for yy in range(y,y+bh) for xx in range(x,x+bw))
    fences=FENCES|({0x285,0x286,0x287,0x288} if city=='cerulean_city' else {0x288,0x289})
    kinds={}
    for xy,mid in cells.items():
        if xy in owned:continue
        kind='fence' if mid in fences else 'flower' if mid==4 else 'shrub' if mid==5 else 'hedge' if mid in HEDGES else 'sign' if mid in SIGNS else 'bicycle' if city=='cerulean_city' and mid==0x2e9 else None
        if kind:kinds[xy]=kind
    # The exact native lawn palette excludes darker colors used inside stems/leaves.
    lawn=set();land=set();donors={};donor_colors={}
    for (x,y),mid in cells.items():
        art=raw.crop((x*16,y*16,(x+1)*16,(y+1)*16))
        if mid in (8,9):lawn.update(art.getdata())
        if mid in GROUND-{0x12b}:
            donors[x,y]=art;donor_colors[x,y]=set(art.getdata());land.update(donor_colors[x,y])
    metal=set()
    for (x,y),kind in kinds.items():
        if kind=='fence':
            metal.update(color for color in raw.crop((x*16,y*16,(x+1)*16,(y+1)*16)).getdata() if max(color[:3])-min(color[:3])<=48)
    floor=Image.open(d/'hd2d_floor.png').convert('RGBA')
    strips=[];card_defs=[];records=[];hedge_used=set();counts=Counter()
    for (x,y),kind in sorted(kinds.items(),key=lambda item:(item[0][1],item[0][0])):
        if (x,y) in hedge_used:continue
        width=1
        if kind=='hedge':
            while kinds.get((x+width,y))=='hedge':width+=1
            hedge_used.update((xx,y) for xx in range(x,x+width))
        art=raw.crop((x*16,y*16,(x+width)*16,(y+1)*16))
        if kind=='fence':
            art.putdata([color if color in metal else (0,0,0,0) for color in art.getdata()])
        else:cut_background(art,lawn)
        id=f'city_{kind}_{x}_{y}'
        if kind=='hedge':
            tex='hd2d_'+id;art.save(d/(tex+'_front.png'))
            metadata['tables'].append(dict(id=id,card=True,x0=x,x1=x+width,z0=y+1,z1=y+1,h=.75,base=0,tex=tex))
        else:
            index=len(strips);strips.append(art)
            card_defs.append((x,y,index,kind))
        counts[kind]+=width
        records.append(dict(id=id,kind=kind,tiles=[[xx,y] for xx in range(x,x+width)],source_mids=[cells[xx,y] for xx in range(x,x+width)]))
        # Reconstruct only obscured pixels. Road/shore boundaries and all untouched pixels survive.
        for xx in range(width):
            bx=x+xx;source=raw.crop((bx*16,y*16,(bx+1)*16,(y+1)*16));part=art.crop((xx*16,0,(xx+1)*16,16))
            background=Counter(source.getpixel((px,py)) for py in range(16) for px in range(16) if part.getpixel((px,py))[3]==0 and source.getpixel((px,py)) in land)
            color=background.most_common(1)[0][0] if background else None
            candidates=[(xy,tile) for xy,tile in donors.items() if color is None or color in donor_colors[xy]]
            if not candidates:candidates=list(donors.items())
            (_,donor)=min(candidates,key=lambda item:abs(item[0][0]-bx)+abs(item[0][1]-y))
            clean=source.copy()
            for py in range(16):
                row=[px for px in range(16) if part.getpixel((px,py))[3]==0 and source.getpixel((px,py)) in land]
                for px in range(16):
                    if part.getpixel((px,py))[3]==0:continue
                    value=source.getpixel((min(row,key=lambda nx:abs(nx-px)),py)) if row else donor.getpixel((px,py))
                    clean.putpixel((px,py),value)
            floor.paste(clean,((bx+p)*16,(y+p)*16))
    selected=set(kinds)
    metadata['cards']=remove_cells(metadata['cards'],selected)
    metadata['props']=[obj for obj in metadata['props'] if (int((obj['x0']+obj['x1'])*.5),int(math.ceil(obj['z']))-1) not in selected]
    old=Image.open(d/'hd2d_atlas.png').convert('RGBA');cols=old.width//16
    atlas=Image.new('RGBA',(old.width,old.height+((len(strips)+cols-1)//cols)*16));atlas.paste(old,(0,0))
    for i,art in enumerate(strips):atlas.paste(art,((i%cols)*16,old.height+(i//cols)*16))
    atlas.save(d/'hd2d_atlas.png')
    for x,y,i,kind in card_defs:
        # Tag 4 activates the existing rooted, layered flower renderer.
        flower=kind=='flower';height=.75 if kind=='shrub' else .875 if kind=='bicycle' else 1.0
        metadata['cards'].append([x,y,1,(i%cols)*16,old.height+(i//cols)*16,0,height,50 if flower else 0,0,4 if flower else 5])
    floor.save(d/'hd2d_floor.png')
    metadata['city_outdoor_props']=dict(city=city,objects=records,source_tile_counts=dict(counts),floor_repair='same-row source background; nearest matching native ground if fully occluded')
    return metadata
