"""Generates assets/placeholder/placeholder_tiles.png: 16x16 tiles for things the
Kenney Tiny Dungeon pack does not have. Run from the project root:

    python tools/make_placeholder_tiles.py

Tile order (left to right): 0 pit, 1 spikes, 2 coin, 3 portal closed, 4 portal open,
5 bow icon, 6 dash icon, 7 spikes icon reserved (empty).
The art is our own placeholder and can be replaced; the game refers to tiles only
through resources (tile theme, AtlasTexture files), never by pixel content.
"""
from PIL import Image, ImageDraw

TILE = 16
COUNT = 8
SAND = (230, 160, 98, 255)
SAND_DARK = (203, 130, 78, 255)
STONE = (163, 172, 190, 255)
STONE_DARK = (70, 66, 94, 255)
OUTLINE = (40, 34, 52, 255)

sheet = Image.new("RGBA", (TILE * COUNT, TILE), (0, 0, 0, 0))


def tile(index):
    image = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    return image, ImageDraw.Draw(image), index


def put(image, index):
    sheet.paste(image, (index * TILE, 0))


# 0: pit - dark hole with a lighter rim at the top to hint at depth
image, draw, index = tile(0)
draw.rectangle([0, 0, 15, 15], fill=(16, 12, 22, 255))
draw.rectangle([0, 0, 15, 1], fill=(58, 44, 60, 255))
draw.rectangle([0, 2, 15, 3], fill=(34, 26, 40, 255))
put(image, index)

# 1: spikes - sand floor with four metal spikes
image, draw, index = tile(1)
draw.rectangle([0, 0, 15, 15], fill=SAND)
for cx, cy in ((4, 5), (11, 5), (4, 12), (11, 12)):
    draw.polygon([(cx - 3, cy + 2), (cx, cy - 4), (cx + 3, cy + 2)], fill=STONE, outline=OUTLINE)
    draw.point((cx, cy - 2), fill=(240, 240, 250, 255))
put(image, index)

# 2: coin
image, draw, index = tile(2)
draw.ellipse([4, 4, 11, 11], fill=(250, 200, 60, 255), outline=(150, 96, 20, 255))
draw.point((6, 6), fill=(255, 245, 190, 255))
draw.point((7, 6), fill=(255, 245, 190, 255))
put(image, index)

# 3 and 4: portal gate, closed (dim) and open (bright)
for index, inner, glow in ((3, (52, 40, 78, 255), (80, 64, 110, 255)),
                           (4, (90, 220, 230, 255), (220, 255, 255, 255))):
    image = Image.new("RGBA", (TILE, TILE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle([1, 0, 14, 15], radius=5, fill=STONE, outline=OUTLINE)
    draw.rounded_rectangle([4, 3, 11, 15], radius=3, fill=inner)
    draw.line([(6, 6), (9, 6)], fill=glow)
    draw.line([(5, 9), (10, 9)], fill=glow)
    draw.line([(6, 12), (9, 12)], fill=glow)
    put(image, index)

# 5: bow icon
image, draw, index = tile(5)
draw.arc([-4, 1, 12, 14], start=-70, end=70, fill=(170, 100, 50, 255), width=2)
draw.line([(6, 2), (6, 13)], fill=(230, 230, 230, 255))
draw.line([(3, 7), (13, 7)], fill=(230, 230, 230, 255))
draw.polygon([(13, 7), (11, 5), (11, 9)], fill=(230, 230, 230, 255))
put(image, index)

# 6: dash icon - two chevrons
image, draw, index = tile(6)
for x in (3, 8):
    draw.line([(x, 3), (x + 4, 7), (x, 12)], fill=(240, 240, 250, 255), width=2)
put(image, index)

sheet.save("assets/placeholder/placeholder_tiles.png")
print("saved assets/placeholder/placeholder_tiles.png", sheet.size)
