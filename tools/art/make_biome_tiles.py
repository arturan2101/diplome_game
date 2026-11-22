"""Batch 15, parts 3 and 4: the tiles, props and floor effects of two new floor styles,
"fungal catacombs" (id fungal) and "sand temple" (id sand). Same slot layout as the
flooded and fire styles (tools/art/make_depth_styles.py), built on the ruins tiles so
the architecture stays the same. Extra colours: docs/art-style.md "Fungal theme" and
"Sand temple theme" (keys 1-3 p x v and 6-9 S D in make_batch15.PAL).

For each style <s> in (fungal, sand):
  tiles/<s>_tiles_atlas.png   144x16: 0-2 floor, 3 wall front, 4 wall top, 5 cover,
                              6-7 cracked wall front / top, 8 second wall front
  tiles/<s>_hazards.png       128x16: 0 pit edge, 1 spikes, 2 still frame of the floor
                              hazard (spore fungus / quicksand), 7 pit inside
  tiles/<s>_decals.png        64x16, 4 decals
  tiles/<s>_wall_details.png  80x16, 5 details on the wall front, rows 6-14
  tiles/<s>_door_seal.png     16x16
  level/<s>_lamp.png          16x16 x 4, loop: glowing mushroom / brazier on the wall
  level/<s>_obstacle_*.png    cover props (tall 16x32, small 16x16, wide 32x16)
fungal only: level/spore_puff.png (16x16: 4 breathing + 6 burst = 160x16),
             fx/spore_cloud.png (32x32 x 6, loop)
sand only:   tiles/sand_quicksand.png (16x16 x 4, loop, seamless)
Both: rows 4 (fungal) and 5 (sand) appended to ui/floor_plates.png (64x80 in all).
Run from the project root: python tools/art/make_biome_tiles.py
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_batch15 import RGB, Canvas, strip  # noqa: E402

T = 16
TILES = "assets/art/tiles"
LEVEL = "assets/art/level"


def hexkey(h):
    return {"#343442": "f", "#3f4050": "F", "#2a2935": "5", "#263a32": "n", "#767a8c": "T",
            "#5d6072": "s", "#1f1e29": "g", "#17161f": "k", "#08070b": "o", "#0f0e14": "d",
            "#9aa2ad": "m", "#4c4e5f": "e", "#3b5a45": "N"}.get(h)


def load_slot(path, i):
    im = Image.open(path).convert("RGBA").crop((i * T, 0, (i + 1) * T, T))
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            p = im.getpixel((x, y))
            if p[3]:
                k = hexkey("#%02x%02x%02x" % p[:3])
                if k:
                    c.set(x, y, k)
    return c


def remap(c, mapping):
    out = Canvas(c.w, c.h)
    for y in range(c.h):
        for x in range(c.w):
            k = c.get(x, y)
            if k != ".":
                out.set(x, y, mapping.get(k, k))
    return out


def paint(c, pts, k):
    for x, y in pts:
        c.set(x % c.w, y % c.h, k)


def clip_rows(c, first=6, last=14):
    """Wall details live on rows 6-14 of the wall front only."""
    for y in range(c.h):
        if first <= y <= last:
            continue
        for x in range(c.w):
            c.px[x, y] = (0, 0, 0, 0)


def row(canvases):
    return strip([c.img for c in canvases])


RUINS = f"{TILES}/ruins_tiles_atlas.png"
HAZ = f"{TILES}/ruins_hazards.png"


# =====================================================================================
# Fungal catacombs
# =====================================================================================

EARTH = {"f": "2", "F": "3", "5": "1"}


def fungal_floor(v):
    c = remap(load_slot(RUINS, v), EARTH)
    # pebbles and root threads in the earth
    paint(c, [(3, 4), (11, 12), (13, 3)], "3")
    paint(c, [(4, 5), (12, 13)], "1")
    if v == 1:   # mycelium threads
        for x, y in ((2, 9), (3, 9), (4, 10), (5, 10), (6, 10), (7, 11), (5, 9), (8, 11), (9, 12)):
            c.set(x, y, "e")
        c.set(6, 9, "3")
    if v == 2:   # a few tiny glowing mushrooms
        for x, y, k in ((10, 6, "x"), (10, 7, "w"), (12, 8, "h"), (12, 9, "e")):
            c.set(x, y, k)
        paint(c, [(11, 9), (9, 9)], "1")
    return c


def roots(c, path, dark="b", light="B"):
    for i, (x, y) in enumerate(path):
        c.set(x, y, light if i % 3 == 0 else dark)


def fungal_wall(src=3, variant=0):
    c = load_slot(RUINS, src)
    # moss on the lip and in the mortar
    paint(c, [(1, 5), (2, 5), (3, 5), (8, 5), (9, 5), (13, 5)], "N")
    paint(c, [(2, 6), (9, 6), (12, 10)], "n")
    if variant == 0:
        # a root crossing the bricks from the top
        roots(c, [(4, 5), (4, 6), (5, 7), (5, 8), (6, 9), (6, 10), (7, 11), (7, 12), (8, 13)])
        roots(c, [(12, 6), (12, 7), (13, 8), (13, 9)])
    else:
        # shelf fungi glowing on the bricks
        for x0, y0 in ((3, 8), (10, 11)):
            for dx, k in ((0, "h"), (1, "H"), (2, "p"), (3, "H")):
                c.set(x0 + dx, y0, k)
            c.set(x0 + 1, y0 + 1, "h")
            c.set(x0 + 2, y0 + 1, "h")
        roots(c, [(8, 5), (8, 6), (9, 7), (9, 8)])
    return c


def fungal_top(src=4):
    c = load_slot(RUINS, src)
    # moss and grass over the stone top, a small mushroom
    for x, y in ((1, 1), (2, 1), (2, 2), (3, 2), (9, 8), (10, 8), (10, 9), (11, 9), (5, 12), (6, 12),
                 (13, 4), (14, 4), (14, 5)):
        c.set(x, y, "N")
    for x, y in ((2, 2), (10, 9), (14, 5)):
        c.set(x, y, "G")
    for x, y, k in ((6, 5, "x"), (7, 5, "x"), (6, 6, "w"), (12, 12, "H"), (12, 13, "w")):
        c.set(x, y, k)
    return c


def mushroom(c, cx, base, h, cap_w, cap_k=("h", "H", "p"), stalk=("m", "w")):
    """A mushroom with its stalk standing on row base."""
    for y in range(base - h, base + 1):
        c.set(cx, y, stalk[1])
        c.set(cx + 1, y, stalk[0])
    top = base - h - 2
    for dy in range(3):
        half = cap_w // 2 - (1 if dy == 0 else 0)
        for dx in range(-half, half + 2):
            x = cx + dx
            k = cap_k[1]
            if dy == 0 or dx < 0:
                k = cap_k[2] if dy < 2 else cap_k[1]
            if dy == 2 or dx >= half:
                k = cap_k[0]
            c.set(x, top + dy, k)


def fungal_cover():
    """A stone stump overgrown with a cluster of glowing mushrooms."""
    c = Canvas(T, T)
    for y in range(8, 15):
        for x in range(3, 13):
            k = "s" if x < 6 else "e" if x < 10 else "F"
            if y == 8:
                k = "T"
            c.set(x, y, k)
    for x, y in ((5, 10), (6, 11), (8, 12), (9, 13), (11, 10)):
        c.set(x, y, "N")
    mushroom(c, 5, 8, 2, 6)
    mushroom(c, 10, 9, 1, 4, cap_k=("a", "x", "A"))
    c.outline()
    for x in range(3, 14):
        c.set(x, 15, "d")
    return c


def fungal_pit_edge():
    c = load_slot(HAZ, 0)
    c = remap(c, {"T": "3", "s": "2", "5": "1", "f": "2"})
    # roots hanging down into the dark
    for x0, n in ((3, 6), (9, 8), (13, 5)):
        for k in range(n):
            c.set(x0 + (k // 3) % 2, 6 + k, "b" if k % 3 else "B")
    return c


def fungal_pit_inner():
    c = load_slot(HAZ, 7)
    for x, y in ((4, 3), (4, 4), (5, 5), (11, 9), (12, 10), (12, 11)):
        c.set(x, y, "k")
    return c


def thorn_spikes():
    c = remap(load_slot(HAZ, 1), {"f": "2", "5": "1", "e": "B", "s": "b", "m": "w"})
    return c


def puffball(c, cx, base, swell, burst=0):
    """A spore puffball on the floor: round body, pale spots, dark pore on top."""
    rx = 4.2 + swell * 0.5 - burst * 0.6
    ry = 3.4 + swell * 0.6 - burst * 0.9
    cy = base - ry
    for y in range(c.h):
        for x in range(c.w):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1:
                lit = -dx - dy
                c.set(x, y, "p" if lit > 0.9 else "H" if lit > -0.6 else "h")
    for x, y in ((cx - 2, cy - 1), (cx + 1, cy + 1), (cx - 1, cy + 1)):
        c.set(x, y, "x")
    c.set(cx, cy - ry + 0.6, "o" if burst else "h")
    c.set(cx - 1, cy - ry + 0.6, "h")


def spore_floor_still():
    c = Canvas(T, T)
    puffball(c, 8, 13, 0)
    c.outline()
    for x in range(4, 13):
        c.set(x, 14, "1")
    return c


def spore_puff():
    frames = []
    for i in range(10):
        c = Canvas(T, T)
        if i < 4:
            puffball(c, 8, 13, (0, 1, 2, 1)[i])
        else:
            j = i - 4
            puffball(c, 8, 13, (2, 0, 0, 0, 0, 0)[j], burst=(0, 2, 2, 1, 1, 0)[j])
        c.outline()
        for x in range(4, 13):
            c.set(x, 14, "1")
        if i >= 5:   # spores thrown up and drifting
            j = i - 5
            rnd = random.Random(3)
            for n in range(8):
                ang = rnd.uniform(-2.6, -0.5)
                sp = rnd.uniform(0.6, 1.0)
                d = (2, 4, 6, 7, 8)[j] * sp
                x = 8 + math.cos(ang) * d * 1.2
                y = 8 + math.sin(ang) * d - j * 0.4
                if j < 4 or n % 2:
                    c.set(x, y, "v" if n % 3 else "V" if j < 3 else "G")
        frames.append(c)
    return row(frames)


def spore_cloud(frame):
    """A drifting toxic cloud, loop of 6: blobs that swell and turn."""
    c = Canvas(32, 32)
    blobs = []
    for n in range(7):
        a = n * math.tau / 7 + frame * math.tau / 6 * 0.5
        r = 7 if n % 2 else 4.5
        blobs.append((16 + math.cos(a) * r, 16 + math.sin(a) * r * 0.8,
                      4.6 + 1.2 * math.sin(frame * math.tau / 6 + n * 1.7)))
    blobs.append((16, 16, 7.0))
    for y in range(32):
        for x in range(32):
            best = None
            for bx, by, br in blobs:
                d = math.hypot(x + 0.5 - bx, y + 0.5 - by) / br
                if d <= 1 and (best is None or d < best[0]):
                    best = (d, bx, by)
            if best:
                d, bx, by = best
                lit = (bx - x) + (by - y)
                k = "v" if lit > 1.5 and d > 0.3 else "V" if d < 0.8 else "G"
                c.set(x, y, k)
    c.outline(skip=())
    # recolour the outline to a dark green rim (a gas, not a solid)
    for y in range(32):
        for x in range(32):
            if c.get(x, y) == "o":
                c.set(x, y, "N")
    rnd = random.Random(frame)
    for _ in range(5):
        c.set(rnd.randint(6, 25), rnd.randint(6, 25), "W" if rnd.random() < 0.3 else "x")
    return c


def fungal_decals():
    out = []
    # 0 cluster of tiny glowing mushrooms
    c = Canvas(T, T)
    for cx, base, k in ((5, 11, ("h", "H", "p")), (9, 12, ("a", "x", "A")), (11, 9, ("h", "H", "p"))):
        c.set(cx, base, "w")
        c.set(cx, base - 1, k[1])
        c.set(cx - 1, base - 1, k[2])
        c.set(cx + 1, base - 1, k[0])
    out.append(c)
    # 1 mycelium web on the earth
    c = Canvas(T, T)
    for a in range(6):
        ang = a * math.tau / 6 + 0.3
        for t in range(1, 7):
            if (t + a) % 4:
                c.set(8 + math.cos(ang + t * 0.08) * t, 8 + math.sin(ang + t * 0.08) * t * 0.7, "e")
    c.set(8, 8, "m")
    out.append(c)
    # 2 fallen broken cap
    c = Canvas(T, T)
    for x in range(4, 12):
        c.set(x, 8, "H" if x < 9 else "h")
        c.set(x, 9, "h")
    for x in range(5, 11):
        c.set(x, 7, "p" if x < 7 else "H")
    c.set(6, 9, "m")
    c.set(8, 9, "m")
    c.outline()
    out.append(c)
    # 3 moss patch with glowing spores
    c = Canvas(T, T)
    for y in range(5, 12):
        for x in range(3, 13):
            if (x - 8) ** 2 / 25 + (y - 8) ** 2 / 9 <= 1 and (x * 5 + y * 3) % 4:
                c.set(x, y, "n" if (x + y) % 3 else "N")
    for x, y in ((6, 7), (10, 9), (8, 6)):
        c.set(x, y, "x")
    out.append(c)
    return row(out)


def fungal_wall_details():
    out = []
    # 0 hanging roots
    c = Canvas(T, T)
    for x0, n in ((3, 8), (7, 6), (11, 9), (13, 5)):
        for k in range(n):
            c.set(x0 + (1 if k in (3, 4) else 0), 6 + k, "B" if k % 3 == 0 else "b")
        c.set(x0, 6 + n, "c")
    out.append(c)
    # 1 shelf fungi, glowing
    c = Canvas(T, T)
    for x0, y0, w in ((2, 8, 5), (8, 11, 6), (9, 7, 4)):
        for dx in range(w):
            c.set(x0 + dx, y0, "p" if dx < 2 else "H")
            if 0 < dx < w - 1:
                c.set(x0 + dx, y0 + 1, "h")
    c.outline()
    for y in range(c.h):
        for x in range(c.w):
            if (y < 6 or y > 14) and c.get(x, y) != ".":
                c.px[x, y] = (0, 0, 0, 0)
    out.append(c)
    # 2 moss curtain
    c = Canvas(T, T)
    for x in range(1, 15):
        n = 2 + (x * 7 % 5)
        for k in range(n):
            c.set(x, 6 + k, "N" if k < n - 1 else "n")
        if x % 4 == 1:
            c.set(x, 6 + n, "x")
    out.append(c)
    # 3 skull with a mushroom growing out of it
    c = Canvas(T, T)
    for y in range(9, 14):
        for x in range(5, 11):
            if (x - 7.5) ** 2 / 9 + (y - 11) ** 2 / 6 <= 1:
                c.set(x, y, "w" if x < 8 else "m")
    c.set(6, 11, "o")
    c.set(9, 11, "o")
    c.set(7, 13, "e")
    c.set(8, 13, "e")
    for x, y, k in ((9, 8, "m"), (9, 7, "H"), (8, 6, "p"), (9, 6, "H"), (10, 6, "h"), (10, 7, "h")):
        c.set(x, y, k)
    c.outline()
    for y in range(c.h):
        for x in range(c.w):
            if (y < 6 or y > 14) and c.get(x, y) != ".":
                c.px[x, y] = (0, 0, 0, 0)
    out.append(c)
    # 4 glowing mycelium vein running down the bricks
    c = Canvas(T, T)
    path = [(8, 6), (8, 7), (7, 8), (7, 9), (8, 10), (9, 11), (9, 12), (8, 13), (8, 14)]
    for i, (x, y) in enumerate(path):
        c.set(x, y, "x" if i % 3 == 1 else "a")
    for x, y in ((6, 8), (5, 9), (10, 11), (11, 10)):
        c.set(x, y, "a")
    out.append(c)
    for c in out:
        clip_rows(c)
    return row(out)


def fungal_door_seal():
    c = load_slot(f"{TILES}/door_seal.png", 0) if os.path.exists(f"{TILES}/door_seal.png") else Canvas(T, T)
    c = remap(c, {"f": "2", "5": "1", "F": "3"})
    # a tangle of roots over the rubble
    for path in ([(0, 3), (2, 4), (4, 4), (6, 5), (8, 7), (10, 8), (12, 8), (15, 9)],
                 [(1, 12), (3, 11), (5, 10), (7, 9), (9, 10), (11, 12), (13, 13), (15, 13)],
                 [(6, 0), (6, 2), (7, 4), (7, 6), (8, 9), (8, 12), (9, 15)]):
        for (x0, y0), (x1, y1) in zip(path, path[1:]):
            n = max(abs(x1 - x0), abs(y1 - y0))
            for t in range(n + 1):
                x = x0 + (x1 - x0) * t / max(n, 1)
                y = y0 + (y1 - y0) * t / max(n, 1)
                c.set(x, y, "B")
                c.set(x, y + 1, "b")
    for x, y, k in ((3, 3, "x"), (11, 7, "H"), (12, 7, "p"), (5, 9, "x")):
        c.set(x, y, k)
    return c


def fungal_lamp(frame):
    """A cluster of glowing mushrooms on a root bracket on the wall (like torch.png)."""
    c = Canvas(T, T)
    for x, y in ((6, 13), (7, 12), (8, 12), (9, 13), (7, 14), (8, 14)):
        c.set(x, y, "B" if y < 13 else "b")
    glow = ("x", "A", "x", "a")[frame]
    caps = [(5, 9, 4), (9, 8, 4), (7, 6, 5)]
    for i, (cx, top, w) in enumerate(caps):
        for y in range(top + 2, 12):
            c.set(cx + 1, y, "w")
        for dx in range(w):
            c.set(cx - w // 2 + 1 + dx, top, glow if dx < w - 1 else "a")
            c.set(cx - w // 2 + 1 + dx, top + 1, "a" if dx < w - 1 else "j")
        c.set(cx - w // 2 + 1, top, "W" if (frame + i) % 4 == 0 else glow)
    c.outline()
    # spores drifting up
    for i, (x, y) in enumerate(((4, 4), (11, 3), (8, 2))):
        if (frame + i) % 2 == 0:
            c.set(x, y - frame % 2, "x")
    return c


def fungal_obstacles():
    # tall mushroom 16x32
    c = Canvas(16, 32)
    for y in range(13, 31):
        for x in range(6, 10):
            c.set(x, y, "w" if x == 6 else "m" if x < 9 else "T")
    for y in range(28, 31):
        c.set(5, y, "m")
        c.set(10, y, "T")
    for y in range(4, 14):
        half = int(round(7 * math.sqrt(max(0, 1 - ((y - 12) / 8.5) ** 2))))
        for x in range(8 - half, 8 + half):
            lit = (8 - x) / 7 - (y - 8) / 6
            k = "p" if lit > 0.9 else "H" if lit > -0.4 else "h"
            if y == 13:
                k = "h"
            c.set(x, y, k)
    for x, y in ((5, 7), (9, 6), (11, 9), (4, 10), (8, 10)):
        c.set(x, y, "x")
    for x in range(3, 13):
        c.set(x, 14, "m" if x % 2 else "T")   # gills
    c.outline()
    for x in range(4, 13):
        c.set(x, 31, "d")
    tall = c
    # stump 16x16
    c = Canvas(16, 16)
    for y in range(6, 14):
        for x in range(3, 13):
            k = "B" if x < 6 else "b"
            if y == 6:
                k = "c"
            elif y == 7 and 4 < x < 11:
                k = "B" if (x % 3) else "c"
            c.set(x, y, k)
    for x, y in ((2, 13), (13, 13), (2, 12)):
        c.set(x, y, "b")
    for x, y in ((6, 7), (7, 7), (8, 7), (9, 7)):
        c.set(x, y, "u" if x in (7, 8) else "c")  # growth rings
    mushroom(c, 10, 6, 1, 4)
    c.set(4, 10, "x")
    c.set(5, 11, "a")
    c.outline()
    for x in range(3, 14):
        c.set(x, 15, "d")
    stump = c
    # root arch 32x16
    c = Canvas(32, 16)
    for t in range(0, 101):
        a = math.pi * t / 100
        x = 16 - math.cos(a) * 12
        y = 13 - math.sin(a) * 9
        for w in range(-1, 2):
            c.set(x, y + w, "B" if w < 0 else "b")
    for t in range(0, 101, 2):
        a = math.pi * t / 100
        c.set(16 - math.cos(a) * 10, 14 - math.sin(a) * 7, "b")
    for x, y in ((3, 13), (2, 14), (29, 13), (30, 14), (4, 14), (28, 14)):
        c.set(x, y, "b")
    for x, y, k in ((10, 4, "x"), (11, 4, "a"), (20, 4, "H"), (21, 4, "p"), (16, 3, "N"), (17, 3, "N"), (25, 8, "N")):
        c.set(x, y, k)
    c.outline()
    for x in range(2, 31):
        if x < 6 or x > 26:
            c.set(x, 15, "d")
    arch = c
    return tall, stump, arch


# =====================================================================================
# Sand temple
# =====================================================================================

SANDFLOOR = {"f": "7", "F": "8", "5": "6", "n": "6"}


def sand_floor(v):
    c = remap(load_slot(RUINS, v), SANDFLOOR)
    if v == 1:   # sand drifted into the corner
        for x, y in ((0, 12), (1, 12), (0, 13), (1, 13), (2, 13), (0, 14), (1, 14), (2, 14), (3, 14), (4, 14)):
            c.set(x, y, "8")
        c.set(1, 12, "9")
    if v == 2:   # a turquoise tile fragment
        for x, y in ((9, 5), (10, 5), (9, 6), (10, 6)):
            c.set(x, y, "a")
        c.set(11, 7, "6")
    return c


SANDWALL = {"T": "S", "s": "9", "5": "6", "g": "6", "k": "k"}


def sand_wall(src=3, variant=0):
    c = remap(load_slot(RUINS, src), SANDWALL)
    # the lip: a gold line under the top
    for x in range(T):
        if c.get(x, 5) == "9":
            c.set(x, 5, "y" if x % 4 else "Y")
    if variant == 1:   # a band of turquoise tiles with gold edges across the front
        for x in range(T):
            c.set(x, 9, "y")
            c.set(x, 10, "a" if x % 4 else "A")
            c.set(x, 11, "y")
    else:
        for x, y in ((3, 13), (4, 13), (5, 14), (11, 13), (12, 14)):
            c.set(x, y, "8")   # sand heaped at the foot
    return c


def sand_top(src=4):
    c = remap(load_slot(RUINS, src), {"T": "S", "s": "9", "o": "6"})
    for x, y in ((2, 3), (3, 3), (4, 4), (10, 10), (11, 10), (12, 11), (6, 13), (7, 13)):
        c.set(x, y, "D")
    return c


def sand_cover():
    """A sandstone block with a turquoise tile inlay."""
    c = Canvas(T, T)
    for y in range(4, 15):
        for x in range(2, 14):
            k = "S" if y < 7 else "9" if x < 11 else "8"
            if y == 4:
                k = "D"
            if x == 2 and y >= 7:
                k = "S"
            c.set(x, y, k)
    for x in range(4, 12):
        c.set(x, 9, "y")
        c.set(x, 12, "y")
    for x in range(4, 12):
        for y in (10, 11):
            c.set(x, y, "a" if (x + y) % 3 else "A")
    c.outline()
    for x in range(2, 15):
        c.set(x, 15, "d")
    return c


def sand_pit_edge():
    c = remap(load_slot(HAZ, 0), {"T": "S", "s": "9", "5": "8", "f": "7"})
    # sand trickling down into the dark
    for x0 in (4, 11):
        for y in range(6, 12):
            if (y + x0) % 3:
                c.set(x0, y, "9" if y < 9 else "8")
    return c


def quicksand(frame):
    """Sand swirling into the centre; seamless (the swirl is periodic on the tile)."""
    c = Canvas(T, T)
    for y in range(T):
        for x in range(T):
            dx, dy = x + 0.5 - 8, y + 0.5 - 8
            r = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            band = math.sin(a * 3 + r * 0.9 + frame * math.pi / 2)
            # fade the swirl towards the edges so the tile joins its neighbours
            edge = min(x, y, T - 1 - x, T - 1 - y)
            if edge < 2:
                band *= 0.3
            k = "9" if band > 0.55 else "8" if band > -0.2 else "7"
            if r < 1.6:
                k = "6"
            c.set(x, y, k)
    return c


def sand_decals():
    out = []
    # 0 sand drift
    c = Canvas(T, T)
    for y in range(7, 12):
        for x in range(2, 15):
            if (x - 8) ** 2 / 36 + (y - 10) ** 2 / 4 <= 1:
                c.set(x, y, "9" if y < 9 else "8")
    out.append(c)
    # 1 broken turquoise tiles
    c = Canvas(T, T)
    for x, y, k in ((4, 6, "a"), (5, 6, "A"), (4, 7, "a"), (5, 7, "a"), (9, 9, "a"), (10, 9, "a"),
                    (10, 10, "A"), (7, 11, "a"), (6, 4, "y"), (11, 8, "y")):
        c.set(x, y, k)
    out.append(c)
    # 2 pottery shards
    c = Canvas(T, T)
    for x, y, k in ((4, 9, "c"), (5, 9, "B"), (5, 10, "b"), (9, 6, "c"), (10, 6, "c"), (10, 7, "B"),
                    (11, 11, "c"), (12, 11, "B"), (8, 12, "b")):
        c.set(x, y, k)
    out.append(c)
    # 3 old bones half in the sand
    c = Canvas(T, T)
    for x in range(4, 11):
        c.set(x, 8, "w" if x < 8 else "m")
    for x, y in ((3, 7), (3, 9), (11, 7), (11, 9)):
        c.set(x, y, "w")
    for x in range(5, 10):
        c.set(x, 9, "8")
    out.append(c)
    return row(out)


def sand_wall_details():
    out = []
    # 0 hieroglyph panel: an eye and a bird, carved
    c = Canvas(T, T)
    for x, y in ((3, 8), (4, 7), (5, 7), (6, 7), (7, 8), (4, 9), (5, 9), (6, 9)):
        c.set(x, y, "9")
    c.set(5, 8, "a")
    for x, y in ((10, 7), (11, 7), (11, 8), (10, 9), (11, 9), (12, 9), (11, 10), (11, 11), (12, 11)):
        c.set(x, y, "9")
    for x in range(2, 14):
        c.set(x, 13, "y")
    out.append(c)
    # 1 turquoise tile inlay with gold frame
    c = Canvas(T, T)
    for y in range(7, 13):
        for x in range(4, 12):
            k = "Y" if y in (7, 12) or x in (4, 11) else ("a" if (x + y) % 2 else "A")
            c.set(x, y, k)
    c.set(4, 7, "Z")
    out.append(c)
    # 2 sun disc relief in gold
    c = Canvas(T, T)
    for y in range(6, 15):
        for x in range(3, 13):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 10)
            if d <= 2.5:
                c.set(x, y, "Z" if x + y < 18 else "Y")
            elif 3.5 <= d <= 4.3 and (x + y) % 2:
                c.set(x, y, "y")
    out.append(c)
    # 3 torn sand-coloured banner with a turquoise eye
    c = Canvas(T, T)
    for y in range(6, 14):
        for x in range(5, 11):
            if y == 13 and x in (6, 9):
                continue
            c.set(x, y, "S" if x < 7 else "9")
    c.set(7, 9, "a")
    c.set(8, 9, "a")
    c.set(7, 10, "A")
    for x in range(4, 12):
        c.set(x, 6, "y")
    out.append(c)
    # 4 sand pouring from a crack
    c = Canvas(T, T)
    for x, y in ((6, 6), (7, 7), (8, 7), (9, 6)):
        c.set(x, y, "k")
    for y in range(8, 15):
        c.set(7 + (y % 2), y, "D" if y % 3 == 0 else "9")
    for x in range(5, 11):
        c.set(x, 14, "8")
    out.append(c)
    for c in out:
        clip_rows(c)
    return row(out)


def sand_door_seal():
    c = load_slot(f"{TILES}/door_seal.png", 0)
    c = remap(c, {"f": "7", "5": "6", "F": "8", "T": "S", "s": "9", "e": "9", "m": "S"})
    # sand heaped over the rubble
    for y in range(9, 16):
        for x in range(T):
            if y > 13 - int(3 * math.sin(x * 0.4)) + 2:
                c.set(x, y, "8" if y < 14 else "9")
    for x in range(T):
        if c.get(x, 10) in ("8", "9"):
            c.set(x, 10, "D")
    return c


def sand_lamp(frame):
    """A bronze brazier with a warm flame on a wall bracket."""
    c = Canvas(T, T)
    for x in range(4, 12):
        c.set(x, 10, "Y" if x < 7 else "y")
        if 4 < x < 11:
            c.set(x, 11, "y")
    for x in (6, 7, 8, 9):
        c.set(x, 12, "y")
    c.set(7, 13, "b")
    c.set(8, 13, "b")
    c.set(7, 14, "B")
    flame = [(5, 9), (6, 9), (7, 9), (8, 9), (9, 9), (10, 9), (6, 8), (7, 8), (8, 8), (9, 8), (7, 7), (8, 7)]
    tips = [((7, 6), (8, 5)), ((8, 6), (7, 5)), ((7, 6), (6, 5)), ((8, 6), (9, 5))][frame]
    for x, y in flame:
        c.set(x, y, "q" if y == 9 else "Y")
    for x, y in tips:
        c.set(x, y, "q" if y == 5 else "Y")
    c.set(7 + frame % 2, 8, "Z")
    c.outline()
    for i, (x, y) in enumerate(((5, 3), (10, 2))):
        if (frame + i) % 2 == 0:
            c.set(x, y + frame % 2, "Z")
    return c


def sand_obstacles():
    # obelisk 16x32
    c = Canvas(16, 32)
    for y in range(3, 31):
        w = 3 + (y - 3) * 2 // 27
        for x in range(8 - w, 8 + w):
            k = "S" if x < 8 else "9"
            if x == 8 - w:
                k = "D"
            c.set(x, y, k)
    for x, y in ((7, 1), (8, 1), (6, 2), (7, 2), (8, 2), (9, 2)):
        c.set(x, y, "Z" if x < 8 else "Y")   # gold cap
    for y in (8, 12, 16, 20, 24):
        c.set(7, y, "a")
        c.set(8, y, "y")
    for y in range(27, 31):
        for x in range(3, 13):
            c.set(x, y, "8" if x > 9 else "9")
        c.set(3, y, "S")
    c.outline()
    for x in range(3, 14):
        c.set(x, 31, "d")
    obelisk = c
    # urn 16x16
    c = Canvas(16, 16)
    for y in range(3, 14):
        half = [2, 2, 3, 4, 5, 5, 5, 5, 4, 3, 3][y - 3]
        for x in range(8 - half, 8 + half):
            lit = (8 - x) / 5 - (y - 8) / 8
            c.set(x, y, "c" if lit > 0.5 else "B" if lit > -0.4 else "b")
    for x in range(5, 11):
        c.set(x, 8, "a" if x % 2 else "A")
    for x in range(6, 10):
        c.set(x, 3, "y")
    c.set(6, 4, "u")
    c.outline()
    for x in range(4, 13):
        c.set(x, 15, "d")
    urn = c
    # fallen statue 32x16: a sandstone figure on its side, gold mask
    c = Canvas(32, 16)
    for y in range(7, 14):
        for x in range(5, 27):
            if (x - 16) ** 2 / 121 + (y - 10.5) ** 2 / 12.25 <= 1:
                c.set(x, y, "S" if y < 9 else "9" if y < 12 else "8")
    for y in range(5, 13):
        for x in range(24, 31):
            if (x - 27) ** 2 / 9 + (y - 9) ** 2 / 12 <= 1:
                c.set(x, y, "Z" if x < 27 and y < 9 else "Y")
    c.set(26, 9, "o")
    c.set(28, 9, "o")
    for x in range(24, 31):
        c.set(x, 7, "a" if x % 2 else "y")
    for x, y in ((10, 9), (11, 10), (12, 9), (18, 10), (19, 11)):
        c.set(x, y, "8")     # cracks
    for x in range(4, 10):
        c.set(x, 13, "D" if x % 2 else "9")   # sand piled against it
    c.outline()
    for x in range(5, 31):
        c.set(x, 15, "d")
    statue = c
    return obelisk, urn, statue


# =====================================================================================
# floor plates (rows 4 and 5)
# =====================================================================================

def plate(style):
    c = Canvas(64, 16)
    base, top, low, accent, accent2 = {
        "fungal": ("3", "s", "1", "h", "x"),
        "sand": ("9", "S", "8", "a", "A"),
    }[style]
    for y in range(2, 14):
        for x in range(2, 62):
            if x in (2, 61) and y in (2, 13):
                continue
            k = base
            if y == 2 or x == 2:
                k = top
            elif y == 13 or x == 61:
                k = low
            c.set(x, y, k)
    for x in range(5, 59):
        c.set(x, 4, low)
        c.set(x, 11, top)
    for cx in (7, 56):
        for dx, dy in ((0, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (-1, 0), (1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)):
            c.set(cx + dx, 8 + dy, accent)
        c.set(cx, 8, accent2)
        c.set(cx - 1, 7, accent2)
    if style == "fungal":
        for x in (4, 5, 58, 59, 20, 21, 40):
            c.set(x, 12, "N")
        for x0 in (14, 46):     # small mushrooms on the top edge
            c.set(x0, 1, "H")
            c.set(x0 + 1, 1, "p")
            c.set(x0 + 2, 1, "h")
            c.set(x0 + 1, 2, "w")
        for x, n in ((30, 3), (36, 2)):   # roots hanging under it
            for k in range(n):
                c.set(x, 14 + k, "b")
    else:
        for x in range(3, 61):
            if x % 6 in (0, 1):
                c.set(x, 12, "y")
        for x0 in (3, 54):      # sand heaped at the ends
            for x in range(x0, x0 + 7):
                c.set(x, 13, "D" if x % 2 else "8")
    c.outline()
    return c


def floor_plates():
    path = "assets/art/ui/floor_plates.png"
    old = Image.open(path).convert("RGBA")
    out = Image.new("RGBA", (64, 80))
    out.paste(old.crop((0, 0, 64, 48)), (0, 0))
    out.paste(plate("fungal").img, (0, 48))
    out.paste(plate("sand").img, (0, 64))
    out.save(path)


def main():
    blank = Canvas(T, T)
    # fungal
    row([fungal_floor(i) for i in range(3)] + [fungal_wall(3, 0), fungal_top(4), fungal_cover(),
        fungal_wall(6, 0), fungal_top(7), fungal_wall(3, 1)]).save(f"{TILES}/fungal_tiles_atlas.png")
    row([fungal_pit_edge(), thorn_spikes(), spore_floor_still(), blank, blank, blank, blank,
         fungal_pit_inner()]).save(f"{TILES}/fungal_hazards.png")
    fungal_decals().save(f"{TILES}/fungal_decals.png")
    fungal_wall_details().save(f"{TILES}/fungal_wall_details.png")
    fungal_door_seal().img.save(f"{TILES}/fungal_door_seal.png")
    row([fungal_lamp(i) for i in range(4)]).save(f"{LEVEL}/fungal_lamp.png")
    tall, stump, arch = fungal_obstacles()
    tall.img.save(f"{LEVEL}/fungal_obstacle_mushroom_tall.png")
    stump.img.save(f"{LEVEL}/fungal_obstacle_stump.png")
    arch.img.save(f"{LEVEL}/fungal_obstacle_root_arch.png")
    spore_puff().save(f"{LEVEL}/spore_puff.png")
    strip([spore_cloud(i).img for i in range(6)]).save("assets/art/fx/spore_cloud.png")
    # sand
    row([sand_floor(i) for i in range(3)] + [sand_wall(3, 0), sand_top(4), sand_cover(),
        sand_wall(6, 0), sand_top(7), sand_wall(3, 1)]).save(f"{TILES}/sand_tiles_atlas.png")
    sp = remap(load_slot(HAZ, 1), {"f": "7", "5": "6"})
    row([sand_pit_edge(), sp, quicksand(0), blank, blank, blank, blank,
         load_slot(HAZ, 7)]).save(f"{TILES}/sand_hazards.png")
    row([quicksand(i) for i in range(4)]).save(f"{TILES}/sand_quicksand.png")
    sand_decals().save(f"{TILES}/sand_decals.png")
    sand_wall_details().save(f"{TILES}/sand_wall_details.png")
    sand_door_seal().img.save(f"{TILES}/sand_door_seal.png")
    row([sand_lamp(i) for i in range(4)]).save(f"{LEVEL}/sand_lamp.png")
    obelisk, urn, statue = sand_obstacles()
    obelisk.img.save(f"{LEVEL}/sand_obstacle_obelisk.png")
    urn.img.save(f"{LEVEL}/sand_obstacle_urn.png")
    statue.img.save(f"{LEVEL}/sand_obstacle_fallen_statue.png")
    floor_plates()
    print("biome tiles done")


if __name__ == "__main__":
    main()
