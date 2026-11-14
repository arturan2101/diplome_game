"""Secret wall art.
- Cracked wall tiles, slots 6 (brick front) and 7 (wall top) of
  assets/art/tiles/ruins_tiles_atlas.png: the ordinary wall with a thin crack that is
  easy to miss from afar but honest up close (a dark zig-zag plus one lit edge).
- Collapse: assets/art/fx/wall_collapse.png, 6 frames of 16x24 (the wall cell plus
  room for falling stones): the crack spreads, the bricks break apart, fall and settle
  as rubble on the floor. Dust and chips come from the effect scene's particles.
Run from the project root: python tools/art/make_secret_wall.py
"""
import os

from PIL import Image

T = 16
ATLAS = "assets/art/tiles/ruins_tiles_atlas.png"
DARK = (23, 22, 31, 255)       # 17161f
DEEP = (8, 7, 11, 255)         # 08070b
LIT = (93, 96, 114, 255)       # 5d6072
STONE = (118, 122, 140, 255)   # 767a8c
BRICK = (42, 41, 53, 255)      # 2a2935
RUBBLE = (76, 78, 95, 255)     # 4c4e5f
# The crack: (x, y) on the 16x16 tile, top to bottom.
CRACK = [(9, 6), (8, 7), (8, 8), (9, 9), (10, 10), (9, 11), (8, 12), (8, 13), (7, 14)]


def cracked(tile, points, lit=True):
    out = tile.copy()
    px = out.load()
    for x, y in points:
        px[x, y] = DEEP
        if lit and x > 0:
            px[x - 1, y] = LIT  # the lit lip on the left of the crack
    return out


def collapse_frames(front, top):
    """6 frames 16x24: the wall cell sits in rows 8-23, rows 0-7 are free above it."""
    frames = []
    base = Image.new("RGBA", (T, 24))
    base.paste(front, (0, 8))
    # 1: the crack spreads over the whole face
    wide = CRACK + [(11, 9), (12, 8), (6, 11), (5, 12), (10, 13), (11, 14), (3, 9), (13, 11)]
    f1 = base.copy()
    f1.paste(cracked(front, wide), (0, 8))
    frames.append(f1)
    # 2-4: blocks break off and fall, the top face sinks
    for step in range(3):
        f = Image.new("RGBA", (T, 24))
        px = f.load()
        drop = 3 + step * 4
        for by in range(8, 24, 4):
            for bx in range(0, T, 4):
                ox = (bx // 4 + by // 4) % 3 - 1
                y0 = by + drop * (1 + (bx // 4) % 2) // 2
                for dy in range(3):
                    for dx in range(3):
                        x, y = bx + dx + ox * step, min(23, y0 + dy)
                        if 0 <= x < T:
                            px[x, y] = BRICK if dy else LIT
        frames.append(f)
    # 5-6: rubble on the floor, a few stones
    for k in range(2):
        f = Image.new("RGBA", (T, 24))
        px = f.load()
        for x in range(1, 15):
            h = 1 + (x * 7 + k) % 3
            for y in range(23 - h, 24):
                px[x, y] = RUBBLE if y == 23 - h else BRICK
        for x, y in ((3, 19), (8, 18), (12, 20)):
            px[x, y] = STONE
        frames.append(f)
    return frames


atlas = Image.open(ATLAS).convert("RGBA")
if atlas.width < 8 * T:
    wider = Image.new("RGBA", (8 * T, T))
    wider.paste(atlas, (0, 0))
    atlas = wider
front = atlas.crop((3 * T, 0, 4 * T, T))
top = atlas.crop((4 * T, 0, 5 * T, T))
atlas.paste(cracked(front, CRACK), (6 * T, 0))
atlas.paste(cracked(top, [(9, 4), (8, 5), (8, 6), (9, 7), (10, 8)]), (7 * T, 0))
atlas.save(ATLAS)
strip = Image.new("RGBA", (T * 6, 24))
for i, f in enumerate(collapse_frames(front, top)):
    strip.paste(f, (i * T, 0))
os.makedirs("assets/art/fx", exist_ok=True)
strip.save("assets/art/fx/wall_collapse.png")
print("secret wall art written")
