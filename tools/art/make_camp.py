"""The camp at the entrance to the ruins (plan group 2), in the nature theme of
docs/art-style.md (32-colour palette plus its greens and warm stones):
- Camp tiles, 16x16, one atlas row like ruins_tiles_atlas.png:
  assets/art/tiles/camp_tiles_atlas.png, slots 0-1 grass, 2 dirt path, 3 path with
  grass, 4 pebbles on grass, 5 boulder on grass (cover), 6 cliff front, 7 cliff top.
- Entrance to the ruins, 48x32: a stone arch in a rock face, dark inside:
  assets/art/level/ruins_entrance.png
- Campfire 16x16, 4 frames loop: assets/art/level/campfire.png
- Tent 32x32: assets/art/level/tent.png
- Skill altar 32x32, 4 frames glow loop: assets/art/level/altar.png
- Spell library shelf 32x24: assets/art/level/spell_shelf.png
Run from the project root: python tools/art/make_camp.py
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_world_props as wp  # noqa: E402
from make_world_props import Grid, TORCH_FLAMES  # noqa: E402

# Nature theme colours (docs/art-style.md, "Nature theme").
wp.P.update({"G": "#5a8a4a", "V": "#8ac060", "w": "#8a8466", "v": "#6a6656", "X": "#9a9470", "x": "#c8c088"})

TILES = "assets/art/tiles"
LEVEL = "assets/art/level"


def strip(frames, w, h):
    img = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        img.paste(f, (w * i, 0))
    return img


def grass(seed, flowers=0):
    rng = random.Random(seed)
    g = Grid(16, 16)
    g.rect(0, 0, 15, 15, "G")
    for _ in range(9):
        x, y = rng.randrange(16), rng.randrange(16)
        g.set(x, y, "V")
        if y + 1 < 16:
            g.set(x, (y + 1) % 16, "N")
    for _ in range(flowers):
        x, y = rng.randrange(1, 15), rng.randrange(1, 15)
        g.set(x, y, rng.choice("Zqx"))
        g.set(x, y + 1, "N")
    return g


def path(seed, tufts):
    rng = random.Random(seed)
    g = Grid(16, 16)
    g.rect(0, 0, 15, 15, "v")
    for _ in range(10):
        x, y = rng.randrange(16), rng.randrange(16)
        g.set(x, y, "w")
        g.set((x + 1) % 16, (y + 1) % 16, "b")
    for _ in range(tufts):
        x, y = rng.randrange(16), rng.randrange(16)
        for dx, dy, key in ((0, 0, "G"), (1, 0, "V"), (0, 1, "N"), (1, 1, "G")):
            g.set((x + dx) % 16, (y + dy) % 16, key)
    return g


def pebbles():
    g = grass(7)
    for x, y in ((3, 4), (10, 3), (6, 10), (12, 11)):
        g.set(x, y, "x")
        g.set(x + 1, y, "w")
        g.set(x, y + 1, "w")
        g.set(x + 1, y + 1, "v")
        g.set(x, y + 2, "N")
        g.set(x + 1, y + 2, "N")
    return g


def boulder():
    g = grass(11)
    cx, cy, rx, ry = 8.0, 8.5, 6.5, 5.5
    inside = set()
    for y in range(16):
        for x in range(16):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1.0:
                inside.add((x, y))
    for x, y in inside:
        dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
        g.set(x, y, "x" if dx + dy < -0.7 else "w" if dx + dy < 0.4 else "v")
    for x, y in ((6, 4), (7, 4), (8, 4), (7, 5)):
        g.set(x, y, "G")
    g.set(6, 3, "V")
    for x, y in inside:
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) not in inside and 0 <= nx < 16 and 0 <= ny < 16:
                g.set(nx, ny, "o")
    for x in range(3, 14):
        if g.get(x, 15) != "o":
            g.set(x, 15, "N")
    return g


def cliff_front():
    g = Grid(16, 16)
    g.rect(0, 0, 15, 15, "v")
    g.rect(0, 0, 15, 0, "w")
    for y0, x0 in ((1, 0), (6, 5), (11, 2)):
        g.rect(x0, y0, x0 + 5, y0, "w")
        g.set(x0, y0 + 1, "w")
    for x, y in ((6, 1), (6, 2), (7, 3), (11, 6), (12, 7), (12, 8), (3, 11), (2, 12), (13, 12), (13, 13)):
        g.set(x, y, "k")
    for x in (1, 9, 14):
        g.set(x, 2, "G")
        g.set(x, 3, "N")
    g.rect(0, 15, 15, 15, "o")
    return g


def cliff_top():
    g = grass(21)
    g.rect(0, 15, 15, 15, "w")
    for x in (2, 3, 9, 10, 11):
        g.set(x, 14, "w")
        g.set(x, 13, "x")
    return g


def camp_atlas():
    tiles = [grass(1), grass(2, flowers=2), path(3, 0), path(4, 3), pebbles(), boulder(), cliff_front(), cliff_top()]
    return strip([t.image() for t in tiles], 16, 16)


def ruins_entrance():
    """A rock face with a ruined stone arch, darkness inside, vines over it."""
    w, h, cx = 48, 32, 23.5
    g = Grid(w, h)
    # Rock mass with an uneven top.
    rng = random.Random(5)
    tops = [int(3 + 2 * math.sin(x * 0.35) + rng.random() * 1.5) for x in range(w)]
    for x in range(w):
        for y in range(tops[x], 30):
            g.set(x, y, "w" if y < tops[x] + 2 else "v")
        g.set(x, tops[x], "x")
    for x, y in ((5, 9), (6, 10), (6, 11), (40, 8), (41, 9), (42, 9), (8, 20), (9, 21), (38, 19), (39, 20)):
        g.set(x, y, "k")
    # The arch: a half circle on jambs, stones lit from the top-left.
    arch_y, inner, outer = 17, 9.5, 13.5

    def in_shape(x, y, r):
        dx = x - cx
        if y > 29:
            return False
        if y >= arch_y:
            return abs(dx) <= r
        return dx * dx + (y - arch_y) ** 2 <= r * r

    for y in range(h):
        for x in range(w):
            if in_shape(x, y, outer) and not in_shape(x, y, inner):
                key = "S"
                if not in_shape(x, y - 1, outer):
                    key = "T"
                elif in_shape(x, y + 1, inner) or in_shape(x + 1, y, inner) or in_shape(x - 1, y, inner):
                    key = "e"
                if y < arch_y:
                    ang = math.atan2(arch_y - y + 0.5, x - cx)
                    step = math.pi / 6
                    if abs(ang / step - round(ang / step)) * step * 11 < 0.5 and 0 < round(ang / step) < 6:
                        key = "k"
                elif y in (arch_y + 4, arch_y + 8):
                    key = "k"
                g.set(x, y, key)
            elif in_shape(x, y, inner):
                # Darkness: black, a faint floor going in near the bottom.
                g.set(x, y, "k" if y >= 26 and abs(x - cx) < 6 else "o")
    # Vines hanging over the arch.
    for x0, length in ((14, 7), (17, 4), (29, 6), (32, 9)):
        for k in range(length):
            y = tops[x0] + 1 + k + (arch_y - 13 if x0 in (17, 29) else 0)
            if 0 <= y < 30:
                g.set(x0 + (k // 3) % 2, y, "G" if k % 2 else "N")
        g.set(x0, tops[x0] + length, "V")
    g.rect(13, 29, 34, 29, "e")
    g.outline()
    g.rect(1, 31, 46, 31, "d")
    return g


def campfire():
    frames = []
    for flame in TORCH_FLAMES:
        rows = flame.strip("\n").splitlines()
        g = Grid(16, 16)
        # Flame (rows 2..8 of the torch flame), lowered by 2 px.
        for y, line in enumerate(rows):
            for x, key in enumerate(line):
                if key != "." and y + 2 < 12:
                    g.set(x + 1, y + 2, key)
        # Logs.
        for x in range(3, 13):
            g.set(x, 11, "B" if x % 3 else "b")
            g.set(x, 12, "b")
        # Ring of stones.
        for x, y in ((2, 12), (4, 13), (7, 14), (10, 14), (12, 13), (13, 12)):
            g.set(x, y, "m")
            g.set(x + 1, y, "T")
        g.outline()
        g.rect(3, 15, 12, 15, "d")
        frames.append(g.image())
    return strip(frames, 16, 16)


def tent():
    g = Grid(32, 32)
    apex, base_y = (11, 5), 27
    # Side roof (seen to the right): from the ridge going back.
    for y in range(5, base_y + 1):
        t = (y - 5) / (base_y - 5)
        x0 = int(round(11 + (21 - 11) * t))
        x1 = int(round(23 + (29 - 23) * t))
        for x in range(x0, x1 + 1):
            g.set(x, y, "c" if (x + y) % 7 else "B")
    for y in range(5, base_y + 1):
        t = (y - 5) / (base_y - 5)
        g.set(int(round(23 + (29 - 23) * t)), y, "B")
    # Front face: a triangle, lit, with a dark opening.
    for y in range(5, base_y + 1):
        half = (y - 5) * 10 / (base_y - 5)
        for x in range(int(round(11 - half)), int(round(11 + half)) + 1):
            g.set(x, y, "u")
        g.set(int(round(11 + half)), y, "c")
    for y in range(14, base_y + 1):
        half = (y - 14) * 3.5 / (base_y - 14)
        for x in range(int(round(11 - half)), int(round(11 + half)) + 1):
            g.set(x, y, "o" if y > 16 else "k")
    # Pole tip and a pennant.
    g.set(11, 4, "B")
    g.set(11, 3, "B")
    g.set(11, 2, "B")
    g.set(12, 2, "q")
    g.set(13, 2, "q")
    g.set(12, 3, "R")
    g.outline()
    # Guy ropes and pegs.
    for x, y in ((1, 25), (2, 24), (3, 23), (30, 23), (31, 24)):
        g.set(x, y, "m")
    g.rect(2, 29, 30, 29, "d")
    return g


def altar(frame):
    """Stone pedestal with a golden rune ring hovering over it; the glow pulses."""
    g = Grid(32, 32)
    # Pedestal: top face, front, wider base.
    g.rect(8, 16, 23, 17, "T")
    g.rect(8, 18, 23, 18, "S")
    g.rect(10, 19, 21, 26, "S")
    g.rect(10, 19, 10, 26, "T")
    g.rect(21, 19, 21, 26, "e")
    g.rect(7, 27, 24, 29, "S")
    g.rect(7, 27, 24, 27, "T")
    g.rect(24, 28, 24, 29, "e")
    for x, y in ((14, 21), (15, 22), (16, 22), (17, 21), (15, 23), (16, 23)):
        g.set(x, y, "y" if frame % 2 else "Y")
    # Hovering rune ring, bobbing.
    bob = [0, -1, -1, 0][frame]
    bright = frame in (1, 2)
    cx, cy = 15.5, 10.0 + bob
    for y in range(32):
        for x in range(32):
            d = math.hypot((x + 0.5 - cx), (y + 0.5 - cy) * 1.6)
            if 5.0 <= d <= 6.6:
                ang = math.atan2(y + 0.5 - cy, x + 0.5 - cx)
                g.set(x, y, "Z" if (bright and ang < -1.0) else "Y" if int((ang + math.pi) * 3) % 2 else "y")
    g.outline()
    # A four-pointed star in the ring, glowing (no outline).
    sx, sy = 15, int(round(cy)) - 1
    for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1), (0, -1), (1, -1), (0, 2), (1, 2), (-1, 0), (-1, 1), (2, 0), (2, 1)):
        g.set(sx + dx, sy + dy, "Z" if (dx, dy) in ((0, 0), (1, 0), (0, 1), (1, 1)) or bright else "Y")
    # Sparks and glow on the top face (no outline).
    sparks = [[(9, 6), (22, 12)], [(21, 4), (10, 13)], [(8, 9), (23, 7)], [(20, 13), (11, 5)]][frame]
    for x, y in sparks:
        g.set(x, y, "Z")
    for x in range(13, 19):
        g.set(x, 16, "Z" if bright else "Y")
    g.rect(7, 31, 24, 31, "d")
    return g


def spell_shelf():
    g = Grid(32, 24)
    g.rect(2, 2, 29, 21, "B")
    g.rect(2, 2, 29, 2, "c")
    g.rect(2, 2, 2, 21, "c")
    g.rect(29, 3, 29, 21, "b")
    for y0 in (3, 11):
        g.rect(4, y0, 27, y0 + 6, "k")
        g.rect(3, y0 + 7, 28, y0 + 7, "b")
    # Books: (x, width, height, colour light, colour dark).
    books = [(4, 2, 6, "R", "r"), (6, 2, 5, "l", "j"), (8, 1, 6, "N", "n"), (9, 2, 4, "Y", "y"), (13, 2, 6, "H", "h"),
             (15, 2, 5, "R", "r"), (19, 2, 6, "l", "j"), (21, 1, 5, "c", "B"), (22, 2, 6, "N", "n")]
    for row, y0 in enumerate((3, 11)):
        for i, (x, bw, bh, light, dark) in enumerate(books):
            xs = x + (row * 3 + i) % 2 if row else x
            if xs + bw > 27:
                continue
            g.rect(xs, y0 + 6 - bh + 1, xs + bw - 1, y0 + 6, dark)
            g.rect(xs, y0 + 6 - bh + 1, xs, y0 + 6, light)
    # A scroll lying on the lower shelf and a violet orb on the upper one.
    g.rect(24, 16, 27, 17, "W")
    g.set(24, 16, "U")
    g.set(27, 17, "m")
    for x, y, key in ((24, 7, "H"), (25, 7, "H"), (24, 8, "h"), (25, 8, "H"), (24, 6, "U"), (25, 6, "H"), (23, 8, "h"), (26, 8, "h"),
                      (24, 9, "B"), (25, 9, "B")):
        g.set(x, y, key)
    g.outline()
    g.rect(3, 23, 28, 23, "d")
    return g


def main():
    os.makedirs(TILES, exist_ok=True)
    os.makedirs(LEVEL, exist_ok=True)
    camp_atlas().save(f"{TILES}/camp_tiles_atlas.png")
    ruins_entrance().image().save(f"{LEVEL}/ruins_entrance.png")
    campfire().save(f"{LEVEL}/campfire.png")
    tent().image().save(f"{LEVEL}/tent.png")
    strip([altar(i).image() for i in range(4)], 32, 32).save(f"{LEVEL}/altar.png")
    spell_shelf().image().save(f"{LEVEL}/spell_shelf.png")


if __name__ == "__main__":
    main()
