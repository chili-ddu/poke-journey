"""Explicit source bounds for home appliances and wall-mounted decorations."""
from collections import deque

def definitions(name):
    result = []
    def add(label, box, wall=False, donor=136):
        x0, top, x1, bottom = box
        result.append(dict(kind='card' if wall else 'box', object_id=label,
            x0=x0, x1=x1, top=top, bottom=bottom, front=top+2,
            z0=2.0, z1=2.025 if wall else 2.4, base=0.9 if wall else 0.0,
            rect=True, source_mask=True, depth=0.4, floor_y=32, wall_x=donor,
            wall_rows=[top,32], shadow=0))
    if name in ['players_house_1f','rivals_house','pewter_house1','pewter_house2']:
        dx = 16 if name == 'players_house_1f' else 0
        donor = 152 if dx else 136
        add('sink', [dx,18,32+dx,40], donor=donor)
        result[-1].update(front=32, depth=0.75, z1=2.75, remove_faucet=True)
        add('faucet', [7+dx,16,15+dx,24], donor=donor)
        result[-1].update(kind='card', base=0.5, z1=2.16, z0=2.16)
        add('cabinet', [33+dx,12,56+dx,40], donor=donor)
        result[-1].update(erase_right=True)
        add('cylinder', [56+dx,25,64+dx,40], donor=donor)
        result[-1].update(kind='card', base=0.0, z1=2.75, z0=2.75)
        add('tv', [80+dx,13,96+dx,40], donor=donor)
        add('window', [104+dx,9,128+dx,23], True, donor)
        if name == 'rivals_house':
            add('picture',[145,9,159,23],True)
            add('bookshelf',[177,11,208,40])
        elif name.startswith('pewter'):
            add('map',[148,12,171,24],True)
    elif name == 'players_house_2f':
        add('bookshelf',[65,11,96,40],donor=128)
        add('calendar',[176,12,192,24],True,128)
    if name in ['players_house_1f','rivals_house','pewter_house1','pewter_house2']:
        for spec in result:
            spec['floor_sample'] = [9 if name == 'players_house_1f' else 8, 2]
    return result

def cutout(art, spec, padding):
    """Remove only edge-connected pixels matching intact same-row wallpaper."""
    x0,y0,x1,y1 = (spec[k] for k in ['x0','top','x1','bottom'])
    im=art.crop((padding+x0,padding+y0,padding+x1,padding+y1))
    candidates=set()
    for y in range(im.height):
        color=art.getpixel((padding+spec['wall_x'],padding+y0+y))
        for x in range(im.width):
            if y0+y >= 32 and spec.get('floor_sample'):
                fx,fy=spec['floor_sample']
                color=art.getpixel((padding+fx*16+(x0+x)%16,padding+fy*16+(y0+y)%16))
            if im.getpixel((x,y))==color:
                candidates.add((x,y))
    q=deque(p for p in candidates if p[0] in [0,im.width-1] or p[1] in [0,im.height-1]); seen=set(q)
    while q:
        x,y=q.popleft();im.putpixel((x,y),(0,0,0,0))
        for p in [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]:
            if p in candidates and p not in seen:seen.add(p);q.append(p)
    if spec.get('chair_side'):
        # Hand-reviewed chair silhouette; exclude carpet dots and baked exterior shadow.
        for y in range(im.height):
            for x in range(im.width):
                xx = x if spec['chair_side']=='left' else 15-x
                keep = xx < 4 if y < 4 else (xx < 12 if y < 14 else (1 <= xx < 4 or 9 <= xx < 12))
                if not keep:
                    im.putpixel((x,y),(0,0,0,0))
    if spec.get('remove_faucet'):
        # Reconstruct only the eight-column faucet overlap on the sink surface.
        # Same-row intact bowl/counter pixels are inferred, not recovered original art.
        for y in range(18,24):
            for x in range(7,15):
                im.putpixel((x,y-y0), art.getpixel((padding+x0+16,padding+y)))
    return im
