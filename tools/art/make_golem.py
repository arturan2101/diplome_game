"""Stone golem, front view, 48x48 (body about 34x40, feet on row 46, shadow on row 47):
a hulking figure of separate boulders (legs, torso, shoulders, arms, fists, a small
head sunk between the shoulders), lit from the top-left, moss on the top stones,
orange eye slits and a glowing core crack in the chest. Light stone (#d8d4c4 /
#9aa2ad / #767a8c) so the main mass stays out of the floor's value range.
This picture is the reference for the PixelLab character (other directions and
animations): assets/art/enemies/golem_reference.png
Run from the project root: python tools/art/make_golem.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_world_props import Grid  # noqa: E402

# (centre x, centre y, radius x, radius y, mossy), back to front.
BOULDERS = [
    (19.5, 42.0, 4.2, 4.8, False), (29.5, 42.0, 4.2, 4.8, False),   # legs
    (24.5, 29.0, 11.5, 10.0, False),                               # torso
    (8.0, 27.5, 4.5, 5.5, False), (41.0, 27.5, 4.5, 5.5, False),    # upper arms
    (7.0, 35.5, 5.5, 4.8, False), (42.0, 35.5, 5.5, 4.8, False),    # fists
    (24.5, 16.5, 5.5, 4.5, True),                                  # head
    (13.0, 21.5, 6.5, 5.5, True), (36.0, 21.5, 6.5, 5.5, True),     # shoulders
]


def golem():
    g = Grid(48, 48)
    for cx, cy, rx, ry, mossy in BOULDERS:
        inside = set()
        for y in range(48):
            for x in range(48):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    inside.add((x, y))
        for x, y in inside:
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            s = dx + dy
            key = "W" if s < -0.75 else "m" if s < 0.45 else "T"
            if mossy and dy < -0.5 and (x * 3 + y) % 5 != 0:
                key = "N" if dx < 0.2 else "n"
            g.set(x, y, key)
        # The boulder's own edge: a dark joint against whatever lies behind it.
        for x, y in inside:
            if any((x + ex, y + ey) not in inside and g.get(x + ex, y + ey) != "."
                   for ex, ey in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                g.set(x, y, "o")
    # Eye slits and the core crack.
    for x, y in ((22, 17), (23, 17), (26, 17), (27, 17)):
        g.set(x, y, "Y")
    g.set(22, 17, "Z")
    g.set(26, 17, "Z")
    for x, y, key in ((24, 26, "Y"), (25, 27, "Z"), (24, 28, "Y"), (25, 29, "q"), (24, 30, "Y"), (23, 31, "q")):
        g.set(x, y, key)
    g.outline()
    g.rect(14, 47, 35, 47, "d")
    return g


def main():
    os.makedirs("assets/art/enemies", exist_ok=True)
    golem().image().save("assets/art/enemies/golem_reference.png")


if __name__ == "__main__":
    main()
