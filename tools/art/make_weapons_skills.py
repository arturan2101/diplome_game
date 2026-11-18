"""Skills and new weapons (plan group 3), 32-colour palette, drawn in code with the
helpers of make_world_props.py, make_ui_icons.py and make_combat_fx.py:
- Skill icons 16x16: parry (crossed blades with a spark), teleport (violet swirl):
  assets/art/ui/icon_parry.png, icon_teleport.png
- Parry flash 32x32, 4 frames, one pass: assets/art/fx/parry_flash.png
- Teleport out and in, 32x32, 5 frames each: assets/art/fx/teleport_out.png, teleport_in.png
- Weapons by rarity (common steel, rare blue, legendary gold), 16x16:
  assets/art/weapons/{spear,daggers,crossbow}_{common,rare,legendary}.png
- Attack effects, pointing right: spear thrust 48x16 (3 frames, the streak starts at
  the wielder on the left edge), dagger slash 32x32 (3 frames, centred on the wielder),
  crossbow bolt 16x16 (tip at (14, 8)): assets/art/fx/spear_thrust.png,
  dagger_slash.png, assets/art/weapons/crossbow_bolt.png
Run from the project root: python tools/art/make_weapons_skills.py
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_world_props import Grid, slash  # noqa: E402
from make_ui_icons import line  # noqa: E402

UI, FX, WEAPONS = "assets/art/ui", "assets/art/fx", "assets/art/weapons"
# Rarity accents: (light, mid, dark) for metal parts, and the blade's glint.
RARITY = {
    "common": (("U", "m", "S"), "U"),
    "rare": (("L", "l", "j"), "U"),
    "legendary": (("Z", "Y", "y"), "Z"),
}


def strip(frames, w, h):
    img = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        img.paste(f, (w * i, 0))
    return img


def icon_parry():
    g = Grid(16, 16)
    line(g, 2, 13, 12, 3, "U")
    line(g, 3, 13, 13, 3, "m")
    line(g, 13, 13, 3, 3, "U")
    line(g, 12, 13, 2, 3, "m")
    for x, y in ((1, 14), (2, 14), (14, 14), (13, 14)):
        g.set(x, y, "B")
    g.outline()
    # The spark where the blades meet (no outline: it glows).
    for x, y, key in ((7, 7, "Z"), (8, 7, "Z"), (7, 8, "Z"), (8, 8, "Z"), (7, 5, "Y"), (8, 10, "Y"),
                      (5, 7, "Y"), (10, 8, "Y"), (7, 6, "U"), (8, 9, "U")):
        g.set(x, y, key)
    return g.image()


def icon_teleport():
    g = Grid(16, 16)
    for k in range(60):
        t = k / 60.0
        a = t * math.tau * 1.6
        r = 1.0 + t * 5.5
        x, y = int(round(8 + math.cos(a) * r)), int(round(8 + math.sin(a) * r * 0.85))
        g.set(x, y, "H" if t > 0.35 else "U")
    g.outline()
    for x, y in ((2, 2), (13, 3), (12, 13)):
        g.set(x, y, "Z")
    return g.image()


def parry_flash():
    frames = []
    for i in range(4):
        g = Grid(32, 32)
        c = 16
        if i == 0:
            for d in range(-2, 3):
                g.set(c + d, c, "U")
                g.set(c, c + d, "U")
            g.set(c, c, "Z")
        elif i == 1:
            for d in range(-11, 12):
                key = "U" if abs(d) < 4 else "Z" if abs(d) < 8 else "Y"
                g.set(c + d, c, key)
                g.set(c, c + d, key)
            for d in range(-4, 5):
                g.set(c + d, c + d, "Z" if abs(d) < 3 else "Y")
                g.set(c + d, c - d, "Z" if abs(d) < 3 else "Y")
            g.set(c, c, "U")
        else:
            radius = 8 if i == 2 else 12
            for y in range(32):
                for x in range(32):
                    r = math.hypot(x + 0.5 - c, y + 0.5 - c)
                    if radius - 1.2 <= r <= radius:
                        seg = int((math.atan2(y - c, x - c) + math.pi) / math.tau * 16)
                        if i == 2 or seg % 2 == 0:
                            g.set(x, y, "Z" if i == 2 else "Y")
            for k in range(8):
                a = k * math.tau / 8 + math.pi / 8
                rr = radius + (2 if i == 2 else 3)
                g.set(int(round(c + math.cos(a) * rr)), int(round(c + math.sin(a) * rr)), "U" if i == 2 else "Y")
        frames.append(g.image())
    return strip(frames, 32, 32)


def _column(column, spark_r, spark_rise, ring=False, core=False):
    """A body-sized column of violet light, stippled to column (0..1), with sparks."""
    g = Grid(32, 32)
    cx, cy, rx, ry = 16.0, 15.0, 6.5, 11.0
    patterns = {0.25: lambda x, y: (x + 2 * y) % 4 == 0, 0.5: lambda x, y: (x + y) % 2 == 0,
                0.75: lambda x, y: (x + 2 * y) % 4 != 0, 1.0: lambda x, y: True}
    lit = patterns.get(column)
    for y in range(32):
        for x in range(32):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d > 1.0:
                continue
            if ring and d > 0.75:
                g.set(x, y, "U")
            elif lit and lit(x, y):
                g.set(x, y, "H" if d < 0.5 or column >= 0.75 else "h")
    if core:
        for y in range(6, 25):
            g.set(16, y, "U")
    for k in range(8 if spark_r else 0):
        a = k * math.tau / 8 + 0.4
        x = int(round(cx + math.cos(a) * spark_r * 0.8))
        y = int(round(cy + math.sin(a) * spark_r - spark_rise))
        g.set(x, y, "Z" if k % 2 else "H")
    # Ground ring under the feet.
    if column or ring:
        for x in range(10, 23):
            if x in (10, 22):
                continue
            g.set(x, 27, "H")
        g.set(10, 26, "h")
        g.set(22, 26, "h")
    return g.image()


def teleport():
    out = [_column(0, 0, 0, ring=True), _column(1.0, 0, 0, core=True), _column(0.5, 6, 2), _column(0.25, 10, 5),
           _column(0, 13, 9)]
    come = [_column(0, 13, 0), _column(0.25, 9, 0), _column(0.5, 5, 0), _column(1.0, 0, 0, core=True),
            _column(0, 0, 0, ring=True)]
    return strip(out, 32, 32), strip(come, 32, 32)


def spear(rarity):
    (light, mid, dark), glint = RARITY[rarity]
    g = Grid(16, 16)
    line(g, 1, 14, 10, 5, "B")
    line(g, 2, 14, 11, 5, "b")
    # Leaf-shaped head.
    for x, y, key in ((11, 4, glint), (12, 3, glint), (13, 2, glint), (12, 4, "m"), (13, 3, "m"), (14, 1, "U"),
                      (11, 3, "U"), (12, 2, "U"), (13, 4, "m"), (12, 5, "S")):
        g.set(x, y, key)
    # Binding under the head in the rarity colour.
    for x, y, key in ((9, 6, light), (10, 6, mid), (9, 7, mid), (10, 5, light)):
        g.set(x, y, key)
    g.set(1, 15, dark)
    g.outline()
    return g.image()


def daggers(rarity):
    (light, mid, dark), glint = RARITY[rarity]
    g = Grid(16, 16)
    # Two short daggers crossed: blades up, hilts down.
    line(g, 5, 9, 10, 4, glint)
    line(g, 6, 9, 11, 4, "m")
    line(g, 10, 9, 5, 4, glint)
    line(g, 9, 9, 4, 4, "m")
    for x0, sx in ((3, 1), (12, -1)):
        g.set(x0 + 2 * sx, 10, light)
        g.set(x0 + 3 * sx, 10, mid)
        g.set(x0 + 1 * sx, 9, light)
        g.set(x0 + 1 * sx, 11, "B")
        g.set(x0, 12, "b")
        g.set(x0 - sx, 13, dark)
    g.outline()
    return g.image()


def crossbow(rarity):
    (light, mid, dark), glint = RARITY[rarity]
    g = Grid(16, 16)
    # Stock pointing right.
    line(g, 2, 9, 12, 9, "B")
    line(g, 2, 10, 11, 10, "b")
    g.set(2, 11, "b")
    g.set(3, 11, "b")
    # Limbs across the front in the rarity colour, the string behind them.
    for y in range(3, 16 - 1):
        dx = abs(y - 9) // 3
        g.set(11 - dx, y, light if y < 9 else mid)
    g.set(10, 3, dark)
    g.set(10, 14, dark)
    line(g, 9, 4, 6, 9, "W")
    line(g, 9, 14, 6, 9, "W")
    # The bolt on the stock.
    line(g, 5, 8, 13, 8, "m")
    g.set(14, 8, glint)
    g.outline()
    return g.image()


def spear_thrust():
    frames = []
    for i, (x0, x1) in enumerate(((2, 22), (2, 46), (24, 46))):
        g = Grid(48, 16)
        for x in range(x0, x1 + 1):
            t = (x - x0) / max(x1 - x0, 1)
            if i == 2 and x % 3 == 0:
                continue
            g.set(x, 8, "U" if i < 2 else "L")
            if i < 2 and t > 0.3:
                g.set(x, 7, "L")
                g.set(x, 9, "l" if t > 0.6 else "L")
        if i == 1:
            for x, y in ((46, 8), (47, 8), (45, 6), (45, 10), (44, 5), (44, 11)):
                g.set(x, y, "U" if y == 8 else "L")
        frames.append(g.image())
    return strip(frames, 48, 16)


def crossbow_bolt():
    g = Grid(16, 16)
    line(g, 3, 8, 11, 8, "b")
    for x, y, key in ((12, 7, "m"), (12, 8, "U"), (12, 9, "m"), (13, 8, "U"), (14, 8, "m"),
                      (2, 7, "m"), (3, 7, "S"), (2, 9, "m"), (3, 9, "S")):
        g.set(x, y, key)
    g.outline()
    return g.image()


def main():
    for folder in (UI, FX, WEAPONS):
        os.makedirs(folder, exist_ok=True)
    icon_parry().save(f"{UI}/icon_parry.png")
    icon_teleport().save(f"{UI}/icon_teleport.png")
    parry_flash().save(f"{FX}/parry_flash.png")
    out, come = teleport()
    out.save(f"{FX}/teleport_out.png")
    come.save(f"{FX}/teleport_in.png")
    for rarity in RARITY:
        spear(rarity).save(f"{WEAPONS}/spear_{rarity}.png")
        daggers(rarity).save(f"{WEAPONS}/daggers_{rarity}.png")
        crossbow(rarity).save(f"{WEAPONS}/crossbow_{rarity}.png")
    spear_thrust().save(f"{FX}/spear_thrust.png")
    slash(32, 13.5, 100, 4.0, ("U", "L", "l")).save(f"{FX}/dagger_slash.png")
    crossbow_bolt().save(f"{WEAPONS}/crossbow_bolt.png")


if __name__ == "__main__":
    main()
