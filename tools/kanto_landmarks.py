"""Assemble mainland landmark surfaces from the project's original FRLG map layers."""

from PIL import Image

from north_terrain import remove_cells, source_cells

# Rectangles use world tiles with exclusive right/bottom edges.
LAVENDER_HOUSES = ((392, 138, 397, 142), (387, 143, 392, 147), (392, 143, 397, 147))
RIDGE = (196, 326, 221, 330)
# Native roof bounds and first wall scanline, measured from the composite tile.
FUCHSIA_HOUSES = (
    ((198, 328, 205, 333), 1, 44),
    ((205, 328, 210, 332), 8, 35),
    ((210, 328, 215, 332), 8, 35),
    ((215, 327, 220, 332), 10, 51),
)
FISHING_HOUSE = (395, 234, 400, 237)
BRIDGE = (285, 17, 290, 45)
ROCK_COLORS = {
    (90, 57, 65),
    (123, 74, 74),
    (148, 106, 106),
    (189, 148, 139),
    (222, 197, 164),
    (238, 213, 197),
}
PIER_TILES = {0x1BD, 0x1BE, 0x1BF, 0x1C5, 0x1C6, 0x1C7, 0x1CD, 0x1CE, 0x1CF}


def cells(rect):
    x0, y0, x1, y1 = rect
    return {(x, y) for x in range(x0, x1) for y in range(y0, y1)}


def pixels(rect, pad=0):
    return tuple((value + pad) * 16 for value in rect)


def native_art(directory, rect, pad):
    with Image.open(directory / "bottom.png") as bottom, Image.open(directory / "top.png") as top:
        art = bottom.crop(pixels(rect, pad)).convert("RGBA")
        art.alpha_composite(top.crop(pixels(rect)).convert("RGBA"))
    return art


def configure_scenery(directory, scenery, pad):
    # Each Lavender house mixes priority layers. Use one continuous roof and
    # facade so windows/roof tiles cannot land on different height planes.
    removed = cells(BRIDGE)
    for rect in LAVENDER_HOUSES:
        removed.update(cells(rect))
        art = native_art(directory, rect, pad)
        x, y, end, front = rect
        name = "lavender_roof"
        # The first eight source rows are lawn behind the house.
        make_prop(
            directory, scenery, name, x, end, front, art.crop((0, 8, art.width, art.height)), 34
        )
    # The house faces south on the Route 12 waterfront. The upper corners
    # contain the original shoreline, which belongs on the ground plane.
    removed.update(cells(FISHING_HOUSE))
    cottage = native_art(directory, FISHING_HOUSE, pad)
    for py in range(cottage.height):
        for px in range(cottage.width):
            r, g, b, _ = cottage.getpixel((px, py))
            if (g > r and g > b) or (py < 6 and (r, g, b) in ROCK_COLORS):
                cottage.putpixel((px, py), (0, 0, 0, 0))
    x, _, end, front = FISHING_HOUSE
    make_prop(directory, scenery, "fishing_house", x, end, front, cottage, 27)
    # The clinic roof overlaps the cliff in the original two layers. Rebuild
    # the rock behind it using a full column from the same continuous ridge.
    rock = native_art(directory, RIDGE, pad)
    donor = rock.crop((16, 0, 32, rock.height))
    for col in range(2, 24):
        rock.paste(donor, (col * 16, 0))
    for py in range(rock.height):
        for px in range(rock.width):
            r, g, b, _ = rock.getpixel((px, py))
            if g > r and g > b:
                rock.putpixel((px, py), (0, 0, 0, 0))
    x, y, end, front = RIDGE
    make_prop(directory, scenery, "fuchsia_ridge", x, end, front, rock, 32)
    # Mask the background rock in the first rows of the adjoining roofs;
    # projecting it onto a roof as well as the ridge produces a second rock face.
    for i, (rect, inset, wall) in enumerate(FUCHSIA_HOUSES):
        removed.update(cells(rect))
        art = native_art(directory, rect, pad)
        x, _, end, front = rect
        for py in range(art.height):
            for px in range(art.width):
                r, g, b, _ = art.getpixel((px, py))
                if g > r and g > b or (py < 18 and (r, g, b) in ROCK_COLORS):
                    art.putpixel((px, py), (0, 0, 0, 0))
        make_prop(
            directory,
            scenery,
            "fuchsia_house_" + str(i),
            x,
            end,
            front,
            art.crop((0, inset, art.width, art.height)),
            wall - inset,
        )
    removed.update(cells(RIDGE))
    cards = []
    for card in scenery["cards"]:
        x, y, n = card[:3]
        if not any((x, row) in removed for row in range(y, y + n)):
            cards.append(card)
        else:
            cards.extend(remove_cells([card], removed))
    # Lower the native lab eaves enough to see the player on the mansion lane.
    for card in cards:
        if 65 <= card[0] < 72 and card[1:3] == [386, 4]:
            card[6] = 0.68
    scenery["cards"] = cards
    # The old bridge extraction treats single handrail pixels as signposts.
    scenery["props"] = [
        p
        for p in scenery["props"]
        if not (BRIDGE[0] <= p["x0"] < BRIDGE[2] and BRIDGE[1] <= p["z"] <= BRIDGE[3])
    ]


def make_prop(directory, scenery, name, x, end, front, art, split):
    tex = "landmark_" + name
    roof = art.crop((0, 0, art.width, split))
    face = art.crop((0, split, art.width, art.height))
    roof.save(directory / (tex + "_top.png"))
    face.save(directory / (tex + "_front.png"))
    face.crop((3, 0, 4, face.height)).save(directory / (tex + "_side.png"))
    scenery["props"].append(dict(x0=x, x1=end, z=front, d=split / 16, h=face.height / 16, tex=tex))


def restore_ground(directory, image, nav):
    pad = nav["pad"]
    # Replace the full bridge including its rail pixels, and only the authored
    # timber metatiles of the harbor. Nearby roads retain the selected palette.
    image.paste(native_art(directory, BRIDGE, pad), pixels(BRIDGE, pad)[:2])
    harbor = next(a for a in nav["areas"] if a["id"] == "vermilion_city")
    bounds = (harbor["x"], harbor["y"], harbor["x"] + harbor["w"], harbor["y"] + harbor["h"])
    art = native_art(directory, bounds, pad)
    for (x, y), mid in source_cells(nav, ["VermilionCity"]).items():
        if mid in PIER_TILES:
            sx, sy = (x - bounds[0]) * 16, (y - bounds[1]) * 16
            image.paste(art.crop((sx, sy, sx + 16, sy + 16)), ((x + pad) * 16, (y + pad) * 16))
    # Remove the roof/window/ridge fragments previously left on the floor.
    # Take the donor from the same floor variant, retaining HGSS grass when active.
    substrates = [(rect, (397, 142)) for rect in LAVENDER_HOUSES]
    substrates += [(RIDGE, (222, 325))] + [(rect, (222, 325)) for rect, _, _ in FUCHSIA_HOUSES]
    # Keep the thin shore behind the cottage aligned with its neighboring tile.
    x0, y0, x1, y1 = FISHING_HOUSE
    substrates.extend([((x0, y0, x1, y0 + 1), (394, 234)),
                       ((x0, y0 + 1, x1, y1), (394, 237))])
    for rect, donor in substrates:
        dx, dy = donor
        lawn = image.crop(pixels((dx, dy, dx + 1, dy + 1), pad))
        for x, y in cells(rect):
            image.paste(lawn, ((x + pad) * 16, (y + pad) * 16))
