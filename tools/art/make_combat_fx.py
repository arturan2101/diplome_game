"""Combat effects of the golem and the ghost, and the damage digits (stages 29-31),
drawn in code with the helpers of make_world_props.py (32-colour palette):
- Golem slam shockwave, 64x64, 6 frames, one pass, centred: a ring of dust and stone
  chunks running out over cracks in the floor: assets/art/fx/golem_shockwave.png
- Golem slam warning, 48x48, 4 frames, loop, centred: a stippled dark shadow with a
  pulsing orange rim: assets/art/fx/golem_warning.png
  Both are round like the code's circle; the ring reaches about 31 px (shockwave) and
  23 px (warning), so scale them to slam_radius (36 px: x1.16 and x1.5).
- Ghost fade in and fade out, 32x32, 5 frames each: teal sparks and a flickering
  column of light: assets/art/fx/ghost_fade_in.png, ghost_fade_out.png
- Damage digits 0-9, 3x5 glyphs with a 1 px outline: cells 5x7, one strip 50x7, white
  (tint in code); place digits 4 px apart so the outlines overlap:
  assets/art/ui/damage_digits.png
Run from the project root: python tools/art/make_combat_fx.py
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_world_props import Grid  # noqa: E402

FX = "assets/art/fx"
UI = "assets/art/ui"


def strip(frames, w, h):
    img = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        img.paste(f, (w * i, 0))
    return img


def _rock(g, x, y):
    """A 2x2 stone chunk with an outline, lit from the top-left."""
    g.set(x, y, "W")
    g.set(x + 1, y, "m")
    g.set(x, y + 1, "m")
    g.set(x + 1, y + 1, "T")


# Cracks: (angle, share of the ring's reach, bend). Uneven on purpose.
CRACKS = [(0.25, 0.95, 0.5), (1.05, 0.6, -0.4), (1.7, 0.85, 0.3), (2.6, 0.5, 0.6), (3.2, 0.9, -0.5),
          (4.0, 0.7, 0.4), (4.7, 0.55, -0.3), (5.5, 0.8, 0.5)]


def _cracks(g, c, reach, key, lip=None):
    """Jagged cracks from the centre, each bending once; no outline (they are in the floor)."""
    for a, share, bend in CRACKS:
        length = reach * share
        x, y = c, c
        for step in range(2, int(length)):
            turn = a + (bend if step > length * 0.5 else 0.0) * 0.6
            zig = 0.7 if (step // 3) % 2 else -0.7
            x = c + math.cos(a) * min(step, length * 0.5) + math.cos(turn) * max(0, step - length * 0.5)
            y = c + math.sin(a) * min(step, length * 0.5) + math.sin(turn) * max(0, step - length * 0.5)
            px, py = int(round(x - math.sin(turn) * zig)), int(round(y + math.cos(turn) * zig))
            if g.get(px, py) in (".", "e"):
                g.set(px, py, key)
            # The lit lip of the crack (light from the top-left).
            if lip and g.get(px + 1, py + 1) == ".":
                g.set(px + 1, py + 1, lip)


def golem_shockwave():
    size, c = 64, 32.0
    radii = [6, 12, 18, 23, 27, 30]
    frames = []
    for i, radius in enumerate(radii):
        g = Grid(size, size)
        # The dust ring: breaks into dashes in the last frames.
        thick = 3.0 if i < 4 else 2.0
        gaps = 0 if i < 3 else 2 if i < 5 else 3
        for y in range(size):
            for x in range(size):
                dx, dy = x + 0.5 - c, y + 0.5 - c
                r = math.hypot(dx, dy)
                if not (radius - thick <= r <= radius):
                    continue
                seg = int((math.atan2(dy, dx) + math.pi) / math.tau * 24)
                if gaps and seg % 4 < gaps - 1 + (1 if i == 5 else 0):
                    continue
                if i >= 4:
                    g.set(x, y, "T" if r > radius - 1 else "e")
                else:
                    g.set(x, y, "W" if r > radius - 1.2 else "m" if r > radius - 2.2 else "T")
        # Stone chunks thrown out on the ring, then lying still.
        if i > 0:
            for k in range(8):
                a = k * math.tau / 8 + math.pi / 8
                rr = radius + 2 if i < 4 else 28
                _rock(g, int(round(c + math.cos(a) * rr)) - 1, int(round(c + math.sin(a) * rr)) - 1)
        g.outline()
        # Cracks in the floor under the ring, fading to seams at the end.
        _cracks(g, c, min(radius - 1, 27), "k" if i < 4 else "s", "e" if i < 5 else None)
        frames.append(g.image())
    return strip(frames, size, size)


def golem_warning():
    size, c, radius = 48, 24.0, 22.5
    rims = [("q", 1.2), ("Y", 2.0), ("q", 1.2), ("R", 1.0)]
    frames = []
    for rim, width in rims:
        g = Grid(size, size)
        for y in range(size):
            for x in range(size):
                r = math.hypot(x + 0.5 - c, y + 0.5 - c)
                if r > radius:
                    continue
                if r > radius - width:
                    g.set(x, y, rim)
                elif r > radius - width - 1:
                    g.set(x, y, "o")
                elif (x + y) % 2 == 0:
                    g.set(x, y, "d")
        frames.append(g.image())
    return strip(frames, size, size)


def _ghost_frame(column, spark_r, spark_rise, ring=False, core=False):
    """column: share of the ghost-shaped column that is lit (0..1, stippled)."""
    g = Grid(32, 32)
    cx, cy, rx, ry = 16.0, 16.0, 7.0, 13.0
    patterns = {0.25: lambda x, y: (x + 2 * y) % 4 == 0, 0.5: lambda x, y: (x + y) % 2 == 0,
                0.75: lambda x, y: (x + 2 * y) % 4 != 0, 1.0: lambda x, y: True}
    lit = patterns.get(column)
    for y in range(32):
        for x in range(32):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d > 1.0:
                continue
            if ring and d > 0.78:
                g.set(x, y, "U")
            elif lit and lit(x, y):
                g.set(x, y, "A" if d < 0.55 or column >= 0.75 else "a")
    if core:
        for y in range(6, 27):
            g.set(16, y, "U")
    if spark_r:
        for k in range(8):
            a = k * math.tau / 8 + (0.3 if spark_rise else 0.0)
            x = int(round(cx + math.cos(a) * spark_r * 0.7))
            y = int(round(cy + math.sin(a) * spark_r - spark_rise))
            g.set(x, y, "A" if k % 2 else "U")
            if k % 2 == 0:
                g.set(x + 1, y, "a")
    return g.image()


def ghost_fades():
    fade_in = [_ghost_frame(0, 14, 0), _ghost_frame(0.25, 10, 0), _ghost_frame(0.5, 6, 0),
               _ghost_frame(0.75, 0, 0, core=True), _ghost_frame(0, 0, 0, ring=True)]
    fade_out = [_ghost_frame(0, 0, 0, ring=True), _ghost_frame(0.75, 0, 0, core=True),
                _ghost_frame(0.5, 6, 2), _ghost_frame(0.25, 10, 5), _ghost_frame(0, 14, 8)]
    return strip(fade_in, 32, 32), strip(fade_out, 32, 32)


DIGITS = [
    ["111", "101", "101", "101", "111"], ["010", "110", "010", "010", "111"],
    ["111", "001", "111", "100", "111"], ["111", "001", "111", "001", "111"],
    ["101", "101", "111", "001", "001"], ["111", "100", "111", "001", "111"],
    ["111", "100", "111", "101", "111"], ["111", "001", "001", "010", "010"],
    ["111", "101", "111", "101", "111"], ["111", "101", "111", "001", "111"],
]


def damage_digits():
    frames = []
    for glyph in DIGITS:
        g = Grid(5, 7)
        for y, row in enumerate(glyph):
            for x, bit in enumerate(row):
                if bit == "1":
                    g.set(x + 1, y + 1, "U")
        g.outline()
        frames.append(g.image())
    return strip(frames, 5, 7)


def main():
    os.makedirs(FX, exist_ok=True)
    os.makedirs(UI, exist_ok=True)
    golem_shockwave().save(f"{FX}/golem_shockwave.png")
    golem_warning().save(f"{FX}/golem_warning.png")
    fade_in, fade_out = ghost_fades()
    fade_in.save(f"{FX}/ghost_fade_in.png")
    fade_out.save(f"{FX}/ghost_fade_out.png")
    damage_digits().save(f"{UI}/damage_digits.png")


if __name__ == "__main__":
    main()
