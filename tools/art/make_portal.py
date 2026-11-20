"""Portals (batch 10, group 3; docs/art-style.md palette).

Boss portal, 32x48, front view: a rectangular stone frame that rises out of the floor
after the boss dies. The base stands on rows 42-45, outline row 46, shadow row 47; the
frame's centre column is x 15.5 (opening x 9-22, y 11-41).
- Rise, 8 frames (play once, 10 fps): 0 purple cracks in the floor, 1 the slabs break
  and fall in, the slot glows, 2-4 the frame rises out of the slot (lintel, half, nearly all)
  with dust, 5 the frame stands dark, 6 the runes light up and a spark appears inside,
  7 the glow spreads: assets/art/level/portal_rise.png (256x48)
- Loop, 4 frames (8 fps): purple light ripples out from the centre, runes pulse,
  sparks rise: assets/art/level/portal_loop.png (128x48)

Free-standing gate, 48x32: the arch of gate_*.png without the brick pillars at its
sides, on its own footing, for arenas without a boss. Threshold row 29, shadow rows
30-31: assets/art/level/gate_free_closed.png (1 frame), gate_free_open.png (4 frames).
Run from the project root: python tools/art/make_portal.py
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_world_props as wp  # noqa: E402
from make_world_props import Grid  # noqa: E402

LEVEL = "assets/art/level"
PW, PH = 32, 48
CX = 15.5
OPEN_X0, OPEN_X1, OPEN_Y0, OPEN_Y1 = 9, 22, 11, 41
BASE_Y = 45  # last row of the frame's base; outline row 46, shadow row 47
SLOT_X0, SLOT_X1 = 1, 30

# Runes on the posts and the keystone: (x, y) pixels per glyph.
RUNES = [
    [(6, 16), (6, 17), (6, 18), (7, 17)],
    [(6, 26), (7, 25), (7, 26), (7, 27)],
    [(6, 34), (7, 34), (6, 35)],
    [(25, 18), (25, 19), (24, 19), (25, 20)],
    [(24, 28), (25, 28), (24, 29), (24, 30)],
    [(25, 35), (24, 36), (25, 36)],
    [(15, 7), (16, 7), (15, 8), (16, 8)],
]


def frame_grid(rune_key):
    """The stone frame, fully risen, without the inside of the opening."""
    g = Grid(PW, PH)
    # Lintel: top face rows 3-5, front face rows 6-10.
    for y in range(3, 11):
        for x in range(2, 30):
            if y == 3:
                k = "T"
            elif y <= 5:
                k = "T" if x < 28 else "S"
            elif y == 10:
                k = "e"
            else:
                k = "S" if x > 2 else "T"
            g.set(x, y, k)
    g.rect(2, 6, 29, 6, "S")
    for x in (8, 23):
        g.rect(x, 7, x, 9, "k")
    g.rect(12, 6, 19, 10, "S")
    g.rect(12, 6, 12, 10, "T")
    g.rect(19, 6, 19, 10, "e")
    # Posts.
    for x0, x1 in ((4, 8), (23, 27)):
        for y in range(11, 42):
            for x in range(x0, x1 + 1):
                g.set(x, y, "T" if x == x0 else "e" if x == x1 else "S")
        for y in (17, 24, 31, 37):
            g.rect(x0, y, x1, y, "k")
    # Base: a wide step, top face row 42, front rows 43-45.
    for y in range(42, BASE_Y + 1):
        for x in range(2, 30):
            g.set(x, y, "T" if y == 42 else "e" if y == BASE_Y else "S")
    g.rect(OPEN_X0, 42, OPEN_X1, 42, "e")
    for x in (8, 23):
        g.rect(x, 43, x, BASE_Y, "k")
    for rune in RUNES:
        for x, y in rune:
            g.set(x, y, rune_key)
    # Cracks and moss.
    for x, y, k in ((27, 13, "k"), (26, 14, "k"), (26, 15, "k"), (3, 44, "N"), (4, 44, "n"),
                    (4, 41, "N"), (5, 41, "n"), (29, 5, "e")):
        g.set(x, y, k)
    return g


def fill_opening(g, glow, phase):
    """glow: 0 dark, 1 spark, 2 small glow, 3 full light; phase 0..3 for the loop."""
    hw = (OPEN_X1 - OPEN_X0 + 1) / 2.0
    hh = (OPEN_Y1 - OPEN_Y0 + 1) / 2.0
    cy = OPEN_Y0 + hh - 0.5
    for y in range(OPEN_Y0, OPEN_Y1 + 1):
        for x in range(OPEN_X0, OPEN_X1 + 1):
            dx, dy = abs(x - CX) / hw, abs(y - cy) / hh
            r = max(dx, dy * 0.9) * 0.6 + math.hypot(dx, dy * 0.9) * 0.4  # rounded rectangle
            if glow == 0:
                k = "d"
            elif glow == 1:
                k = "U" if r < 0.08 else "H" if r < 0.17 else "h" if r < 0.28 else "d"
            elif glow == 2:
                k = "U" if r < 0.14 else "H" if r < 0.34 else "h" if r < 0.6 else "d"
            else:
                band = ((r * 3.0 - phase / 4.0) % 1.0) < 0.42
                level = int((1.0 - r) * 2.2 + (1.0 if band else 0.0) - 0.1)
                if r < 0.16:
                    level = 3
                k = "dhHU"[max(0, min(level, 3))]
            g.set(x, y, k)
    # Shadow under the lintel on the opening's top row.
    for x in range(OPEN_X0, OPEN_X1 + 1):
        if g.get(x, OPEN_Y0) in ("d", "h"):
            g.set(x, OPEN_Y0, "o")


def slot(g, state):
    """The floor in front of the base. state 0: slabs closed with glowing cracks,
    1: the slabs broke and fell in, the slot glows; 2: the frame stands in it."""
    if state == 0:
        for y in range(42, 47):
            for x in range(SLOT_X0, SLOT_X1 + 1):
                g.set(x, y, "f")
        for x in range(SLOT_X0, SLOT_X1 + 1):
            g.set(x, 42, "s")
            g.set(x, 46, "s")
        for y in range(42, 47):
            g.set(SLOT_X0, y, "s")
            g.set(SLOT_X1, y, "s")
            g.set(15, y, "s")
            g.set(16, y, "s")
        for x, y in ((15, 43), (16, 44), (15, 45), (10, 44), (11, 44), (21, 43), (20, 44), (16, 46), (15, 46)):
            g.set(x, y, "H")
        for x, y in ((9, 44), (12, 45), (22, 43), (19, 44), (14, 43), (17, 45)):
            g.set(x, y, "h")
        return
    if state == 1:
        for y in range(43, 47):
            for x in range(SLOT_X0 + 1, SLOT_X1):
                g.set(x, y, "o" if y < 45 else "h" if y == 45 else "s")
        for x in range(SLOT_X0, SLOT_X1 + 1):
            g.set(x, 42, "s")
        for x in range(SLOT_X0 + 3, SLOT_X1 - 2, 3):
            g.set(x, 45, "H")
    # Broken slab edges on both lips of the slot.
    for x, y, k in ((1, 42, "e"), (2, 42, "e"), (3, 42, "s"), (28, 42, "s"), (29, 42, "e"), (30, 42, "e"),
                    (8, 42, "e"), (9, 42, "e"), (21, 42, "e"), (22, 42, "e")):
        if g.get(x, y) == ".":
            g.set(x, y, k)


def shadow(g):
    for x in range(3, 32):
        g.set(x, 47, "d")


def portal_frame(rise, glow, phase=0, rune="h", slot_state=2, dust=False):
    """rise: rows the frame is still sunk below the floor (0 = fully up, None = hidden)."""
    g = Grid(PW, PH)
    slot(g, slot_state)
    if rise is not None:
        f = frame_grid(rune)
        fill_opening(f, glow, phase)
        f.outline()
        clip = BASE_Y if rise else PH
        for y in range(PH):
            sy = y - rise
            if sy < 0 or y > clip:
                continue
            for x in range(PW):
                k = f.get(x, sy)
                if k != ".":
                    g.set(x, y, k)
        if rise:
            # The slot's front lip covers the frame where it comes out of the floor.
            for x in range(SLOT_X0, SLOT_X1 + 1):
                g.set(x, BASE_Y + 1, "s")
                g.set(x, BASE_Y, "o" if g.get(x, BASE_Y) != "." else ".")
        else:
            shadow(g)
    if dust:
        for x, y in ((1, 40), (3, 38), (29, 39), (30, 37), (2, 35), (28, 34)):
            g.set(x, y, "S")
        for x, y in ((0, 38), (31, 40), (4, 36)):
            g.set(x, y, "e")
    return g.image()


def portal_rise():
    frames = [
        portal_frame(None, 0, slot_state=0),
        portal_frame(None, 0, slot_state=1, dust=True),
        portal_frame(33, 0, slot_state=1, dust=True),
        portal_frame(20, 0, slot_state=1, dust=True),
        portal_frame(8, 0, slot_state=1, dust=True),
        portal_frame(0, 0, rune="h"),
        portal_frame(0, 1, rune="H"),
        portal_frame(0, 2, rune="H"),
    ]
    return strip_images(frames, PW, PH)


SPARKS = [[(13, 33), (18, 25)], [(14, 28), (17, 20)], [(13, 23), (18, 36)], [(15, 18), (17, 31)]]


def portal_loop():
    frames = []
    for i in range(4):
        img = portal_frame(0, 3, phase=i, rune="H" if i % 2 == 0 else "h")
        for x, y in SPARKS[i]:
            img.putpixel((x, y), wp.rgb("Z"))
        frames.append(img)
    return strip_images(frames, PW, PH)


def strip_images(frames, w, h):
    img = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        img.paste(f, (i * w, 0))
    return img


def gate_free(portal_frame_index):
    """The arch of make_world_props.gate() without its side pillars, on a footing."""
    img = wp.gate(portal_frame_index)
    g = Grid(wp.GATE_W, wp.GATE_H)
    inv = {wp.rgb(k)[:3]: k for k in wp.P}
    for y in range(wp.GATE_H):
        for x in range(wp.GATE_W):
            p = img.getpixel((x, y))
            if p[3]:
                g.set(x, y, inv[p[:3]])
    # Remove the brick pillars (x <= 9 and x >= 38 outside the arch ring).
    for y in range(wp.GATE_H):
        for x in range(wp.GATE_W):
            inside_arch = wp._in_shape(x, y, wp.RING_R + 1.0)
            if not inside_arch:
                g.set(x, y, ".")
    # Footings under both jambs: wider blocks with a lit top face.
    for x0, x1 in ((7, 15), (32, 40)):
        g.rect(x0, 25, x1, 29, "S")
        g.rect(x0, 25, x1, 25, "T")
        g.rect(x0, 26, x0, 29, "T")
        g.rect(x1, 26, x1, 29, "e")
        g.rect(x0 + 1, 29, x1 - 1, 29, "e")
    for x, y, k in ((8, 28, "N"), (9, 28, "n"), (39, 27, "k"), (38, 28, "k")):
        g.set(x, y, k)
    # Threshold between the footings.
    g.rect(16, 29, 31, 29, "e")
    for y in range(wp.GATE_H):
        for x in range(wp.GATE_W):
            if g.get(x, y) == "o":
                g.set(x, y, ".")
    g.outline()
    for x in range(8, 43):
        if g.get(x, 31) == ".":
            g.set(x, 31, "d")
    return g.image()


def main():
    portal_rise().save(f"{LEVEL}/portal_rise.png")
    portal_loop().save(f"{LEVEL}/portal_loop.png")
    gate_free(None).save(f"{LEVEL}/gate_free_closed.png")
    strip_images([gate_free(i) for i in range(4)], wp.GATE_W, wp.GATE_H).save(f"{LEVEL}/gate_free_open.png")


if __name__ == "__main__":
    main()
