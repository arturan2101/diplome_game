"""Player bow draw (6 frames), shield block (4) and dash (4) in four directions, from
PixelLab animations of character 4459ec17-e479-409e-bcda-e4bf0966c233 ("ruins_player",
v3 custom motion, Ruins 32 palette). Animation groups used, per direction:
  bow    down 01b9f383 (bow_draw_south_v2), up/right cb9e63d9 (bow_draw),
         left 5e6b2339 (bow_draw_west_v2)
  block  down/up/right 899f7d5d (block), left 33821ced (block_west_v2)
  dash   down 9822a3c3 (dash_south_v2), up 9d286efa (dash_north_v2),
         right/left 330a7443 (dash)
The sheet is the pixelart_workbench `join ... --as rows` of these 12 animations in the
ROWS order below (32x32 cells), downloaded as a PNG.
Each strip is aligned on the feet with player_idle_<dir>.png (same shadow row), snapped
to the palette and recoloured like the existing player frames (outline #08070b, tunic
#3a7ac0); the pale shield of the block (left, up) is recoloured to wood.
Output: assets/art/characters/player_{bow,block,dash}_{down,up,right,left}.png
Usage (from the project root): python tools/art/import_player_actions.py <sheet.png>
"""
import sys

from PIL import Image

PALETTE = """#08070b #0f0e14 #17161f #1f1e29 #2a2935 #343442 #3f4050 #4c4e5f #5d6072 #767a8c
#263a32 #3b5a45 #9aa2ad #d8d4c4 #f4f0e0 #4a2f22 #7a4a2c #b07040 #e0a070 #5a1820 #a82a30 #e85a3a
#8a4a10 #e09a20 #ffd860 #1e3f6a #3a7ac0 #7ac0f0 #4a2a78 #9a5ae0 #2aa8a0 #9af0e0""".split()
COLORS = [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in PALETTE]


def hx(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


RECOLOR = {"#0f0e14": "#08070b", "#1e3f6a": "#3a7ac0", "#2a2935": "#1e3f6a", "#343442": "#1e3f6a"}
SHIELD = {"#d8d4c4": "#7a4a2c", "#f4f0e0": "#b07040", "#9aa2ad": "#4a2f22"}
SHADOW = hx("#0f0e14")
ROWS = [  # (anim, dir, frames)
    ("bow", "down", 6), ("bow", "up", 6), ("bow", "right", 6), ("bow", "left", 6),
    ("block", "down", 4), ("block", "up", 4), ("block", "right", 4), ("block", "left", 4),
    ("dash", "down", 4), ("dash", "up", 4), ("dash", "right", 4), ("dash", "left", 4),
]
C, F = 32, 24


def clean(img, mapping):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
                continue
            best = min(COLORS, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)
            key = "#%02x%02x%02x" % best
            px[x, y] = hx(mapping.get(key, key))
    return out


def feet(img, shadow_row=None):
    """(centre x of the lowest 4 body rows, lowest body row); the shadow row is skipped."""
    px = img.load()
    rows = [y for y in range(img.height) if y != shadow_row and any(px[x, y][3] and px[x, y] != SHADOW for x in range(img.width))]
    bottom = max(rows)
    xs = [x for y in range(bottom - 3, bottom + 1) for x in range(img.width) if px[x, y][3] and px[x, y] != SHADOW]
    return (min(xs) + max(xs)) / 2.0, bottom


def main():
    sheet = Image.open(sys.argv[1]).convert("RGBA")
    for row, (anim, direction, count) in enumerate(ROWS):
        idle = Image.open(f"assets/art/characters/player_idle_{direction}.png").convert("RGBA").crop((0, 0, F, F))
        idle_cx, _ = feet(idle, shadow_row=F - 1)
        shadow = [x for x in range(F) if idle.getpixel((x, F - 1)) == SHADOW]
        cells = [sheet.crop((i * C, row * C, (i + 1) * C, (row + 1) * C)) for i in range(count)]
        cx, bottom = feet(cells[0])
        dx = int(round(idle_cx - cx))
        dy = (F - 2) - bottom
        out = Image.new("RGBA", (F * count, F))
        for i, cell in enumerate(cells):
            mapping = dict(RECOLOR)
            frame = Image.new("RGBA", (F, F))
            frame.paste(cell, (dx, dy), cell)
            frame = clean(frame, mapping)
            if anim == "block" and direction in ("left", "up"):
                px = frame.load()
                xs = range(int(idle_cx) - 2) if direction == "left" else range(int(idle_cx) + 2, F)
                shield = dict(SHIELD, **({"#e0a070": "#b07040"} if direction == "left" else {}))
                for y in range(F):
                    for x in xs:
                        key = "#%02x%02x%02x" % px[x, y][:3]
                        if px[x, y][3] and key in shield:
                            px[x, y] = hx(shield[key])
            for y in range(F - 1, F):
                for x in range(F):
                    frame.putpixel((x, y), (0, 0, 0, 0))
            for x in shadow:
                frame.putpixel((x, F - 1), SHADOW)
            out.paste(frame, (i * F, 0))
        out.save(f"assets/art/characters/player_{anim}_{direction}.png")
        print(anim, direction, "offset", dx, dy)


if __name__ == "__main__":
    main()
