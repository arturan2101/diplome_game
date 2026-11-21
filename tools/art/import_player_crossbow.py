"""Player crossbow attack (batch 11), 4 frames in four directions (aim, shot, recoil),
from two PixelLab animations of character 4459ec17-e479-409e-bcda-e4bf0966c233
("ruins_player"):
  sheet A  group c382fb97 "crossbow" (v3, a small wooden crossbow held in both hands):
           used for down and up; to the sides it drew a plain bow being drawn
  sheet B  group 550d0cb3 "crossbow_shoot" (skeleton-v3 move "shoot", held like a
           rifle): used for right and left
Each sheet is the pixelart_workbench `join` of the group's south, north, east and west
animations `--as rows` (32x32 cells, rows down, up, right, left), downloaded as a PNG.
Same alignment and recolouring as tools/art/import_player_weapons.py (feet on the idle
of the same direction, palette, outline #08070b, tunic #3a7ac0, idle shadow row).
From behind the crossbow is hidden by the body, so the tips of its steel limbs are drawn
beside the body at chest height, 2 px on each side, kicked up 1 px on the shot.
Output: assets/art/characters/player_crossbow_{down,up,right,left}.png
Usage (from the project root): python tools/art/import_player_crossbow.py <sheetA.png> <sheetB.png>
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from import_player_actions import C, F, RECOLOR, SHADOW, clean, feet, hx  # noqa: E402

# (sheet index, row in the sheet, direction, frame order)
ROWS = [(0, 0, "down", [0, 1, 2, 3]), (0, 1, "up", [0, 1, 2, 3]),
        (1, 2, "right", [0, 1, 2, 3]), (1, 3, "left", [0, 1, 2, 3])]
KICK = [0, 0, 1, 0]   # the limbs jump up on the shot (frame 2)
OUTLINE = hx("#08070b")


def limbs_from_behind(frame, cx, kick):
    """Steel crossbow limbs across the shoulders, on empty pixels beside the body."""
    px = frame.load()
    rows = [y for y in range(F) if any(px[x, y][3] for x in range(F))]
    y = min(rows) + 11 - kick                       # chest height, under the hood
    body = [x for x in range(F) if px[x, y][3]]
    if not body:
        return
    left, right = min(body), max(body)
    drawn = []
    for x in (left - 2, left - 1, right + 1, right + 2):
        if 0 <= x < F and px[x, y][3] == 0:
            px[x, y] = hx("#9aa2ad")
            drawn.append((x, y))
    for xx, yy in drawn:
        for nx, ny in ((xx + 1, yy), (xx - 1, yy), (xx, yy - 1), (xx, yy + 1)):
            if 0 <= nx < F and 0 <= ny < F - 1 and px[nx, ny][3] == 0:
                px[nx, ny] = OUTLINE


def main():
    sheets = [Image.open(p).convert("RGBA") for p in sys.argv[1:3]]
    for sheet_i, row, direction, order in ROWS:
        sheet = sheets[sheet_i]
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
            if direction == "up":
                limbs_from_behind(frame, idle_cx, KICK[i])
            out.paste(frame, (i * F, 0))
        out.save(os.path.join("assets/art/characters", f"player_crossbow_{direction}.png"))
        print("crossbow", direction, "offset", dx, dy)


if __name__ == "__main__":
    main()
