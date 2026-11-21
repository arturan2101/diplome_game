"""Player cast (4 frames) and parry (3 frames) poses in four directions (batch 14, part 4),
from PixelLab v3 animations of character 4459ec17-e479-409e-bcda-e4bf0966c233
("ruins_player", Ruins 32 palette):
  cast   down/up/right a941ea35 (cast), left 16840526 (cast_west_v2)
  parry  down/right dd9c8140 (parry), up 305f9d41 (parry_north_v2),
         left 1a77e4c5 (parry_west_v2)
The sheet is the pixelart_workbench `join ... --as rows` of these 8 animations in the
ROWS order below (32x32 cells, 4 frames each), downloaded as a PNG.

Same import as tools/art/import_player_actions.py: palette snap, the player's recolour
(outline #08070b, tunic #3a7ac0), the idle shadow on row 23; and every frame is aligned
on its own lowest body row, so the feet stay on row 22 in every frame.
- cast: frames 0-3 (0 = wind-up, the hand comes up; 1-2 = the glow; 3 = lowering). The
  pale glow PixelLab drew round the raised hand is recoloured to the magic purple
  (#f4f0e0 core, #9a5ae0, #4a2a78), so it reads as a spell, not as steel.
- parry: PixelLab frames 1-3 (sword coming up, held across the body, relaxing). Frame 1
  of the output gets a short white-gold flash on the middle of the blade (the moment a
  blow is parried; fx/parry_flash.png can still play on top).
Output: assets/art/characters/player_{cast,parry}_{down,up,right,left}.png
Usage (from the project root): python tools/art/import_player_cast_parry.py <sheet.png>
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from import_player_actions import RECOLOR, SHADOW, clean, feet, hx  # noqa: E402

ROWS = [  # (anim, dir, PixelLab frames used)
    ("cast", "down", [0, 1, 2, 3]), ("cast", "up", [0, 1, 2, 3]),
    ("cast", "right", [0, 1, 2, 3]), ("cast", "left", [0, 1, 2, 3]),
    ("parry", "down", [1, 2, 3]), ("parry", "up", [1, 2, 3]),
    ("parry", "right", [1, 2, 3]), ("parry", "left", [1, 2, 3]),
]
C, F = 32, 24
GLOW = {"#f4f0e0": "#f4f0e0", "#d8d4c4": "#9a5ae0", "#9aa2ad": "#9a5ae0", "#767a8c": "#4a2a78",
        "#7ac0f0": "#9a5ae0", "#9af0e0": "#9a5ae0"}
STEEL = {"#9aa2ad", "#d8d4c4", "#f4f0e0"}


def key(p):
    return "#%02x%02x%02x" % p[:3]


def glow_to_purple(frame, direction, body_cx):
    """Recolour pale pixels on the free hand's side, above the belt, to magic purple."""
    px = frame.load()
    for y in range(4, 15):
        for x in range(F):
            if not px[x, y][3]:
                continue
            if direction == "down" and x < body_cx + 6:    # the face is white too
                continue
            if direction == "right" and x < body_cx + 3:
                continue
            if direction == "left" and x > body_cx - 3:
                continue
            if direction == "up" and x > body_cx - 3:
                continue
            k = key(px[x, y])
            if k in GLOW:
                px[x, y] = hx(GLOW[k])


def flash(frame):
    """A small white-gold star on the middle of the blade."""
    px = frame.load()
    pts = [(x, y) for y in range(F - 2) for x in range(F) if px[x, y][3] and key(px[x, y]) in STEEL]
    if not pts:
        return
    cx = round(sum(p[0] for p in pts) / len(pts))
    cy = round(sum(p[1] for p in pts) / len(pts))
    for (dx, dy), k in (((0, 0), "#f4f0e0"), ((1, 0), "#ffd860"), ((-1, 0), "#ffd860"), ((0, 1), "#ffd860"),
                        ((0, -1), "#ffd860"), ((2, 0), "#e09a20"), ((-2, 0), "#e09a20"), ((0, -2), "#e09a20"),
                        ((0, 2), "#e09a20")):
        x, y = cx + dx, cy + dy
        if 0 <= x < F and 0 <= y < F - 1:
            px[x, y] = hx(k)


def main():
    sheet = Image.open(sys.argv[1]).convert("RGBA")
    for row, (anim, direction, frames) in enumerate(ROWS):
        idle = Image.open(f"assets/art/characters/player_idle_{direction}.png").convert("RGBA").crop((0, 0, F, F))
        idle_cx, _ = feet(idle, shadow_row=F - 1)
        shadow = [x for x in range(F) if idle.getpixel((x, F - 1)) == SHADOW]
        first = sheet.crop((frames[0] * C, row * C, (frames[0] + 1) * C, (row + 1) * C))
        cx0, _ = feet(first)
        dx = int(round(idle_cx - cx0))
        out = Image.new("RGBA", (F * len(frames), F))
        for i, n in enumerate(frames):
            cell = sheet.crop((n * C, row * C, (n + 1) * C, (row + 1) * C))
            _, bottom = feet(cell)
            dy = (F - 2) - bottom
            frame = Image.new("RGBA", (F, F))
            frame.paste(cell, (dx, dy), cell)
            frame = clean(frame, dict(RECOLOR))
            if anim == "cast":
                glow_to_purple(frame, direction, idle_cx)
            if anim == "parry" and i == 1:
                flash(frame)
            for x in range(F):
                frame.putpixel((x, F - 1), (0, 0, 0, 0))
            for x in shadow:
                frame.putpixel((x, F - 1), SHADOW)
            out.paste(frame, (i * F, 0))
        out.save(f"assets/art/characters/player_{anim}_{direction}.png")
        print(anim, direction, "dx", dx)


if __name__ == "__main__":
    main()
