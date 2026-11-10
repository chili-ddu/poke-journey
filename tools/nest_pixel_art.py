"""Native FRLG crowns and a small, indexed pixel palette for the nest stage."""
import math
import random
from PIL import Image, ImageDraw
from hd2d_cards import _tree_template

WOOD = ["#46372d", "#654731", "#805a39", "#a07848", "#ba9258", "#d0af72", "#e4cd96", "#f0dfaf"]
CANOPY_NEAR_SCALE = 1.5
CANOPY_FULL_RADIUS = 14.0
CANOPY_NORMAL_RADIUS = 19.0


def canopy_scale(distance):
    t = max(0.0, min(1.0, (distance-CANOPY_FULL_RADIUS)/(CANOPY_NORMAL_RADIUS-CANOPY_FULL_RADIUS)))
    return round(1.0+(CANOPY_NEAR_SCALE-1.0)*(1.0-t*t*(3.0-2.0*t)), 4)


def rgb(hex_color):
    return tuple(bytes.fromhex(hex_color[1:]))


def indexed(image):
    """Eight wood colors, no smooth gradients or anti-aliasing."""
    palette = Image.new("P", (1, 1))
    colors = [c for h in WOOD for c in rgb(h)]
    palette.putpalette(colors + list(rgb(WOOD[0]))*(256-len(WOOD)))
    alpha = image.getchannel("A")
    result = image.convert("RGB").quantize(palette=palette, dither=Image.Dither.NONE).convert("RGBA")
    result.putalpha(alpha)
    return result


def stem(draw, points, width, shade):
    points = [(round(x), round(y)) for x, y in points]
    draw.line(points, fill=WOOD[max(0, shade-2)], width=width+1)
    draw.line(points, fill=WOOD[shade], width=width)
    if width > 1:
        draw.line([(x, y-1) for x, y in points], fill=WOOD[min(7, shade+1)], width=1)


def bowl(extent, radius_at):
    # Native 16px/tile grid, shared with the FRLG crowns. Connected clusters
    # and a fixed palette give pixel art its shape without enlarging every dot.
    center = extent//2
    art = Image.new("RGBA", (extent, extent))
    d = ImageDraw.Draw(art)
    rng = random.Random(117)
    for y in range(-156, 157):
        for x in range(-156, 157):
            r = radius_at(x, y)
            if r > 151:
                continue
            angle = math.atan2(y, x)
            if r < 92:
                shade = 4
            elif r < 126:
                shade = max(2, 4-int((r-92)/13))
                if math.sin(angle) > .4:
                    shade = min(5, shade+1)
            elif r < 137:
                shade = 5 if r < 133 else 4
            else:
                shade = 2 if r > 146 else 3
            art.putpixel((center+x, center+y), (*rgb(WOOD[shade]), 255))
    # Sticks cross the weave, with occasional split ends and broken highlights.
    for _ in range(290):
        angle = rng.random()*math.tau
        r = rng.uniform(127, 151)
        sweep = rng.uniform(.10, .32)
        points = [(center+math.cos(angle+sweep*i/2)*(r+rng.uniform(-2, 2)),
                   center+math.sin(angle+sweep*i/2)*(r+rng.uniform(-2, 2))) for i in range(3)]
        stem(d, points, rng.choice([1, 2, 3]), rng.choice([3, 4, 5]))
        if rng.random() < .22:
            x, y = points[-1]
            d.line([(round(x),round(y)),(round(x+rng.choice([-4,4])),round(y+3))], fill=WOOD[3], width=1)
    for _ in range(185):
        angle = rng.random()*math.tau
        r = rng.uniform(95, 126)
        sweep = rng.uniform(.08, .26)
        points = [(center+math.cos(angle+sweep*i/2)*(r+i-1),
                   center+math.sin(angle+sweep*i/2)*(r+i-1)) for i in range(3)]
        stem(d, points, rng.choice([1, 2]), rng.choice([3, 4, 5]))
    # Each tuft is a tiny authored cluster, rather than thin vector noise.
    for _ in range(640):
        x, y = rng.randrange(-94, 95), rng.randrange(-94, 95)
        if x*x+y*y > 94*94:
            continue
        dx, dy = rng.choice([(3, -1), (4, 0), (1, 3), (-3, 1), (-2,-2)])
        x += center
        y += center
        d.line([(x, y+1), (x+dx, y+dy+1)], fill=WOOD[3], width=1)
        d.line([(x, y), (x+dx, y+dy)], fill=rng.choice(WOOD[5:7]), width=1)
        if rng.random() < .4:
            d.point((x+dx-1, y+dy-1), fill=WOOD[6])
    for x, y, flip in [(-50, 38, 1), (30, -50, -1), (66, 20, 1)]:
        x += center
        y += center
        for i, w in enumerate([0, 1, 1, 2, 2, 2, 1, 1, 0]):
            d.line([(x+i, y+flip*i-w), (x+i, y+flip*i+w)], fill=WOOD[6], width=1)
        d.line([(x, y), (x+9, y+flip*9)], fill=WOOD[3], width=1)
    return indexed(art)


