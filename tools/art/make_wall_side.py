"""Batch 17: wall_side, the top of a wall that runs vertically, seen from above, floor on
its right. One 16x16 tile per style, put into slot 9 of the style's atlas (ruins and
nature atlases grow from 8 to 10 slots, slot 8 stays empty there). For a floor on the left
the code mirrors the tile.

Built from the style's wall top (slot 4) so moss, mushrooms and stones match:
  - the joint row at the bottom of the wall top is removed (the tile repeats vertically
    without a seam: rows 0 and 15 are plain top face);
  - the edge towards the floor is on the right, in the colours of the wall front's lip:
    column 13 the lip (like row 5 of the wall front), 14 the dark first brick row
    (#17161f), 15 the contact shadow (#08070b), the same order as the front tile from
    its lip downwards, squeezed into 3 px because the side face is not visible from the
    south.

Run from the project root after the atlas generators (make_biome_tiles.py,
make_depth_styles.py, make_nature_tiles.py ...), which write the atlases without slot 9:
    python tools/art/make_wall_side.py
"""
import random

from PIL import Image

T = 16
SLOT = 9
TILES = "assets/art/tiles"


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


# atlas, lip colours (column 13; accents scattered on the lip), extra details
STYLES = {
    "ruins": ("ruins", "#5d6072", []),
    "fungal": ("fungal", "#5d6072", ["#3b5a45", "#3b5a45", "#7a4a2c"]),
    "flooded": ("flooded", "#5d6072", ["#3b5a45"]),
    "fire": ("fire", "#4c4e5f", ["#5a1820"]),
    "sand": ("sand", "#8a7048", ["#d8bc84"]),
    "glade": ("nature", "#8a8466", []),
}
SHADE = hexc("#17161f")
CONTACT = hexc("#08070b")


def body_colour(tile):
    counts = {}
    for p in tile.getdata():
        counts[p] = counts.get(p, 0) + 1
    return max(counts, key=counts.get)


def wall_side(name):
    atlas_name, lip, accents = STYLES[name]
    atlas = Image.open(f"{TILES}/{atlas_name}_tiles_atlas.png").convert("RGBA")
    top = atlas.crop((4 * T, 0, 5 * T, T))
    body = body_colour(top)
    tile = top.copy()
    px = tile.load()
    rnd = random.Random(sum(map(ord, name)))
    # 1. no joint row: the bottom row becomes plain top face, so the tile repeats down
    for x in range(T):
        px[x, T - 1] = body
    # details cut by the new edge: clear columns 12-15 first (a detail that is half
    # covered by the lip looks broken), then draw the edge
    for y in range(T):
        for x in (12,):
            if px[x, y] != body and name != "glade":
                px[x, y] = body
    if name == "glade":
        # the grass overhangs the stone lip in a few tufts; the glade has two lip columns
        warm, warm_dark = hexc("#8a8466"), hexc("#6a6656")
        grass, grass_dark, grass_lit = hexc("#5a8a4a"), hexc("#3b5a45"), hexc("#8ac060")
        for y in range(T):
            px[12, y] = warm
            px[13, y] = warm_dark
            px[14, y] = SHADE
            px[15, y] = CONTACT
            px[11, y] = grass if px[11, y] != grass_lit else grass_lit
        for y in (2, 3, 8, 12, 13):  # tufts over the lip, a darker blade under each
            px[12, y] = grass
        for y in (4, 14):
            px[12, y] = grass_dark
        px[11, 9] = grass_lit
    else:
        lip_c = hexc(lip)
        for y in range(T):
            px[13, y] = lip_c
            px[14, y] = SHADE
            px[15, y] = CONTACT
        # accents on the lip (moss, roots, embers, sand), never on rows 0 and 15
        rows = rnd.sample(range(2, T - 2), len(accents) * 2)
        for i, y in enumerate(rows):
            c = hexc(accents[i // 2])
            px[13, y] = c
            if accents[i // 2] in ("#3b5a45", "#7a4a2c") and i % 2 == 0:
                px[12, y] = c  # moss and roots spill onto the top face
    return tile


def put_in_atlas(name, tile):
    atlas_name = STYLES[name][0]
    path = f"{TILES}/{atlas_name}_tiles_atlas.png"
    atlas = Image.open(path).convert("RGBA")
    width = max(atlas.width, (SLOT + 1) * T)
    out = Image.new("RGBA", (width, T))
    out.paste(atlas.crop((0, 0, min(atlas.width, SLOT * T), T)), (0, 0))
    out.paste(tile, (SLOT * T, 0))
    out.save(path)


def main():
    for name in STYLES:
        put_in_atlas(name, wall_side(name))
        print(f"{name}: wall_side in slot {SLOT} of {STYLES[name][0]}_tiles_atlas.png")


if __name__ == "__main__":
    main()
