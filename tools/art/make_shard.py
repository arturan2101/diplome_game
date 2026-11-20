"""Ruins shard, the camp currency (docs/art-style.md, 32-colour palette):
- Pickup 16x16, 4 frames shimmer loop (8 fps): a floating blue crystal, a glint runs
  down the facets, sparkles around it, the shadow under it catches a blue glow on the
  bright frames. Crystal centre (7.5, 7), shadow centre (7.5, 14), the bottom of the
  picture is row 14: assets/art/pickups/shard.png (64x16)
- HUD icon 16x16, no shadow: assets/art/ui/icon_shard.png
Run from the project root: python tools/art/make_shard.py
"""
import os
import sys

sys.path.insert(0, os.path.dirname(__file__))
from make_world_props import draw  # noqa: E402

SHARD = [
    "................",
    "................",
    ".......oo.......",
    "......oUUo......",
    ".....oULUlo.....",
    "....oULLUllo....",
    "....oLLLUllo....",
    "....oLLLUljo....",
    "....oLLLUljo....",
    ".....oLLUjo.....",
    ".....oLLljo.....",
    "......oLjo......",
    ".......oo.......",
    "................",
    ".....dddddd.....",
    "................",
]

# Per frame: glint pixels (turned to U), sparkle pixels, shadow row.
GLINTS = [
    [],
    [(7, 4), (6, 5), (5, 6)],
    [(7, 6), (6, 7), (5, 8)],
    [(7, 8), (6, 9)],
]
SPARKLES = [
    [(12, 4, "L")],
    [(12, 2, "U"), (12, 1, "L"), (11, 2, "L"), (13, 2, "L"), (12, 3, "L")],
    [(3, 10, "L"), (13, 6, "l")],
    [(2, 7, "U"), (2, 6, "L"), (1, 7, "L"), (3, 7, "L"), (2, 8, "L")],
]
SHADOWS = [
    ".....dddddd.....",
    ".....djjjjd.....",
    ".....djjjjd.....",
    ".....dddddd.....",
]

ICON = """
................
.......oo.......
......oUUo......
.....oULUlo.....
....oULLUllo....
...oULLLUlllo...
..oULLLLUllljo..
..oLLLLLUllljo..
..oLLLLLUllljo..
...oLLLLUlljo...
...oLLLLUlljo...
....oLLLUljo....
....oLLLlljo....
.....oLLljo.....
......oLjo......
.......oo.......
"""


def shard_frame(i):
    rows = [list(r) for r in SHARD]
    for x, y in GLINTS[i]:
        assert rows[y][x] in "Ll", (i, x, y)
        rows[y][x] = "U"
    for x, y, c in SPARKLES[i]:
        assert rows[y][x] == ".", (i, x, y)
        rows[y][x] = c
    rows[14] = list(SHADOWS[i])
    return "\n".join("".join(r) for r in rows)


def main():
    from PIL import Image
    img = Image.new("RGBA", (64, 16))
    for i in range(4):
        img.paste(draw(shard_frame(i), 16, 16), (i * 16, 0))
    img.save("assets/art/pickups/shard.png")
    draw(ICON, 16, 16).save("assets/art/ui/icon_shard.png")


if __name__ == "__main__":
    main()
