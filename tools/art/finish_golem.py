"""Overgrown golem: the moss on the golem's top stones becomes grass (the nature
theme's greens of docs/art-style.md: #8ac060 lit top, #5a8a4a, #3b5a45 shadow), every
stone gets a strip of grass along its top edge (also in the joints between stones),
and short grass blades stick up over the outline where there is air above. Runs over every
golem strip and the reference picture, after tools/art/import_pixellab.py.
The blade pattern follows the left edge of the figure in each frame, so the tufts
stay on the same stones while the golem walks.
Run once, right after the import (a second run would grow the grass again):
    python tools/art/finish_golem.py
"""
import glob
import os

from PIL import Image

SRC = "assets/art/enemies"


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


MOSS = {hexc("#3b5a45"): hexc("#5a8a4a"), hexc("#263a32"): hexc("#3b5a45")}
GRASS = {hexc("#5a8a4a"), hexc("#3b5a45")}
LIT = hexc("#8ac060")
OUTLINE = hexc("#08070b")
DARK = {OUTLINE, hexc("#0f0e14"), hexc("#17161f"), hexc("#1f1e29")}
STONE = {hexc("#9aa2ad"), hexc("#767a8c"), hexc("#d8d4c4"), hexc("#f4f0e0"), hexc("#5d6072")}
# Blade heights by column (relative to the figure's left edge): 0 = no blade.
BLADES = [2, 0, 1, 0, 0, 2, 1, 0, 0, 1, 0, 2, 0, 0, 1]


def overgrow(frame):
    w, h = frame.size
    box = frame.getbbox()
    if box is None:
        return frame
    src = frame.load()
    out = frame.copy()
    px = out.load()
    for y in range(h):
        for x in range(w):
            p = src[x, y]
            if p[3] and p in MOSS:
                px[x, y] = MOSS[p]
    # A strip of grass on the top edge of every stone (skipping the eye and core glow).
    for y in range(1, h - 1):
        for x in range(w):
            if src[x, y][3] and src[x, y] in STONE and src[x, y - 1][3] and src[x, y - 1] in DARK:
                px[x, y] = hexc("#5a8a4a")
                if src[x, y + 1][3] and src[x, y + 1] in STONE and (x - box[0]) % 3 != 1:
                    px[x, y + 1] = hexc("#3b5a45")
    grown = out.copy()
    gp = grown.load()
    for y in range(1, h):
        for x in range(w):
            if not (px[x, y][3] and px[x, y] in GRASS):
                continue
            above = px[x, y - 1]
            if above[3] and above not in DARK:
                continue
            # A top edge of grass: lit, and a blade over the outline where there is air.
            gp[x, y] = LIT
            open_air = y >= 2 and px[x, y - 2][3] == 0
            height = BLADES[(x - box[0]) % len(BLADES)] if open_air else 0
            for k in range(1, height + 1):
                if y - k - 1 < 0:
                    break
                gp[x, y - k] = LIT if k < height or height == 1 else hexc("#5a8a4a")
            top = y - height - 1
            if height and top >= 0 and gp[x, top][3] == 0:
                gp[x, top] = OUTLINE
            # Outline beside a blade where it sticks out into the air.
            for k in range(1, height + 1):
                for nx in (x - 1, x + 1):
                    if 0 <= nx < w and gp[nx, y - k][3] == 0:
                        gp[nx, y - k] = OUTLINE
    return grown


def main():
    for path in sorted(glob.glob(os.path.join(SRC, "golem_*.png"))):
        img = Image.open(path).convert("RGBA")
        size = img.height
        out = Image.new("RGBA", img.size)
        for i in range(img.width // size):
            out.paste(overgrow(img.crop((i * size, 0, (i + 1) * size, size))), (i * size, 0))
        out.save(path)
    print("golem overgrown")


if __name__ == "__main__":
    main()
