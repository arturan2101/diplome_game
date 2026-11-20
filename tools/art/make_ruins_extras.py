"""Missing ruins pieces (plan group 4), 32-colour palette:
- Falling-stone trap, 16x16, 6 frames in one strip: warning shadow 2, fall 3, rubble 1:
  assets/art/level/falling_stone.png (96x16)
- Pit edges and corners, 16x16 pit cells that border floor on some sides, matching
  ruins_hazards.png (slot 0 = floor to the north, slot 7 = inside):
  assets/art/tiles/pit_edges.png, slots 0 floor to the west, 1 east, 2 south,
  3 north + west, 4 north + east, 5 south + west, 6 south + east, 7 north + south
- Wall-top autotiles, 4x4 cells of 16x16: index = N + 2*E + 4*S + 8*W, where a bit is
  set when that neighbour is NOT wall; that side gets a dark edge with a lit or shaded
  lip: assets/art/tiles/ruins_wall_set.png (64x64)
- Light shaft from above, 32x48, warm, bottom centre on the node: soft stepped alpha
  (a light, like the light textures) with a few dust motes: assets/art/fx/light_shaft.png
Run from the project root: python tools/art/make_ruins_extras.py
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_world_props import Grid  # noqa: E402

TILES, LEVEL, FX = "assets/art/tiles", "assets/art/level", "assets/art/fx"
T = 16


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def falling_stone():
    frames = []
    # Warning: a stippled shadow that grows, with grit falling into it.
    for i, (rx, ry) in enumerate(((3.5, 2.0), (5.5, 3.0))):
        g = Grid(T, T)
        for y in range(T):
            for x in range(T):
                if ((x + 0.5 - 8) / rx) ** 2 + ((y + 0.5 - 11) / ry) ** 2 <= 1 and (x + y) % 2 == 0:
                    g.set(x, y, "d")
        for x, y in ((7, 2 + i * 3), (9, 5 - i), (6, 7 + i)):
            g.set(x, y, "m")
        frames.append(g.image())

    def rock(g, cx, cy, r):
        inside = [(x, y) for y in range(T) for x in range(T) if math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.15) <= r]
        for x, y in inside:
            s = (x + 0.5 - cx) + (y + 0.5 - cy)
            g.set(x, y, "W" if s < -r * 0.6 else "m" if s < r * 0.3 else "T")
        if r > 3:
            g.set(int(cx) + 1, int(cy) + 1, "e")

    # Fall: the rock comes down onto its shadow, then hits with dust.
    for i, (cy, r, shadow) in enumerate(((3.5, 4.0, 5.5), (7.5, 4.5, 5.5), (11.0, 4.5, 6.5))):
        g = Grid(T, T)
        for y in range(T):
            for x in range(T):
                if ((x + 0.5 - 8) / shadow) ** 2 + ((y + 0.5 - 13) / 2.2) ** 2 <= 1 and (x + y) % 2 == 0:
                    g.set(x, y, "d")
        rock(g, 8.0, cy, r)
        g.outline()
        if i == 2:
            for x, y in ((1, 12), (2, 10), (14, 11), (13, 9), (3, 14), (12, 14)):
                g.set(x, y, "W")
        frames.append(g.image())
    # Rubble left on the floor.
    g = Grid(T, T)
    for cx, cy, r in ((6.0, 11.5, 2.6), (10.5, 12.0, 2.2), (8.5, 9.5, 1.8), (3.5, 13.5, 1.2), (12.5, 14.0, 1.2)):
        rock(g, cx, cy, r)
    g.outline()
    frames.append(g.image())
    img = Image.new("RGBA", (T * len(frames), T))
    for i, f in enumerate(frames):
        img.paste(f, (i * T, 0))
    return img


def pit_edges(hazards):
    rim = hazards.crop((0, 0, T, T))
    inner = hazards.crop((7 * T, 0, 8 * T, T))
    lit, mid, dark = hexc("#5d6072"), hexc("#4c4e5f"), hexc("#17161f")

    def side(t, where):
        px = t.load()
        for k in range(T):
            jag = 1 if (k * 7) % 5 == 0 else 0
            if where == "west":
                px[0, k] = lit
                px[1 + jag, k] = mid
                if not jag:
                    px[2, k] = dark
            elif where == "east":
                px[T - 1, k] = mid
                px[T - 2 - jag, k] = dark
            elif where == "south":
                # The floor's front lip seen from above: a lit edge at the bottom.
                px[k, T - 1] = lit
                px[k, T - 2 - jag] = mid
                if not jag:
                    px[k, T - 3] = dark

    def make(north, sides):
        t = (rim if north else inner).copy()
        for s in sides:
            side(t, s)
        return t

    tiles = [make(False, ["west"]), make(False, ["east"]), make(False, ["south"]), make(True, ["west"]),
             make(True, ["east"]), make(False, ["south", "west"]), make(False, ["south", "east"]),
             make(True, ["south"])]
    img = Image.new("RGBA", (T * len(tiles), T))
    for i, t in enumerate(tiles):
        img.paste(t, (i * T, 0))
    return img


def wall_set(atlas):
    top = atlas.crop((4 * T, 0, 5 * T, T))
    edge, lit, shade = hexc("#17161f"), hexc("#9aa2ad"), hexc("#5d6072")
    img = Image.new("RGBA", (4 * T, 4 * T))
    for mask in range(16):
        t = top.copy()
        px = t.load()
        for k in range(T):
            if mask & 1:   # north open
                px[k, 0] = edge
                px[k, 1] = lit
            if mask & 2:   # east open
                px[T - 1, k] = edge
                px[T - 2, k] = shade
            if mask & 4:   # south open
                px[k, T - 1] = edge
                px[k, T - 2] = shade
            if mask & 8:   # west open
                px[0, k] = edge
                px[1, k] = lit
        img.paste(t, ((mask % 4) * T, (mask // 4) * T))
    return img


def light_shaft():
    w, h = 32, 48
    img = Image.new("RGBA", (w, h))
    px = img.load()
    warm = (255, 216, 96)
    for y in range(h - 6):
        t = y / (h - 7)
        half = 5 + 7 * t
        for x in range(w):
            d = abs(x + 0.5 - w / 2) / half
            if d > 1:
                continue
            band = 3 if d < 0.35 else 2 if d < 0.7 else 1
            fade = 1 if y < 6 else 2 if y < 14 else 3
            alpha = [0, 22, 40, 62][min(band, fade)]
            px[x, y] = warm + (alpha,)
    # A pool of light on the floor at the bottom.
    for y in range(h - 8, h):
        for x in range(w):
            d = ((x + 0.5 - w / 2) / 14) ** 2 + ((y + 0.5 - (h - 4)) / 3.5) ** 2
            if d <= 1:
                alpha = 70 if d < 0.4 else 45
                old = px[x, y][3]
                px[x, y] = warm + (max(old, alpha),)
    for x, y in ((14, 10), (18, 20), (13, 28), (20, 33), (16, 38)):
        px[x, y] = (255, 240, 200, 200)
    return img


def main():
    for folder in (TILES, LEVEL, FX):
        os.makedirs(folder, exist_ok=True)
    falling_stone().save(f"{LEVEL}/falling_stone.png")
    pit_edges(Image.open(f"{TILES}/ruins_hazards.png").convert("RGBA")).save(f"{TILES}/pit_edges.png")
    wall_set(Image.open(f"{TILES}/ruins_tiles_atlas.png").convert("RGBA")).save(f"{TILES}/ruins_wall_set.png")
    light_shaft().save(f"{FX}/light_shaft.png")


if __name__ == "__main__":
    main()
