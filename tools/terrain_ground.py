"""Native ground beneath standing trees and reconstructed outdoor jump banks."""
from collections import Counter


def pixels(image):
    return image.get_flattened_data() if hasattr(image, 'get_flattened_data') else image.getdata()


def green(color):
    r, g, b, a = color
    return a == 255 and g-r >= 16 and g-b >= 8


def path_color(color):
    r, g, b, a = color
    return a == 255 and r > 160 and g > 140 and r >= g and b < g*.8


def surface_palette(images):
    """Only clean native lawn/path tiles can supply ground colors, never a prop."""
    result = set()
    for image in images:
        colors = Counter(pixels(image))
        color, n = colors.most_common(1)[0]
        if n >= .8*256 and all(green(c) or path_color(c) for c in colors):
            result.update(colors)
    return result


def tile(image, xy, pad):
    x, y = xy
    return image.crop(((x+pad)*16, (y+pad)*16, (x+pad+1)*16, (y+pad+1)*16))


def restore_tree_floor(j, raw, floor, cells, donors, ground_palette):
    """Blocked trunks grow on lawn; walkable canopy overhangs retain native paths."""
    w, h, pad = j['width'], j['height'], j.get('pad', 0)
    grass_palette = set().union(*(set(pixels(im)) for im in donors.values()))
    by_area = {a['id']: [xy for xy in donors if a['x'] <= xy[0] < a['x']+a['w'] and a['y'] <= xy[1] < a['y']+a['h']] for a in j.get('areas', [])}
    changes = []
    for x, y in sorted(cells):
        if not (0 <= x < w and 0 <= y < h) or j.get('ledge', ['0'*w]*h)[y][x] != '0':
            continue
        old = tile(floor, (x,y), pad)
        if j['solid'][y][x] == '1':
            if set(pixels(old)) <= grass_palette:
                continue
            area = next((a for a in j.get('areas', []) if a['x'] <= x < a['x']+a['w'] and a['y'] <= y < a['y']+a['h']), None)
            choices = (by_area.get(area['id']) if area else None) or donors
            donor = min(choices, key=lambda xy: ((xy[0]-x)**2+(xy[1]-y)**2, xy))
            replacement = donors[donor]
            reason = 'lawn beneath solid native tree'
        elif j['grass'][y][x] == '0':
            # The tree's upper layer can overhang a real road. Restore that
            # actual bottom tile instead of extending lawn into the road.
            replacement = tile(raw, (x,y), pad)
            if not set(pixels(replacement)) <= ground_palette:
                continue
            reason = 'native walkable ground beneath canopy'
        else:
            continue
        if replacement.tobytes() != old.tobytes():
            floor.paste(replacement, ((x+pad)*16,(y+pad)*16))
            changes.append({'tile': [x,y], 'reason': reason})
    return changes


def restore_bank_floor(j, raw, floor, cells, ground_palette, fallback):
    """Keep each bank's original grass/path pixels, removing only old face art."""
    pad = j.get('pad',0)
    for xy in sorted(cells):
        original = tile(raw, xy, pad)
        clean = original.copy()
        ground = [(x,y) for y in range(16) for x in range(16) if original.getpixel((x,y)) in ground_palette]
        for y in range(16):
            for x in range(16):
                if original.getpixel((x,y)) in ground_palette:
                    continue
                column = [(a,b) for a,b in ground if a == x]
                choices = column or ground
                color = original.getpixel(min(choices, key=lambda p: ((p[0]-x)**2+(p[1]-y)**2,p))) if choices else fallback.getpixel((x,y))
                clean.putpixel((x,y), color)
        floor.paste(clean, ((xy[0]+pad)*16,(xy[1]+pad)*16))
