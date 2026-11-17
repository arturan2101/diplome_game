"""Finishes the ghost after tools/art/import_pixellab.py (PixelLab character
b78f55a6-efff-4075-b475-580f5ffb2e0b "ruins_ghost", animations idle and move, canvas 32):
- one teal body: the two near-identical pale tones of the source had snapped to
  teal light and bone, which looked spotty; shades become teal, the outline #08070b;
- its own death (the squash death of the importer left a floating scrap of the hood):
  a white flash, then the ghost rises and melts away in 3 frames.
Then rewrites ghost_frames.tres. Run from the project root after the import:
    python tools/art/finish_ghost.py
"""
import glob
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_action_frames as actions  # noqa: E402

F = 32
SRC = "assets/art/enemies"


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


RECOLOR = {
    "#f4f0e0": "#9af0e0", "#d8d4c4": "#9af0e0",
    "#9aa2ad": "#2aa8a0", "#767a8c": "#2aa8a0", "#5d6072": "#2aa8a0", "#4c4e5f": "#2aa8a0", "#343442": "#2aa8a0",
    "#0f0e14": "#08070b",
}
RECOLOR = {hexc(k): hexc(v) for k, v in RECOLOR.items()}
OUTLINE = hexc("#08070b")
FLASH = hexc("#f4f0e0")


def recolor(img, mapping):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p in mapping:
                px[x, y] = mapping[p]
    return out


def melt(img, rise, keep):
    """The frame moved up by rise; keep(x, y) says which pixels stay."""
    out = Image.new("RGBA", img.size)
    src = img.load()
    px = out.load()
    for y in range(F):
        for x in range(F):
            p = src[x, y]
            if p[3] and y - rise >= 0 and keep(x, y):
                px[x, y - rise] = p
    return out


def main():
    actions.F = F
    for path in sorted(glob.glob(os.path.join(SRC, "ghost_*.png"))):
        img = Image.open(path).convert("RGBA")
        recolor(img, RECOLOR).save(path)
    idle = actions.frame(os.path.join(SRC, "ghost_idle_down.png"))
    body = actions.body_only(idle)
    flash = recolor(body, {p: FLASH for p in set(body.getdata()) if p[3] and p != OUTLINE})
    frames = [flash,
              melt(body, 1, lambda x, y: (x + 2 * y) % 4 != 0),
              melt(body, 2, lambda x, y: (x + y) % 2 == 0),
              melt(body, 3, lambda x, y: (x + 2 * y) % 4 == 0 and body.getpixel((x, y)) != OUTLINE)]
    actions.strip(frames, os.path.join(SRC, "ghost_death.png"))
    actions.write_frames(SRC, "ghost", os.path.join(SRC, "ghost_frames.tres"))
    print("ghost finished")


if __name__ == "__main__":
    main()