def bark_atlas(tree):
    atlas = Image.new("RGBA", (64, 64))
    atlas.paste(tree, (0, 0))
    d = ImageDraw.Draw(atlas)
    rng = random.Random(219)
    d.rectangle((48, 0, 63, 15), fill=WOOD[3])
    for _ in range(28):
        x, y = rng.randrange(48, 64), rng.randrange(16)
        d.rectangle((x, y, min(63, x+rng.randrange(2, 6)), min(15, y+1)), fill=rng.choice(WOOD[1:6]))
    d.rectangle((48, 16, 63, 31), fill=WOOD[4])
    d.rectangle((51, 19, 60, 28), outline=WOOD[2], width=1)
    d.rectangle((54, 22, 57, 25), outline=WOOD[5], width=1)
    return atlas


def decoration(height_at):
    beams = []
    # Branches sit under the lining, supporting the nest between native crowns.
    for points, width in [([(0, 9), (7, 11), (12, 12), (19, 15), (24, 14)], .55),
                          ([(5, 24), (9, 17), (13, 11), (18, 1)], .43),
                          ([(18, 14), (22, 10), (25, 9)], .25)]:
        for a, b in zip(points, points[1:]):
            beams.append(dict(a=[a[0], -1.2, a[1]], b=[b[0], -1.2, b[1]], width=width, height=width*.7))
    rng = random.Random(319)
    for i in range(64):
        angle = i/64*math.tau+rng.uniform(-.03, .03)
        r = rng.uniform(8.2, 8.95)
        sweep = rng.uniform(.08, .19)
        ends = []
        for a in [angle-sweep*.5, angle+sweep*.5]:
            rr = r+rng.uniform(-.3, .3)
            x, z = 12+math.cos(a)*rr, 12+math.sin(a)*rr
            ends.append([round(x, 4), round(height_at(x, z)+.08, 4), round(z, 4)])
        beams.append(dict(a=ends[0], b=ends[1], width=rng.choice([.07, .10, .13]), height=.08, taper=rng.uniform(.45,.8)))
    return dict(beams=beams, bark_uv=[48, 0, 16, 16], end_uv=[48, 16, 16, 16])


def build(size, pad, radius_at, height_at):
    extent = (size+2*pad)*16
    tree = _tree_template("viridian_forest")[0]
    floor = Image.new("RGBA", (extent, extent), "#24482d")
    d = ImageDraw.Draw(floor)
    rng = random.Random(419)
    # Only dark, square leaf clusters are baked below the elevated crowns.
    for _ in range(1800):
        x, y = rng.randrange(extent//2)*2, rng.randrange(extent//2)*2
        w, h = rng.choice([2, 4, 6]), rng.choice([2, 4])
        d.rectangle((x, y, x+w, y+h), fill=rng.choice(["#183c29", "#24482d", "#315a33"]))
    fallback = floor.copy()
    cards = []
    count = 0
    scaled = 0
    for y in range(-pad-4, size+pad, 2):
        for x in range(-pad-3, size+pad, 3):
            x += 1 if (y//2)%2 else 0
            root_x, root_z = x+1.5, y+4
            distance = math.hypot(root_x-12, root_z-12)
            if distance < 11.6:
                continue
            scale = canopy_scale(distance)
            for col in range(3):
                cards.append([x+col, y, 4, col*16, 0, 0, 1, 0, 0, 1, scale])
            # The 2D fallback shares the same scale and fixed foot position.
            resized = tree.resize((round(tree.width*scale), round(tree.height*scale)), Image.Resampling.NEAREST) if scale!=1.0 else tree
            fallback.alpha_composite(resized, (round((root_x+pad)*16-resized.width*.5), round((root_z+pad)*16-resized.height)))
            count += 1
            scaled += scale>1.0
    nest = bowl(extent, radius_at)
    floor.alpha_composite(nest)
    fallback.alpha_composite(nest)
    layout = dict(tile=16, cards=cards, houses=[], props=[], tables=[], nest_decor=decoration(height_at),
                  art=dict(canopy_source="FRLG Viridian Forest native 48x64 tree", canopy_trees=count,
                           enlarged_canopies=scaled, near_canopy_scale=CANOPY_NEAR_SCALE,
                           full_scale_radius=CANOPY_FULL_RADIUS, normal_scale_radius=CANOPY_NORMAL_RADIUS,
                           nest_palette=WOOD, nest_pixel_grid=1, canopy_base_height=-3.2))
    return fallback, floor, bark_atlas(tree), layout
