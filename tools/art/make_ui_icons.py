"""HUD and menu art (docs/art-style.md, 32-color palette), drawn in code with the
helpers of make_world_props.py:
- Icons 16x16 (the UI scales them 2x): assets/art/ui/icon_{sword,bow,dash,block,coin,
  hp,swap,pause,take,depth}.png
- Joystick base 48x48 and knob 16x16: assets/art/ui/joystick.png (base),
  joystick_knob.png. Drawn opaque; the HUD can fade them with modulate.
- HP bar 64x8: assets/art/ui/hp_bar_frame.png (frame, dark inside) and
  hp_bar_fill.png (the red fill alone, inside the frame's 62x6 hole).
- Rarity frames 18x18, common / rare / legendary in one strip: assets/art/ui/rarity_frame.png
- 9-slice panel 16x16 (margins 4): assets/art/ui/panel.png; button 16x16, normal and
  pressed in one strip (margins 4): assets/art/ui/button.png
Run from the project root: python tools/art/make_ui_icons.py
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_world_props import Grid  # noqa: E402

UI = "assets/art/ui"


def line(g, x0, y0, x1, y1, key):
    """Bresenham line."""
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        g.set(x0, y0, key)
        if x0 == x1 and y0 == y1:
            return
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy


def disc(g, cx, cy, r, shade):
    """Filled circle; shade(dx, dy, dist) gives each pixel's key (offsets from the centre)."""
    for y in range(g.h):
        for x in range(g.w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.sqrt(dx * dx + dy * dy)
            if d <= r:
                g.set(x, y, shade(dx, dy, d))


def sword():
    g = Grid(16, 16)
    line(g, 6, 9, 12, 3, "U")
    line(g, 7, 9, 13, 3, "m")
    line(g, 7, 10, 13, 4, "m")
    g.set(13, 2, "U")
    g.set(14, 2, "m")
    line(g, 3, 7, 8, 12, "Y")
    line(g, 4, 7, 8, 11, "Z")
    line(g, 3, 12, 5, 10, "B")
    line(g, 4, 12, 6, 10, "b")
    g.set(2, 13, "Y")
    g.set(3, 13, "y")
    g.set(2, 14, "y")
    g.outline()
    return g


def bow():
    g = Grid(16, 16)
    # Arc bulging right, string on the left, an arrow pointing right.
    for y in range(2, 15):
        t = (y - 8) / 6.0
        x = 5 + int(round(6 * math.sqrt(max(0.0, 1 - t * t))))
        g.set(x, y, "c" if y < 8 else "B")
        g.set(x - 1, y, "B" if y < 8 else "b")
    line(g, 5, 2, 5, 14, "W")
    line(g, 3, 8, 12, 8, "B")
    g.set(13, 8, "U")
    g.set(14, 8, "m")
    g.set(13, 7, "m")
    g.set(13, 9, "m")
    g.set(2, 7, "q")
    g.set(3, 7, "q")
    g.set(2, 9, "R")
    g.set(3, 9, "R")
    g.outline()
    return g


def dash():
    g = Grid(16, 16)
    for x0, light, dark in ((3, "l", "j"), (8, "L", "l")):
        for i in range(5):
            g.set(x0 + i, 3 + i, light)
            g.set(x0 + i + 1, 3 + i, light)
            g.set(x0 + i, 13 - i, dark)
            g.set(x0 + i + 1, 13 - i, dark)
        g.set(x0 + 5, 8, light)
        g.set(x0 + 6, 8, "U" if light == "L" else light)
    g.outline()
    return g


def block():
    g = Grid(16, 16)

    def shade(dx, dy, d):
        if d > 5.2:
            return "U" if dx + dy < -4.5 else "m" if dx + dy < 3 else "S"
        if d < 1.6:
            return "U" if dx + dy < 0 else "m"
        return "c" if dx + dy < -2 else "B" if dx + dy < 3 else "b"

    disc(g, 8, 8, 6.6, shade)
    for y in (4, 12):
        for x in range(5, 12):
            if g.get(x, y) in ("c", "B", "b"):
                g.set(x, y, "b")
    g.outline()
    return g


def coin():
    g = Grid(16, 16)

    def shade(dx, dy, d):
        if 3.4 < d <= 4.4:
            return "y"
        if dx + dy < -3:
            return "Z"
        return "Y" if dx + dy < 3 else "y"

    disc(g, 8, 8, 6.2, shade)
    g.outline()
    return g


def heart():
    g = Grid(16, 16)
    rows = [
        "................",
        "................",
        "................",
        "...qqq...RRR....",
        "..qUqqR.RRRRr...",
        "..qUqRRRRRRRr...",
        "..qqRRRRRRRRr...",
        "..qRRRRRRRRRr...",
        "...RRRRRRRRr....",
        "....RRRRRRr.....",
        ".....RRRRr......",
        "......RRr.......",
        ".......r........",
        "................",
        "................",
        "................",
    ]
    for y, row in enumerate(rows):
        for x, c in enumerate(row):
            if c != ".":
                g.set(x, y, c)
    g.outline()
    return g


def swap():
    g = Grid(16, 16)
    line(g, 2, 5, 11, 5, "U")
    for i in range(1, 3):
        g.set(11 - i, 5 - i, "U")
        g.set(11 - i, 5 + i, "U")
    line(g, 13, 10, 4, 10, "m")
    for i in range(1, 3):
        g.set(4 + i, 10 - i, "m")
        g.set(4 + i, 10 + i, "m")
    g.outline()
    return g


def pause():
    g = Grid(16, 16)
    for x0 in (4, 9):
        g.rect(x0, 3, x0 + 2, 12, "m")
        g.rect(x0, 3, x0, 12, "U")
        g.rect(x0, 3, x0 + 2, 3, "U")
    g.outline()
    return g


def take():
    g = Grid(16, 16)
    # A gold arrow down into an open tray: pick up.
    g.rect(7, 1, 8, 6, "Y")
    g.rect(7, 1, 7, 6, "Z")
    for i in range(3):
        line(g, 4 + i, 6 + i, 11 - i, 6 + i, "Y")
    g.set(5, 6, "Z")
    g.set(6, 7, "Z")
    line(g, 2, 10, 2, 13, "m")
    line(g, 13, 10, 13, 13, "S")
    line(g, 2, 13, 13, 13, "S")
    line(g, 3, 13, 12, 13, "m")
    g.set(2, 10, "U")
    g.outline()
    return g


def depth():
    g = Grid(16, 16)
    # Four steps going down to the right, seen from the side.
    for i in range(4):
        x0, y0 = 1 + i * 3, 2 + i * 3
        g.rect(x0, y0, x0 + 2, 13, "S")
        g.rect(x0, y0, x0 + 2, y0, "T")
        g.rect(x0, y0, x0, 13, "T" if i == 0 else "e")
    g.rect(1, 13, 12, 13, "e")
    # A small gold arrow pointing down the stairs.
    g.rect(12, 1, 13, 4, "Y")
    g.rect(12, 1, 12, 4, "Z")
    g.rect(11, 5, 14, 5, "Y")
    g.rect(12, 6, 13, 6, "Y")
    g.outline()
    return g


def joystick_base():
    g = Grid(48, 48)

    def shade(dx, dy, d):
        if d > 19.5:
            return "T" if dx + dy < -14 else "S" if dx + dy < 14 else "e"
        if d > 18.5:
            return "o"
        return "k"

    disc(g, 24, 24, 22.6, shade)
    # Notches at the four directions.
    for x, y in ((24, 7), (23, 7), (24, 40), (23, 40), (7, 24), (7, 23), (40, 24), (40, 23)):
        g.set(x, y, "e")
    g.outline()
    return g


def joystick_knob():
    g = Grid(16, 16)

    def shade(dx, dy, d):
        if d < 2.5 and dx + dy < 0:
            return "U"
        return "T" if dx + dy < -2 else "m" if dx + dy < 3.5 else "S"

    disc(g, 8, 8, 6.6, shade)
    g.outline()
    return g


def hp_bar():
    frame = Grid(64, 8)
    frame.rect(0, 0, 63, 7, "o")
    frame.rect(1, 1, 62, 6, "k")
    fill = Grid(64, 8)
    fill.rect(1, 1, 62, 6, "R")
    fill.rect(1, 1, 62, 1, "q")
    fill.rect(1, 2, 62, 2, "q")
    fill.rect(1, 6, 62, 6, "r")
    for x in range(4, 62, 9):
        fill.set(x, 1, "U")
    return frame, fill


def rarity_frames():
    img = Image.new("RGBA", (54, 18))
    for i, (light, mid, dark) in enumerate((("U", "m", "S"), ("L", "l", "j"), ("Z", "Y", "y"))):
        g = Grid(18, 18)
        g.rect(0, 0, 17, 17, "o")
        g.rect(1, 1, 16, 16, mid)
        g.rect(1, 1, 16, 1, light)
        g.rect(1, 1, 1, 16, light)
        g.rect(16, 2, 16, 16, dark)
        g.rect(2, 16, 16, 16, dark)
        g.rect(2, 2, 15, 15, ".")
        g.set(2, 2, light)
        img.paste(g.image(), (18 * i, 0))
    return img


def panel():
    g = Grid(16, 16)
    g.rect(0, 0, 15, 15, "o")
    g.rect(1, 1, 14, 14, "S")
    g.rect(1, 1, 14, 1, "T")
    g.rect(1, 1, 1, 14, "T")
    g.rect(2, 14, 14, 14, "e")
    g.rect(14, 2, 14, 14, "e")
    g.rect(3, 3, 12, 12, "k")
    g.rect(2, 2, 13, 2, "o")
    g.rect(2, 2, 2, 13, "o")
    g.rect(2, 13, 13, 13, "o")
    g.rect(13, 2, 13, 13, "o")
    return g.image()


def button():
    img = Image.new("RGBA", (32, 16))
    for i, pressed in enumerate((False, True)):
        g = Grid(16, 16)
        g.rect(0, 0, 15, 15, "o")
        top, bottom = ("e", "T") if pressed else ("T", "e")
        g.rect(1, 1, 14, 14, "S" if not pressed else "e")
        g.rect(1, 1, 14, 1, top)
        g.rect(1, 1, 1, 14, top)
        g.rect(2, 14, 14, 14, bottom if not pressed else "S")
        g.rect(14, 2, 14, 14, bottom if not pressed else "S")
        if not pressed:
            g.rect(1, 13, 14, 13, "e")
        img.paste(g.image(), (16 * i, 0))
    return img


def main():
    os.makedirs(UI, exist_ok=True)
    for name, make in (("sword", sword), ("bow", bow), ("dash", dash), ("block", block), ("coin", coin),
                       ("hp", heart), ("swap", swap), ("pause", pause), ("take", take), ("depth", depth)):
        make().image().save(f"{UI}/icon_{name}.png")
    joystick_base().image().save(f"{UI}/joystick.png")
    joystick_knob().image().save(f"{UI}/joystick_knob.png")
    frame, fill = hp_bar()
    frame.image().save(f"{UI}/hp_bar_frame.png")
    fill.image().save(f"{UI}/hp_bar_fill.png")
    rarity_frames().save(f"{UI}/rarity_frame.png")
    panel().save(f"{UI}/panel.png")
    button().save(f"{UI}/button.png")


if __name__ == "__main__":
    main()
