"""Ruin styles by depth (plan group 4): flooded ruins and fire ruins, built from the
ruins tiles (assets/art/tiles/ruins_tiles_atlas.png, ruins_hazards.png) so the
architecture stays the same, in the 32-colour palette.

Every style has the same slot layout as the ruins, so a TileTheme only needs other
textures:
- <style>_tiles_atlas.png, 16x16 slots in one row: 0-2 floor (0 plain, the common one;
  1-2 with details), 3 wall front (plain), 4 wall top, 5 cover, 6 cracked wall front,
  7 cracked wall top, and one extra slot 8: a wall front variant with water running
  down (flooded) or a glowing crack (fire), to mix with slot 3 (wall_tiles = [3, 8]).
- <style>_hazards.png: 0 pit edge (deep water / lava edge), 1 spikes, 7 pit inside;
  extra: 2 = shallow water still frame (flooded) or cooled crust (fire, walkable).
Animations, 16x16 frames, loop, tiling seamlessly:
- flooded_shallow.png: shallow water over the floor, 4 frames (64x16).
- fire_lava.png: row 0 lava edge, row 1 lava inside, 4 frames each (64x32).
Decals: fire_decals.png, 16x16: glowing coals, ash, a cooled splash, one big ember.
Run from the project root: python tools/art/make_depth_styles.py
"""
import math
import os

from PIL import Image

TILES = "assets/art/tiles"
T = 16


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


PAL = {k: hexc(v) for k, v in {
    "o": "#08070b", "d": "#0f0e14", "k": "#17161f", "g": "#1f1e29", "s": "#2a2935", "f": "#343442",
    "F": "#3f4050", "e": "#4c4e5f", "S": "#5d6072", "T": "#767a8c", "m": "#9aa2ad", "W": "#d8d4c4",
    "n": "#263a32", "N": "#3b5a45", "j": "#1e3f6a", "l": "#3a7ac0", "L": "#7ac0f0",
    "r": "#5a1820", "R": "#a82a30", "q": "#e85a3a", "y": "#8a4a10", "Y": "#e09a20", "Z": "#ffd860",
    "U": "#f4f0e0",
}.items()}


def slot(img, i):
    return img.crop((i * T, 0, (i + 1) * T, T)).copy()


def recolor(tile, mapping):
    out = tile.copy()
    px = out.load()
    for y in range(T):
        for x in range(T):
            p = px[x, y]
            if p[3]:
                for src, dst in mapping.items():
                    if p == PAL[src]:
                        px[x, y] = PAL[dst]
                        break
    return out


def paint(tile, points, key):
    px = tile.load()
    for x, y in points:
        if 0 <= x < T and 0 <= y < T:
            px[x, y] = PAL[key]
    return tile


def row(tiles, h=T):
    img = Image.new("RGBA", (T * len(tiles), h))
    for i, t in enumerate(tiles):
        img.paste(t, (i * T, 0))
    return img


# ---------------------------------------------------------------- flooded ruins

def flooded_floor(base, variant):
    t = recolor(base, {})
    # Wet stone: dark wet patches and a few glints of water.
    wet = [[],
           [(5, 2), (6, 2), (6, 3), (7, 3), (13, 8), (13, 9), (1, 13), (2, 13)],
           [(9, 6), (10, 6), (10, 7), (4, 12), (5, 12)]][variant]
    paint(t, wet, "j")
    if wet:
        paint(t, [(x + 1, y - 1) for x, y in wet[::3]], "l")
    if variant == 1:
        paint(t, [(14, 2), (14, 3), (15, 3)], "N")
    return t


def flooded_wall(base, streak=False):
    t = recolor(base, {})
    # Moss along the lip; on the variant, water running down the brick front.
    paint(t, [(1, 5), (2, 5), (9, 5), (10, 5), (11, 5)], "N")
    paint(t, [(2, 6), (10, 6)], "n")
    if streak:
        paint(t, [(6, y) for y in range(6, 15)], "j")
        paint(t, [(6, 6), (6, 10)], "l")
        paint(t, [(7, 14), (5, 14)], "j")
    return t


def flooded_top(base):
    t = recolor(base, {})
    paint(t, [(11, 9), (12, 9), (12, 10)], "N")
    paint(t, [(11, 10)], "n")
    return t


def flooded_cover(base):
    t = recolor(base, {})
    px = t.load()
    for y in range(10, 16):
        for x in range(T):
            if px[x, y][3] and px[x, y] not in (PAL["o"],) and (x + y) % 3 == 0:
                px[x, y] = PAL["N"]
    return t


