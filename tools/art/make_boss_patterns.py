"""Batch 18: attack patterns of the bosses (the Mycelium Mother; the Sand Pharaoh's pieces
come later in the same file). docs/art-style.md palette plus the theme colours of
make_batch15.PAL; the Mother's own colours: bark #7a4a2c / #4a2f22 / #b07040, moss #5a8a4a /
#3b5a45 / #8ac060, violet #9a5ae0 / #d0a0f0, mint glow #6ae0c0 / #9af0e0.

Output (all strips of frames in a row, assets/art/fx/):
  mother_vine.png      16x16 x 4, loop: a piece of the long vine, seamless left-right
                       (tile it along x, rotate for the direction). Centre line row 8, the
                       vine sways +-1 px; frame i of the tip continues frame i of the segment.
  mother_vine_tip.png  16x16 x 4, loop: the vine's end, attached on the left, point at x 13.
  line_warn.png        16x16 x 2, loop: a glowing crack along the line about to be hit,
                       seamless left-right, crack on rows 7-8, dashed lane edges rows 1 / 14.
                       Mint glow inside a black rim: reads on the fungal and the sand floor.
  spore_cell_warn.png  16x16 x 3, once (hold the last frame): spores light up on the floor
                       cell, sparse -> dense, corner marks on frame 2.
  spore_burst.png      16x16 x 4, once: the spores burst out of the cell, centre (8, 8).
Run from the project root: python tools/art/make_boss_patterns.py
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_batch15 import Canvas, strip  # noqa: E402

FX = "assets/art/fx"
T = 16


def crop(c, x0):
    return c.img.crop((x0, 0, x0 + T, T))


# --- the Mother's vine -----------------------------------------------------------------

def vine_centre(x, frame):
    """Centre line of the vine: a sine with the period of one tile, so every frame is
    seamless; the phase moves a quarter period per frame (the vine sways)."""
    return 7.5 + 1.3 * math.sin(math.tau * (x % T) / T + frame * math.pi / 2)


def vine_column(c, x, frame, half):
    """Draws one column of the vine with the given half thickness (3 = full)."""
    xm = x % T
    yc = vine_centre(x, frame)
    top, bot = round(yc - half), round(yc + half)
    if bot < top:
        return
    for y in range(top, bot + 1):
        depth = y - top
        k = "B"
        if (xm + 2 * depth) % 7 == 0 and 0 < depth < bot - top:
            k = "b"                              # twisted grooves of the bark
        if depth == 0:
            k = "c"                              # lit upper edge
        if y >= bot - 1 and bot - top >= 3:
            k = "b"                              # shaded underside
        if y == bot and bot - top >= 5 and xm % 5 == 2:
            k = "y"                              # warm glint under the bark
        c.set(x, y, k)
    if half >= 2.5:
        if xm in (2, 3, 4):                      # moss pad on the top
            c.set(x, top, "V" if xm == 3 else "G")
            c.set(x, top + 1, "G")
            if xm == 3:
                c.set(x, top - 1, "G")
        if xm in (10, 11):                       # mint glowing nodule on the flank
            c.set(x, top + 3, "x" if xm == 10 else "a")
            c.set(x, top + 2, "A" if xm == 10 else "x")
        if xm == 13:                             # thorn down
            c.set(x, bot + 1, "b")
            c.set(x + 1, bot + 2, "b")
        if xm == 7:                              # thorn up, violet tip
            c.set(x, top - 1, "B")
            c.set(x - 1, top - 2, "H")


def vine_frames():
    segs, tips = [], []
    for f in range(4):
        c = Canvas(3 * T, T)
        for x in range(3 * T):
            vine_column(c, x, f, 3)
        c.outline()
        segs.append(crop(c, T))

        c = Canvas(3 * T, T)
        for x in range(T, 2 * T):
            vine_column(c, x, f, 3)
        for x in range(2 * T, 2 * T + 14):       # the tip: tapers over 13 px, curls up
            t = (x - 2 * T) / 13
            half = 3 * (1 - t ** 1.4)
            xm = x % T
            yc = vine_centre(x, f) - 2.2 * t * t
            top, bot = round(yc - half), round(yc + half)
            for y in range(top, bot + 1):
                depth = y - top
                k = "c" if depth == 0 else "b" if y >= bot - (1 if bot - top >= 3 else 0) else "B"
                c.set(x, y, k)
            if xm == 2:                          # moss pad, like the segment
                c.set(x, top, "G")
            if xm == 5:                          # a rootlet splitting off downwards
                for i in range(3):
                    c.set(x + i, round(yc + half) + 1 + (i > 0), "b")
            if 9 <= xm <= 11 and f % 2 == 0:
                c.set(x, round(yc), "x")        # mint glow runs to the point
        tip = round(vine_centre(2 * T + 13, f) - 2.2)
        c.set(2 * T + 13, tip, "H")              # violet point
        c.set(2 * T + 14, tip - 1, "p")
        c.outline()
        tips.append(crop(c, 2 * T))
    return strip(segs), strip(tips)


# --- line warning ----------------------------------------------------------------------

JAG = [0, 0, 1, 1, 1, 0, 0, -1, -1, 0, 0, 0, 1, 0, 0, 0]   # crack wander, period 16


def line_warn(frame):
    c = Canvas(3 * T, T)
    rnd = random.Random(5)
    for x in range(3 * T):
        xm = x % T
        y0 = 7 + JAG[xm]
        c.set(x, y0, "A" if frame else "x")
        c.set(x, y0 + 1, "x" if frame else "a")
        if xm in (4, 5) or xm in (11,):          # wider spots of the crack
            c.set(x, y0 - 1 if xm != 11 else y0 + 2, "x" if frame else "a")
    for x0, dy, n in ((3 * 1 + T, -1, 3), (9 + T, 1, 3)):   # little side cracks
        for i in range(n):
            for xx in (x0 + i - T, x0 + i, x0 + i + T):
                y = 7 + JAG[(x0 + i) % T] + (dy * (i + 2) if dy < 0 else 1 + dy * (i + 2))
                c.set(xx, y, "a" if i < n - 1 or frame else "x")
    c.outline(skip=())
    for x in range(3 * T):                       # earth lips over the rim
        xm = x % T
        y0 = 7 + JAG[xm]
        for y in (y0 - 2, y0 + 3):
            if c.get(x, y) == "." and xm % 3 != 1:
                c.set(x, y, "3")
    for x in range(3 * T):                       # dashed lane edges, moving on frame 1
        xm = x % T
        if (xm + frame * 2) % 4 < 2:
            c.set(x, 1, "a")
            c.set(x, 14, "a")
    motes = [(rnd.randrange(T), rnd.choice((3, 4, 5, 10, 11, 12))) for _ in range(6)]
    for i, (x, y) in enumerate(motes):           # glow motes over the lane, flickering
        if (i + frame) % 2 == 0 and c.get(x + T, y) == ".":
            for xx in (x, x + T, x + 2 * T):
                c.set(xx, y, "x" if i % 3 else "A")
    return crop(c, T)


# --- spore field cell ------------------------------------------------------------------

def spore(c, x, y, size):
    if size == 0:
        c.set(x, y, "G")
    elif size == 1:
        c.set(x, y, "V")
        c.set(x, y + 1, "N")
    else:
        for dx, dy in ((1, 0), (-1, 0), (0, -1)):
            c.set(x + dx, y + dy, "V")
        c.set(x, y + 1, "N")
        c.set(x, y, "v")


def spore_cell_warn(frame):
    c = Canvas(T, T)
    rnd = random.Random(41)
    # the floor of the cell glows: a green patch from the centre, the whole cell on frame 2
    reach = (2.5, 4.5, 99)[frame]
    for y in range(1, T - 1):
        for x in range(1, T - 1):
            if math.hypot(x - 7.5, y - 7.5) <= reach:
                c.set(x, y, "N")
    spots = []                                   # spores on a jittered 4 px grid
    for gy in range(4):
        for gx in range(4):
            x, y = 2 + gx * 4 + rnd.randint(-1, 1), 2 + gy * 4 + rnd.randint(-1, 1)
            d = math.hypot(x - 7.5, y - 7.5)
            appear = 0 if d < 3.5 else 1 if d < 5.5 else 2   # grows from the centre out
            spots.append((x, y, appear, rnd.random()))
    for x, y, appear, r in spots:
        if appear > frame:
            continue
        age = frame - appear
        size = min(2, age + (1 if r < 0.4 else 0))
        spore(c, x, y, size)
        if frame == 2 and r > 0.85:
            c.set(x, y, "p")                     # violet sparks among them
    if frame == 2:                               # corner marks: where the cell ends
        for cx, cy, sx, sy in ((0, 0, 1, 1), (15, 0, -1, 1), (0, 15, 1, -1), (15, 15, -1, -1)):
            for i in range(3):
                c.set(cx + sx * i, cy, "V")
                c.set(cx, cy + sy * i, "V")
            c.set(cx, cy, "v")
    return c.img


def spore_burst(frame):
    c = Canvas(T, T)
    rnd = random.Random(73 + frame)
    cx, cy = 7.5, 8.5 - frame * 0.6
    radius = (3.2, 6.0, 7.0, 7.4)[frame]
    puffs = [(cx, cy, radius * 0.7)]
    for i in range(7):                           # lumpy cloud: a ring of round puffs
        a = i * math.tau / 7 + frame * 0.3
        puffs.append((cx + math.cos(a) * radius * 0.55, cy + math.sin(a) * radius * 0.5,
                      radius * (0.42 if frame < 2 else 0.3)))
    if frame == 3:
        puffs = puffs[1::2]
    holes = random.Random(91)
    for y in range(T):
        for x in range(T):
            px, py = x + 0.5, y + 0.5
            inside = [r - math.hypot(px - ax, py - ay) for ax, ay, r in puffs]
            best = max(inside)
            if best < 0:
                continue
            if frame >= 2 and holes.random() < 0.22:
                continue                         # the cloud thins out
            dx, dy = px - cx, py - cy
            lit = -dx - dy                       # light from the top-left
            k = "V" if lit > 1 else "G"
            if best > 1.4 and frame < 2:
                k = "v" if lit > -1 else "V"
            if frame == 3:
                k = "G" if lit < 2 else "V"
            c.set(x, y, k)
    if frame < 3:
        c.outline(skip=())
        for y in range(T):                       # gas: a dark green rim, not black
            for x in range(T):
                if c.get(x, y) == "o":
                    c.set(x, y, "N")
    for i in range(3 + frame * 2):               # violet sparks and loose spores
        a = rnd.uniform(0, math.tau)
        rr = radius + rnd.uniform(-1, 1.2)
        x, y = cx + math.cos(a) * rr, cy + math.sin(a) * rr * 0.9
        c.set(x, y, "p" if i % 3 == 0 else "H" if i % 3 == 1 else "v")
    if frame == 0:
        c.set(7, 8, "W")
        c.set(8, 8, "v")
    return c.img


def main():
    seg, tip = vine_frames()
    seg.save(f"{FX}/mother_vine.png")
    tip.save(f"{FX}/mother_vine_tip.png")
    strip([line_warn(i) for i in range(2)]).save(f"{FX}/line_warn.png")
    strip([spore_cell_warn(i) for i in range(3)]).save(f"{FX}/spore_cell_warn.png")
    strip([spore_burst(i) for i in range(4)]).save(f"{FX}/spore_burst.png")
    print("batch 18: mother_vine, mother_vine_tip, line_warn, spore_cell_warn, spore_burst")


if __name__ == "__main__":
    main()
