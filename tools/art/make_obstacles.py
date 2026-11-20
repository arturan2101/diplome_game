"""Room obstacles and flat wall details (batch 10, group 2; docs/art-style.md palette).

Obstacles stand free inside rooms and block one cell (the sarcophagus two); the picture
may rise above the cell. The bottom row of every picture is the bottom of the cell: the
base sits on the last rows, a #0f0e14 shadow under it, shifted right (light from the
top-left):
- Whole column 16x32: assets/art/level/obstacle_column.png
- Broken column 16x24 (jagged break, a chip on the plinth): obstacle_column_broken.png
- Rock pile 16x16: obstacle_rocks.png
- Sarcophagus 32x16 (two cells side by side): obstacle_sarcophagus.png

Wall details are flat overlays for the brick front of ruins_wall.png (rows 6-14 of the
16x16 tile; nothing on the top face, nothing outside the cell), one strip of 16x16 slots:
0 crack, 1 hanging chain, 2 niche with a skull, 3 torn banner, 4 moss and ivy:
assets/art/tiles/wall_details.png (80x16). The torch stays level/torch.png.
Run from the project root: python tools/art/make_obstacles.py
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_world_props import Grid, draw  # noqa: E402

LEVEL, TILES = "assets/art/level", "assets/art/tiles"

# --- Columns -------------------------------------------------------------------------

CAPITAL = [
    ".oooooooooooooo.",
    ".oTTTTTTTTTTTSo.",
    ".oTSSSSSSSSSSeo.",
    ".oSeeeeeeeeeeso.",
    ".oooooooooooooo.",
    "..oTTTSTTSSeso..",
]
SHAFT = "...oTTSTTSeso..."
BASE = [
    "..oTTTTTTTSSeo..",
    "..oSSSSSSSeeso..",
    ".oTTTTTTTTTSeeo.",
    ".oTSSSSSSSSeeeo.",
    ".oSeeeeeeeeeeso.",
    ".oNnseeeeeeesso.",
    ".oooooooooooooo.",
    "..dddddddddddddd",
]


def put(rows, x, y, key):
    r = list(rows[y])
    r[x] = key
    rows[y] = "".join(r)


def column():
    rows = ["." * 16] + CAPITAL + [SHAFT] * 17 + BASE
    assert len(rows) == 32
    # A crack running down the lit side, and moss creeping up from the base.
    for x, y in ((6, 10), (6, 11), (5, 12), (5, 13), (6, 14), (9, 17), (10, 18)):
        put(rows, x, y, "k")
    for x, y, k in ((4, 21, "N"), (4, 22, "N"), (5, 22, "n"), (4, 23, "n"), (5, 23, "N")):
        put(rows, x, y, k)
    return rows


BROKEN_TOP = [
    "................",
    "....oo..........",
    "...oTTo.........",
    "...oTTTo........",
    "...oTSTTo.oo....",
    "...oTTTSToTTo...",
    "...oTSTTTTTSo...",
]


def column_broken():
    rows = BROKEN_TOP + [SHAFT] * 9 + BASE
    assert len(rows) == 24
    for x, y in ((8, 8), (8, 9), (9, 10), (6, 12)):
        put(rows, x, y, "k")
    for x, y, k in ((4, 13, "N"), (4, 14, "N"), (5, 14, "n"), (4, 15, "n")):
        put(rows, x, y, k)
    # A chip of the broken shaft lying on the plinth, right of the base.
    for x, y, k in ((11, 17, "o"), (12, 17, "o"), (10, 18, "o"), (11, 18, "T"), (12, 18, "S"),
                    (13, 18, "o"), (10, 19, "o"), (11, 19, "S"), (12, 19, "e"), (13, 19, "o")):
        put(rows, x, y, k)
    return rows


# --- Rock pile -----------------------------------------------------------------------

# (cx, cy, rx, ry), back to front.
ROCKS = [(8.5, 5.0, 4.0, 3.2), (4.3, 8.8, 4.0, 3.5), (11.6, 9.2, 3.9, 3.4), (7.8, 12.0, 3.8, 2.4)]


def rocks():
    g = Grid(16, 16)
    for y in range(16):
        for x in range(16):
            if ((x + 0.5 - 8.8) / 7.4) ** 2 + ((y + 0.5 - 14.0) / 2.0) ** 2 <= 1:
                g.set(x, y, "d")
    for cx, cy, rx, ry in ROCKS:
        def inside(x, y, grow=0.0):
            return ((x + 0.5 - cx) / (rx + grow)) ** 2 + ((y + 0.5 - cy) / (ry + grow)) ** 2 <= 1
        for y in range(16):
            for x in range(16):
                if inside(x, y, 1.0) and not inside(x, y):
                    g.set(x, y, "o")
        for y in range(16):
            for x in range(16):
                if inside(x, y):
                    s = (x + 0.5 - cx) / rx + (y + 0.5 - cy) / ry
                    g.set(x, y, "T" if s < -0.55 else "S" if s < 0.35 else "e" if s < 1.0 else "s")
    # Cracks and a tuft of moss between the stones.
    for x, y, k in ((4, 8, "e"), (10, 5, "e"), (12, 9, "e"), (3, 11, "N"), (2, 11, "n")):
        if g.get(x, y) not in (".", "o", "d"):
            g.set(x, y, k)
    return g.image()


# --- Sarcophagus ---------------------------------------------------------------------

SARCOPHAGUS = """
................................
..oooooooooooooooooooooooooooo..
.oTTTTTTTTTTTTTTTTTTTTTTTTTTTTo.
.oTSSSSSSSTeSSSSSSSSSSSSSSSSSeo.
.oTSSSSSSSTeSSSSSSSSSSSSSSSSSeo.
.oTSSTTeeeTTTTTTTTTTTTTTTTSSSeo.
.oTSSeeSSSTeeeeeeeeeeeeeeSSSSeo.
.oTSSSSSSSTeSSSSSSSSSSSSSSSNneo.
.oSeeeeeeeeeeeeeeeeeeeeeeeeneeo.
.oooooooooooooooooooooooooooooo.
..oSkkkkkkkSkkkkkkkkkSkkkkkkso..
..oSkeeeeekSkeeeeeeekSkeeeeksso.
..oSkkkkkkkSkkkkkkkkkSkkkkkkso..
..oNnsssssssssssssssssssssssso..
..oooooooooooooooooooooooooooo..
...ddddddddddddddddddddddddddddd
"""


# --- Wall details (overlays on rows 6-14 of the wall front) ---------------------------

CRACK = """
................
................
................
................
................
................
.........o......
........eo......
........o.......
.......eo.......
......eoo.......
......o..eo.....
.....eo...o.....
.....o.....o....
....eo..........
................
"""

CHAIN = """
................
................
................
................
................
................
......ommo......
.......Uo.......
.......Umo......
......U..mo.....
......m..mo.....
.......mmo......
.......Uo.......
......oUmo......
.......mmo......
................
"""

NICHE = """
................
................
................
................
................
................
.....oooooo.....
....odddddoo....
....oddWWdeo....
....odWUWmdo....
....odoWomdo....
....odmWWmdo....
....oddmmddo....
....oTTTTTSo....
....oooooooo....
................
"""

BANNER = """
................
................
................
................
................
................
...yBBBBBBBBBy..
....oRRRRRRro...
....oRRYYRRro...
....oRYZYYRro...
....oRRYYRRro...
....oRRRRRRro...
....oRro.oRro...
....oro...oo....
.....o..........
................
"""

IVY = """
................
................
................
................
................
................
NNnNNNNnNnNNNNnN
nNn.nNn.n.nN.nN.
.n...N..n..n..n.
.N..nNn.N.nNn.N.
.n...n..n..n..n.
nNn..N....nN..n.
.n...n.....n.nNn
.....N.....N..n.
....nNn.........
................
"""

DETAILS = [CRACK, CHAIN, NICHE, BANNER, IVY]


def wall_details():
    img = Image.new("RGBA", (16 * len(DETAILS), 16))
    for i, rows in enumerate(DETAILS):
        lines = rows.strip("\n").splitlines()
        assert all(set(line) == {"."} for line in lines[:6] + lines[15:]), i
        img.paste(draw(rows, 16, 16), (16 * i, 0))
    return img


def main():
    draw("\n".join(column()), 16, 32).save(f"{LEVEL}/obstacle_column.png")
    draw("\n".join(column_broken()), 16, 24).save(f"{LEVEL}/obstacle_column_broken.png")
    rocks().save(f"{LEVEL}/obstacle_rocks.png")
    draw(SARCOPHAGUS, 32, 16).save(f"{LEVEL}/obstacle_sarcophagus.png")
    wall_details().save(f"{TILES}/wall_details.png")


if __name__ == "__main__":
    main()