# Short ripple dashes (x, y, length) on a 16x16 tile; they wrap around the edges.
RIPPLES = [(1, 2, 3), (9, 4, 4), (4, 8, 3), (12, 10, 3), (2, 13, 4), (8, 15, 2)]


def ripples(px, shift, light, bright):
    for x0, y, length in RIPPLES:
        for k in range(length):
            x = (x0 + k + shift) % T
            px[x, y] = PAL[bright] if k == 1 else PAL[light]


def deep_water_inner():
    t = Image.new("RGBA", (T, T), PAL["j"])
    px = t.load()
    for x, y in ((6, 5), (14, 1), (3, 11), (10, 13)):
        px[x, y] = PAL["g"]
        px[(x + 1) % T, y] = PAL["g"]
    ripples(px, 0, "l", "l")
    return t


def deep_water_edge(pit_edge):
    """The pit edge's broken stone rim on top, water below it."""
    t = deep_water_inner()
    rim = pit_edge.load()
    px = t.load()
    for y in range(5):
        for x in range(T):
            p = rim[x, y]
            if p[3] and p not in (PAL["d"], PAL["o"], PAL["k"]):
                px[x, y] = p
            elif y < 4:
                px[x, y] = PAL["g"]
    for x in range(T):
        px[x, 5] = PAL["L"] if x % 5 == 1 else PAL["l"]
    return t


def shallow(floor, frame):
    """Floor seen through shallow water: the stone pattern in blue, ripples drifting right."""
    t = floor.copy()
    px = t.load()
    tint = {PAL["f"]: PAL["j"], PAL["F"]: PAL["j"], PAL["s"]: PAL["g"], PAL["e"]: PAL["l"], PAL["g"]: PAL["g"]}
    for y in range(T):
        for x in range(T):
            px[x, y] = tint.get(px[x, y], PAL["j"])
    ripples(px, frame * 4, "l", "L")
    return t


# ---------------------------------------------------------------- fire ruins

BASALT = {"f": "s", "F": "f", "e": "F", "s": "g", "n": "r", "N": "R"}


def fire_floor(base, variant):
    t = recolor(base, BASALT)
    embers = [[], [(11, 4), (12, 4)], [(7, 13)]][variant]
    paint(t, embers, "q")
    paint(t, [(x, y + 1) for x, y in embers], "r")
    if variant == 2:
        paint(t, [(2, 2), (3, 3), (4, 3), (5, 4)], "k")
    return t


def fire_wall(base, crack_on=False):
    t = recolor(base, {"S": "e", "T": "S", "s": "g", "g": "k", "N": "R", "n": "r"})
    if not crack_on:
        return t
    # A glowing crack zigzagging down the brick front.
    crack = [(7, 6), (8, 7), (8, 8), (7, 9), (7, 10), (8, 11), (9, 12), (9, 13), (10, 14)]
    paint(t, crack, "q")
    paint(t, [crack[2], crack[5]], "Y")
    paint(t, [(x + 1, y) for x, y in crack[::2]], "R")
    return t


def fire_top(base):
    return recolor(base, {"T": "S", "S": "e"})


def fire_cover(base):
    t = recolor(base, {"T": "e", "m": "S", "W": "S", "U": "T", "S": "F", "e": "f"})
    paint(t, [(7, 6), (8, 7), (8, 8), (7, 9)], "q")
    paint(t, [(8, 8)], "Y")
    return t


def lava_field(x, y, phase):
    a = math.sin((x / T) * math.tau + phase)
    b = math.sin((y / T) * math.tau * 2 + phase * 0.5 + x / T * math.tau)
    c = math.sin(((x - y) / T) * math.tau + phase * 1.5)
    return (a + b + c + 3.0) / 6.0


def lava_inner(phase):
    t = Image.new("RGBA", (T, T))
    px = t.load()
    for y in range(T):
        for x in range(T):
            v = lava_field(x, y, phase)
            px[x, y] = PAL["R"] if v < 0.3 else PAL["q"] if v < 0.62 else PAL["Y"] if v < 0.82 else PAL["Z"]
    return t


def lava_edge(phase):
    """Basalt lip on top, a bright seam, then lava."""
    t = lava_inner(phase)
    px = t.load()
    for y in range(4):
        for x in range(T):
            px[x, y] = PAL["s"] if (x + y) % 5 else PAL["g"]
    for x in range(T):
        px[x, 0] = PAL["F"] if x % 6 else PAL["f"]
        px[x, 4] = PAL["k"] if x % 3 else PAL["r"]
        px[x, 5] = PAL["Z"] if (x + int(phase * 3)) % 4 == 0 else PAL["Y"]
    return t


