"""Player spear and dagger attacks (plan group 3), 4 frames in four directions, from
PixelLab v3 animations of character 4459ec17-e479-409e-bcda-e4bf0966c233
("ruins_player", Ruins 32 palette), one animation group per direction:
  spear    down 9386e5c4 (spear_south_v2), up adc10737 (spear_north), right e60997cd
           (spear_east), left 78588b33 (spear_west)
  daggers  down 1701a914, up ecb1c53d, right 85348d3c, left 530b86c5
The sheet is the pixelart_workbench `join ... --as rows` of these 8 animations in the
ROWS order below (32x32 cells), downloaded as a PNG.
Same alignment and recolouring as tools/art/import_player_actions.py (feet on the idle
of the same direction, outline #08070b, tunic #3a7ac0). Fixes:
- the last frame of both "left" animations turned the figure to the right: it is
  replaced by an earlier frame (spear: the start pose, daggers: the second stab);
- from behind the spear was hidden by the body: a long shaft with a steel tip is drawn
  above the right shoulder, pushed up on the thrust frames.
Output: assets/art/characters/player_{spear,daggers}_{down,up,right,left}.png
Usage (from the project root): python tools/art/import_player_weapons.py <sheet.png>
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from import_player_actions import C, F, RECOLOR, SHADOW, clean, feet, hx  # noqa: E402

# (anim, dir, frame order taken from the 4 generated frames)
ROWS = [
    ("spear", "down", [0, 1, 2, 3]), ("spear", "up", [0, 1, 2, 3]), ("spear", "right", [0, 1, 2, 3]),
    ("spear", "left", [0, 1, 2, 0]),
    ("daggers", "down", [0, 1, 2, 3]), ("daggers", "up", [0, 1, 2, 3]), ("daggers", "right", [0, 1, 2, 3]),
    ("daggers", "left", [0, 1, 2, 1]),
]
SPEAR_REACH = [0, 3, 4, 1]   # how far the spear is pushed up on each "up" frame
OUTLINE = hx("#08070b")


def spear_from_behind(frame, cx, reach):
    """Draws the spear above the right shoulder, only on empty pixels (the body hides it below)."""
    px = frame.load()
    rows = [y for y in range(F) if any(px[x, y][3] for x in range(F))]
    head_top = min(rows)
    x = int(cx) + 4
    tip = max(1, head_top - 3 - reach)
    drawn = []

    def put(xx, yy, key):
        if 0 <= xx < F and 0 <= yy < F - 1 and px[xx, yy][3] == 0:
            px[xx, yy] = hx(key)
            drawn.append((xx, yy))

    put(x, tip, "#f4f0e0")
    put(x - 1, tip + 1, "#9aa2ad")
    put(x, tip + 1, "#f4f0e0")
    put(x + 1, tip + 1, "#9aa2ad")
    put(x, tip + 2, "#9aa2ad")
    for y in range(tip + 3, head_top + 9):
        put(x, y, "#7a4a2c")
    for xx, yy in drawn:
        for nx, ny in ((xx + 1, yy), (xx - 1, yy), (xx, yy - 1), (xx, yy + 1)):
            if 0 <= nx < F and 0 <= ny < F - 1 and px[nx, ny][3] == 0:
                px[nx, ny] = OUTLINE


def main():
    sheet = Image.open(sys.argv[1]).convert("RGBA")
    for row, (anim, direction, order) in enumerate(ROWS):
        idle = Image.open(f"assets/art/characters/player_idle_{direction}.png").convert("RGBA").crop((0, 0, F, F))
        idle_cx, _ = feet(idle, shadow_row=F - 1)
        shadow = [x for x in range(F) if idle.getpixel((x, F - 1)) == SHADOW]
        cells = [sheet.crop((i * C, row * C, (i + 1) * C, (row + 1) * C)) for i in range(4)]
        cx, bottom = feet(cells[0])
        dx, dy = int(round(idle_cx - cx)), (F - 2) - bottom
        out = Image.new("RGBA", (F * len(order), F))
        for i, index in enumerate(order):
            frame = Image.new("RGBA", (F, F))
            frame.paste(cells[index], (dx, dy), cells[index])
            frame = clean(frame, dict(RECOLOR))
            for x in range(F):
                frame.putpixel((x, F - 1), (0, 0, 0, 0))
            for x in shadow:
                frame.putpixel((x, F - 1), SHADOW)
            if anim == "spear" and direction == "up":
                spear_from_behind(frame, idle_cx, SPEAR_REACH[i])
            out.paste(frame, (i * F, 0))
        out.save(os.path.join("assets/art/characters", f"player_{anim}_{direction}.png"))
        print(anim, direction, "offset", dx, dy)


if __name__ == "__main__":
    main()
