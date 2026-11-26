"""Batch 17: wall_side, the top of a wall that runs vertically, seen from above. One 16x16
tile per style, put into slot 9 of the style's atlas (ruins and nature atlases grow from 8
to 10 slots, slot 8 stays empty there).

v2 (the author's decision): the style's wall top (slot 4) without its joint row, nothing
else. The bottom row (the joint, #5d6072 or the style's equivalent) becomes plain top face,
so the tile repeats vertically without a seam, and the edge towards the floor is the colour
of the wall top itself, as before: no lip and no dark line (v1 had a 3 px edge on the right,
#17161f and #08070b, which the author did not like). The tile is the same for a floor on the
left or on the right.

Run from the project root after the atlas generators (make_biome_tiles.py,
make_depth_styles.py, make_nature_tiles.py ...), which write the atlases without slot 9:
    python tools/art/make_wall_side.py
"""
from PIL import Image

T = 16
SLOT = 9
TILES = "assets/art/tiles"

# style -> atlas file
STYLES = {"ruins": "ruins", "fungal": "fungal", "flooded": "flooded", "fire": "fire",
          "sand": "sand", "glade": "nature"}


def body_colour(tile):
    counts = {}
    for p in tile.getdata():
        counts[p] = counts.get(p, 0) + 1
    return max(counts, key=counts.get)


def wall_side(name):
    atlas = Image.open(f"{TILES}/{STYLES[name]}_tiles_atlas.png").convert("RGBA")
    tile = atlas.crop((4 * T, 0, 5 * T, T))
    body = body_colour(tile)
    px = tile.load()
    for x in range(T):  # the joint row becomes plain top face: no seam when repeated down
        px[x, T - 1] = body
    return tile


def put_in_atlas(name, tile):
    path = f"{TILES}/{STYLES[name]}_tiles_atlas.png"
    atlas = Image.open(path).convert("RGBA")
    width = max(atlas.width, (SLOT + 1) * T)
    out = Image.new("RGBA", (width, T))
    out.paste(atlas.crop((0, 0, min(atlas.width, SLOT * T), T)), (0, 0))
    out.paste(tile, (SLOT * T, 0))
    out.save(path)


def main():
    for name in STYLES:
        put_in_atlas(name, wall_side(name))
        print(f"{name}: wall_side in slot {SLOT} of {STYLES[name]}_tiles_atlas.png")


if __name__ == "__main__":
    main()