def cooled_crust():
    t = Image.new("RGBA", (T, T), PAL["g"])
    seams = [(x, 5 + int(2 * math.sin(x * 0.8))) for x in range(T)] + [(6 + int(math.sin(y)), y) for y in range(6, T)]
    paint(t, [(x, y) for x, y in seams], "r")
    paint(t, [(x, y) for x, y in seams[::5]], "R")
    paint(t, [(2, 2), (12, 10), (9, 13)], "s")
    return t


def fire_decals():
    tiles = []
    # Glowing coals.
    t = Image.new("RGBA", (T, T))
    for x, y in ((5, 7), (9, 9), (7, 11), (11, 6)):
        paint(t, [(x, y), (x + 1, y)], "q")
        paint(t, [(x, y + 1), (x + 1, y + 1)], "r")
        paint(t, [(x, y)], "Y")
    tiles.append(t)
    # Ash patch.
    t = Image.new("RGBA", (T, T))
    for y in range(5, 12):
        for x in range(4, 13):
            if (x - 8) ** 2 / 16 + (y - 8) ** 2 / 9 <= 1 and (x * 3 + y) % 4:
                paint(t, [(x, y)], "e" if (x + y) % 3 else "S")
    tiles.append(t)
    # A cooled lava splash with red seams.
    t = Image.new("RGBA", (T, T))
    for y in range(4, 13):
        for x in range(3, 14):
            if (x - 8) ** 2 / 25 + (y - 8) ** 2 / 12 <= 1:
                paint(t, [(x, y)], "k")
    paint(t, [(5, 8), (6, 8), (7, 9), (8, 9), (9, 8), (10, 7), (8, 6), (8, 10)], "r")
    paint(t, [(7, 9)], "R")
    tiles.append(t)
    # One big ember.
    t = Image.new("RGBA", (T, T))
    paint(t, [(7, 7), (8, 7), (6, 8), (9, 8), (7, 9), (8, 9)], "q")
    paint(t, [(7, 8), (8, 8)], "Z")
    paint(t, [(6, 9), (9, 9), (7, 10), (8, 10)], "r")
    tiles.append(t)
    return row(tiles)


def main():
    ruins = Image.open(f"{TILES}/ruins_tiles_atlas.png").convert("RGBA")
    hazards = Image.open(f"{TILES}/ruins_hazards.png").convert("RGBA")
    floors = [slot(ruins, i) for i in range(3)]
    wall, top, cover, cwall, ctop = (slot(ruins, i) for i in range(3, 8))
    pit_edge, spikes = slot(hazards, 0), slot(hazards, 1)
    blank = Image.new("RGBA", (T, T))

    # Flooded ruins.
    row([flooded_floor(floors[i], i) for i in range(3)] + [flooded_wall(wall), flooded_top(top), flooded_cover(cover),
        flooded_wall(cwall), flooded_top(ctop), flooded_wall(wall, streak=True)]).save(f"{TILES}/flooded_tiles_atlas.png")
    row([deep_water_edge(pit_edge), spikes, shallow(floors[0], 0), blank, blank, blank, blank,
         deep_water_inner()]).save(f"{TILES}/flooded_hazards.png")
    row([shallow(floors[0], k) for k in range(4)]).save(f"{TILES}/flooded_shallow.png")

    # Fire ruins.
    row([fire_floor(floors[i], i) for i in range(3)] + [fire_wall(wall), fire_top(top), fire_cover(cover),
        fire_wall(cwall), fire_top(ctop), fire_wall(wall, crack_on=True)]).save(f"{TILES}/fire_tiles_atlas.png")
    row([lava_edge(0.0), recolor(spikes, {"f": "s", "F": "f"}), cooled_crust(), blank, blank, blank, blank,
         lava_inner(0.0)]).save(f"{TILES}/fire_hazards.png")
    lava = Image.new("RGBA", (T * 4, T * 2))
    for k in range(4):
        lava.paste(lava_edge(k * math.tau / 4), (k * T, 0))
        lava.paste(lava_inner(k * math.tau / 4), (k * T, T))
    lava.save(f"{TILES}/fire_lava.png")
    fire_decals().save(f"{TILES}/fire_decals.png")


if __name__ == "__main__":
    main()
