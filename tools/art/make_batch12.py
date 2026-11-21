"""Batch 12 (stage 42: floors of different styles with their own enemies, a better shop),
the parts drawn in code (docs/art-style.md palette). The drowned and the ember imp come
from PixelLab: tools/art/import_batch12_enemies.py.
Output:
  assets/art/fx/warden_boulder.png      16x16, 4 frames, loop: rolling marble chunk with a
                                        purple glint, flies right, centre (8, 8)
  assets/art/fx/warden_boulder_hit.png  24x24, 4 frames, once: dust and stone chips, centre (12, 13)
  assets/art/fx/imp_fireball.png        8x8, 4 frames, loop, flies right, core (5, 4)
  assets/art/tiles/flooded_decals.png   16x16 each (64x16): puddle, seaweed, shells, ripple puddle
  assets/art/ui/shop_icons2.png         16x16 each (80x16): whetstone, dice, heart elixir,
                                        lucky charm, rune key (same frame as shop_icons.png)
  assets/art/props/merchant_sign.png    16x24: a signpost with a hanging board, bottom row 23
  assets/art/ui/floor_plates.png        64x16 each, stacked (64x48): ruins, flooded, fire;
                                        the middle (x 12-51, y 4-11) is left plain for the title
  assets/art/enemies/tide_crab_*.png    16x16, 4 directions: idle 4, walk 4 (sideways scuttle),
                                        attack 4 (claws raised 0-1, hold 1; snap 2), hurt 2,
                                        death 4 (one strip); tide_crab_frames.tres
  assets/art/enemies/magma_beetle_*.png the beetle (16x16, same feet and size) with a basalt
                                        shell and lava seams; attack as beetle_attack (crouch
                                        0-1, hold 1; bite 2); own death 4 (cracks open, lava
                                        spills); magma_beetle_frames.tres
Run from the project root: python tools/art/make_batch12.py
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_action_frames as actions  # noqa: E402
import make_element_frames as el  # noqa: E402

ENEMIES = "assets/art/enemies"
C = {
    "o": "#08070b", "d": "#0f0e14", "k": "#17161f", "g": "#1f1e29", "s5": "#2a2935",
    "f": "#343442", "F": "#3f4050", "e": "#4c4e5f", "s": "#5d6072", "T": "#767a8c",
    "n": "#263a32", "N": "#3b5a45", "m": "#9aa2ad", "w": "#d8d4c4", "W": "#f4f0e0",
    "b": "#4a2f22", "B": "#7a4a2c", "c": "#b07040", "u": "#e0a070",
    "r": "#5a1820", "R": "#a82a30", "q": "#e85a3a", "y": "#8a4a10", "Y": "#e09a20", "Z": "#ffd860",
    "j": "#1e3f6a", "l": "#3a7ac0", "L": "#7ac0f0", "h": "#4a2a78", "H": "#9a5ae0",
    "a": "#2aa8a0", "A": "#9af0e0", "G": "#5a8a4a", "V": "#8ac060",
}


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def rgb(k):
    return hexc(C[k])


def put(img, x, y, k):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgb(k))


def get(img, x, y):
    if 0 <= x < img.width and 0 <= y < img.height:
        return img.getpixel((x, y))
    return (0, 0, 0, 0)


def outline(img, skip=()):
    out = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                p = get(img, x + dx, y + dy)
                if p[3] and p not in skip:
                    out.putpixel((x, y), rgb("o"))
                    break
    return out


def from_map(rows, w, h):
    img = Image.new("RGBA", (w, h))
    for y, row in enumerate(rows):
        x = 0
        i = 0
        while i < len(row) and x < w:
            ch = row[i]
            if ch != ".":
                put(img, x, y, ch)
            x += 1
            i += 1
    return img


def strip(frames):
    w, h = frames[0].size
    img = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        img.paste(f, (i * w, 0))
    return img


# --- 1. Warden boulder ------------------------------------------------------------

def boulder(frame):
    img = Image.new("RGBA", (16, 16))
    cx, cy, r = 8.0, 8.0, 5.2
    lumps = [(0.0, 0.0), (1.1, 0.4), (2.3, -0.5), (3.6, 0.3), (4.8, -0.3)]
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            ang = math.atan2(dy, dx)
            rr = r + 0.6 * math.sin(ang * 3 + frame * math.pi / 2)   # lumpy edge turns with it
            if math.hypot(dx, dy) <= rr:
                s = (dx + dy) / r
                put(img, x, y, "W" if s < -0.9 else ("w" if s < 0.2 else ("m" if s < 0.9 else "T")))
    # a crack with a purple glint, turning with the roll (it flies right: clockwise)
    a = frame * math.pi / 4
    for t in range(-3, 4):
        put(img, cx + math.cos(a) * t, cy + math.sin(a) * t, "h")
    put(img, cx + math.cos(a) * 2, cy + math.sin(a) * 2, "H")
    img = outline(img)
    # dust trail behind it
    for i in range(2):
        put(img, 1 + i, 9 + (frame + i) % 3 - 1, "m")
    return img


def boulder_hit(frame):
    img = Image.new("RGBA", (24, 24))
    cx, cy = 12, 13
    rnd = random.Random(5)
    chips = [(rnd.random() * math.tau, rnd.uniform(0.7, 1.1)) for _ in range(8)]
    dust_r = (3, 6, 8, 9)[frame]
    for y in range(24):
        for x in range(24):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.4)
            if frame < 3 and dust_r - 1.5 <= d <= dust_r and (x * 3 + y + frame) % 4:
                put(img, x, y, "m" if frame == 0 else ("T" if frame == 1 else "s"))
            elif frame == 3 and abs(d - dust_r) < 0.8 and (x + y) % 3 == 0:
                put(img, x, y, "s")
    if frame == 0:
        for x, y in ((12, 13), (11, 13), (12, 12), (13, 13)):
            put(img, x, y, "W")
        put(img, 14, 11, "H")
        put(img, 9, 12, "H")
    for ang, sp in chips:
        dist = (2, 5, 8, 9)[frame] * sp
        lift = (0, 3, 3, 0)[frame] * sp
        x, y = cx + math.cos(ang) * dist, cy + math.sin(ang) * dist * 0.7 - lift
        put(img, x, y, "w")
        put(img, x + 1, y, "m")
        if frame < 2:
            put(img, x, y - 1, "W")
    return img


# --- imp fireball ------------------------------------------------------------------

def imp_fireball(frame):
    img = Image.new("RGBA", (8, 8))
    for k in range(4):
        put(img, 3 - k, 4 + ((k + frame) % 3 - 1) * (k > 1), "q" if k < 2 else "R")
    for x, y, k in ((4, 3, "Y"), (5, 3, "Y"), (6, 4, "Y"), (4, 5, "Y"), (5, 5, "Y"), (4, 4, "Z"),
                    (5, 4, "W" if frame % 2 else "Z"), (6, 3 + frame % 2 * 2, "q")):
        put(img, x, y, k)
    return img


# --- flooded decals ------------------------------------------------------------------

def flooded_decals():
    out = Image.new("RGBA", (64, 16))
    # 0 puddle: dark water, a lit rim on the top-left, a reflection streak
    p = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            d = ((x + 0.5 - 8) / 6.2) ** 2 + ((y + 0.5 - 9) / 3.6) ** 2
            if d <= 1:
                put(p, x, y, "j" if d > 0.55 else "s5")
                if d > 0.75 and (x + 0.5 - 8) + (y + 0.5 - 9) * 1.5 < -2:
                    put(p, x, y, "e")
    for x in (6, 7, 9):
        put(p, x, 8, "l")
    out.paste(p, (0, 0))
    # 1 seaweed: dark strands lying on the floor
    sw = Image.new("RGBA", (16, 16))
    for i, (x0, y0) in enumerate(((3, 12), (7, 13), (11, 11))):
        for k in range(7):
            put(sw, x0 + math.sin(k * 0.9 + i) * 1.3 + k * 0.4, y0 - k, "N" if k % 3 else "n")
    for x, y in ((5, 8), (9, 6), (12, 9)):
        put(sw, x, y, "G")
    out.paste(sw, (16, 0))
    # 2 shells: two small shells and a broken one
    sh = Image.new("RGBA", (16, 16))
    for x, y, k in ((4, 9, "w"), (5, 9, "m"), (4, 10, "m"), (5, 10, "c"), (3, 10, "w"),
                    (10, 6, "w"), (11, 6, "w"), (10, 7, "m"), (11, 7, "c"), (12, 7, "m"),
                    (9, 12, "m"), (10, 12, "w"), (12, 13, "s")):
        put(sh, x, y, k)
    out.paste(outline(sh), (32, 0))
    # 3 shallow puddle with a ripple ring
    rp = Image.new("RGBA", (16, 16))
    for y in range(16):
        for x in range(16):
            d = ((x + 0.5 - 8) / 5.0) ** 2 + ((y + 0.5 - 8) / 3.0) ** 2
            if d <= 1:
                put(rp, x, y, "s5")
            if 0.25 < d < 0.42:
                put(rp, x, y, "j")
    put(rp, 8, 8, "l")
    out.paste(rp, (48, 0))
    return out


# --- shop goods icons ------------------------------------------------------------------

WHETSTONE = [
    "................",
    "..............m.",
    ".............mW.",
    "............mW..",
    "...........mW...",
    "..Z.......mW....",
    "...Y.Z...mW.....",
    "....ZY.yBy......",
    "..Z..yBBy.......",
    "....wwwBwwww....",
    "...wmmmmmmmmT...",
    "..wmmTmmmTmmmT..",
    "..TTTTTTTTTTTs..",
    "..BBBBBBBBBBBb..",
    "..bbbbbbbbbbbb..",
    "................",
]
DICE = [
    "................",
    "......WWWWW.....",
    ".....WwWWWwW....",
    "....WWWWoWWWW...",
    "....wWWWWWWWm...",
    "....wwWWWWWmm...",
    "....wowwwmmom...",
    "....wwwwwmmmm...",
    "....wwwowmmom...",
    "....wwwwwmmmm...",
    "....wowwwmmom...",
    ".....wwwwmmm....",
    "................",
    "................",
    "................",
    "................",
]
HEART_ELIXIR = [
    "................",
    "......BBB.......",
    "......cBc.......",
    "......mWm.......",
    "...RR.mWm.RR....",
    "..RqqRmWmRqqR...",
    ".RqWqqRRRqqqqR..",
    ".RqWqqqqqqqqqR..",
    ".RqqqqqqqqqqrR..",
    "..RqqqqqqqqrR...",
    "...RqqqqqqrR....",
    "....RqqqqrR.....",
    ".....RqqrR......",
    "......RrR.......",
    ".......R........",
    "................",
]
LUCKY_CHARM = [
    "................",
    ".....y....y.....",
    "......y..y......",
    ".......yy.......",
    "......YZZY......",
    ".....YVGVGY.....",
    "....YVVGGVVY....",
    "....ZGGyyGGZ....",
    "....YVVGGVVY....",
    ".....YGVGVY.....",
    "......YYYY......",
    "................",
    "................",
    "................",
    "................",
    "................",
]
RUNE_KEY = [
    "................",
    "................",
    "..TTTT..........",
    ".TmmmmT.........",
    ".TmhHmT.........",
    ".TmHhmTsssssssT.",
    ".TmmmmTmmmmmmmT.",
    "..TTTT...TmT.Tm.",
    ".........HmH..H.",
    "..........H.....",
    "................",
    "................",
    "................",
    "................",
    "................",
    "................",
]


def shop_icons2():
    out = Image.new("RGBA", (80, 16))
    for i, rows in enumerate((WHETSTONE, DICE, HEART_ELIXIR, LUCKY_CHARM, RUNE_KEY)):
        icon = from_map(rows, 16, 16)
        # shift down so the icons sit centred like shop_icons.png
        box = icon.getbbox()
        cell = Image.new("RGBA", (16, 16))
        cell.alpha_composite(icon.crop(box), ((16 - (box[2] - box[0])) // 2, (16 - (box[3] - box[1])) // 2))
        out.paste(outline(cell), (i * 16, 0))
    return out


# --- merchant sign -------------------------------------------------------------------

MERCHANT_SIGN = [
    "................",
    "...BBBBBBBBBB...",
    "...bBbbbbbbbBb..",
    "....y......y....",
    "....y......y....",
    "..cccccccccccc..",
    "..cBBBBBBBBBBc..",
    "..cBBBYZZYBBBc..",
    "..cBBYZYYZYBBc..",
    "..cBBYZYYZYBBc..",
    "..cBBBYZZYBBBc..",
    "..cBBBBBBBBBBc..",
    "..bbbbbbbbbbbb..",
    "......Bb.qq.....",
    "......Bb.qR.....",
    "......Bb.R......",
    "......Bb........",
    "......Bb........",
    "......Bb........",
    "......Bb........",
    "......Bb........",
    ".....NBbN.......",
    "....bBBbbb......",
    "................",
]


def merchant_sign():
    img = outline(from_map(MERCHANT_SIGN, 16, 24))
    for x in range(4, 12):
        if not img.getpixel((x, 23))[3]:
            put(img, x, 23, "d")
    return img


# --- floor plates ------------------------------------------------------------------------

def plate(style):
    img = Image.new("RGBA", (64, 16))
    base, top, low, accent, accent2 = {
        "ruins": ("s", "T", "e", "h", "H"),
        "flooded": ("s", "T", "e", "l", "L"),
        "fire": ("g", "e", "k", "q", "Z"),
    }[style]
    for y in range(2, 14):
        for x in range(2, 62):
            if (x in (2, 61) and y in (2, 13)):
                continue
            k = base
            if y == 2 or x == 2:
                k = top
            elif y == 13 or x == 61:
                k = low
            put(img, x, y, k)
    # inner frame line and the end ornaments (a diamond on each side)
    for x in range(5, 59):
        put(img, x, 4, low)
        put(img, x, 11, top)
    for cx in (7, 56):
        for dx, dy in ((0, -2), (-1, -1), (0, -1), (1, -1), (-2, 0), (-1, 0), (1, 0), (2, 0), (-1, 1), (0, 1), (1, 1), (0, 2)):
            put(img, cx + dx, 8 + dy, accent)
        put(img, cx, 8, accent2)
        put(img, cx - 1, 7, accent2)
    if style == "flooded":
        for x in range(3, 61):
            if x % 7 in (0, 1, 2):
                put(img, x, 12, "l")
        for x, y in ((14, 13), (33, 13), (47, 13)):
            put(img, x, y + 1, "L")
            put(img, x, y + 2, "l")
        for x in (4, 5, 58, 59):
            put(img, x, 3, "N")
    elif style == "fire":
        for x, y in ((12, 3), (13, 3), (30, 12), (31, 12), (32, 12), (45, 3), (50, 12)):
            put(img, x, y, "q")
        for x in (22, 41):
            put(img, x, 12, "Y")
    else:
        for x, y in ((18, 12), (19, 12), (44, 3)):
            put(img, x, y, "k")
        for x in (4, 59):
            put(img, x, 12, "N")
    return outline(img)


def floor_plates():
    out = Image.new("RGBA", (64, 48))
    for i, style in enumerate(("ruins", "flooded", "fire")):
        out.paste(plate(style), (0, i * 16))
    return out


# --- tide crab --------------------------------------------------------------------------

DIRS = {"down": (0, 1), "up": (0, -1), "right": (1, 0), "left": (-1, 0)}
SQUASH = 0.8   # vertical distances on screen (3/4 view)


def crab(facing, legs=0, raise_claws=0, spread=1, reach=0, shift=(0, 0), curl=False, crack=False, flash=None):
    """One crab frame. facing: down/up/right/left; legs: leg phase 0/1; raise_claws:
    claws lifted (px); spread: pincer gap; reach: claws pushed forward (px)."""
    fx, fy = DIRS[facing]
    px_, py_ = -fy, fx                         # perpendicular (to the crab's left side)
    img = Image.new("RGBA", (16, 16))
    cx, cy = 7.5 + shift[0], 9.0 + shift[1]

    def scr(u, v):
        """crab-local (u forward, v side) -> screen."""
        return cx + fx * u + px_ * v, cy + (fy * u + py_ * v) * SQUASH

    # legs: three a side, alternating
    if not curl:
        for side in (-1, 1):
            for i, u in enumerate((-1.5, 0.0, 1.5)):
                lift = 1 if (i + legs + (side > 0)) % 2 else 0
                for t in (4.6, 5.6):
                    x, y = scr(u + (t - 4.6) * 0.6 * (1 if i == 2 else -0.3), side * t)
                    put(img, x, y - lift * (t > 5), "R")
    # shell
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - cx, (y + 0.5 - cy) / SQUASH
            u, v = dx * fx + dy * fy, dx * px_ + dy * py_
            if (u / 3.3) ** 2 + (v / 4.6) ** 2 <= 1:
                s = (x + 0.5 - cx) / 4.6 + (y + 0.5 - cy) / 3.6    # light from the top-left
                put(img, x, y, "w" if s < -0.85 else ("m" if s < 0.1 else ("T" if s < 0.75 else "s")))
    # barnacles
    for u, v in ((-1.0, 2.0), (0.5, -2.4), (-1.8, -0.6)):
        x, y = scr(u, v)
        put(img, x, y, "W")
    if crack:
        for t in range(-3, 4):
            x, y = scr(t * 0.4, t)
            put(img, x, y, "o")
    # eyes on stalks at the front edge (hidden from behind)
    if facing != "up":
        for v in (-1.2, 1.2):
            x, y = scr(3.3, v)
            put(img, x, y, "o")
            put(img, x, y - 1, "W")
    # claws
    for side in (-1, 1):
        if raise_claws:
            # lifted beside the shell and above it, so they show against the floor
            x, y = scr(1.5, side * 4.6)
            y -= raise_claws + 1
        else:
            x, y = scr(4.2 + reach, side * 3.0)
        if facing == "up" and not raise_claws:
            continue                            # behind the shell
        for dx, dy in ((0, 0), (1, 0), (0, 1), (1, 1)):
            put(img, x + dx - 0.5, y + dy - 0.5, "q")
        # pincer: two prongs pointing forward, opened by spread
        for p in (-1, 1):
            tx, ty = x + fx * 1.6 + px_ * p * (0.5 + spread * 0.5), y + (fy * 1.6 + py_ * p * (0.5 + spread * 0.5)) * SQUASH
            put(img, tx, ty, "R" if p < 0 else "q")
    img = outline(img)
    # shadow under the crab
    for x in range(3, 13):
        if not img.getpixel((x, 14))[3]:
            put(img, x, 14, "d")
    if flash:
        px = img.load()
        for y in range(16):
            for x in range(16):
                p = px[x, y]
                if p[3] and p[:3] not in (hexc("#08070b")[:3], hexc("#0f0e14")[:3]):
                    px[x, y] = rgb(flash)
    return img


def tide_crab():
    strips = {}
    for d, (fx, fy) in DIRS.items():
        px_, py_ = -fy, fx
        strips[f"idle_{d}"] = [crab(d, spread=s, shift=(0, b)) for s, b in ((1, 0), (0.5, 0), (1, 0), (1.5, 0))]
        strips[f"walk_{d}"] = [crab(d, legs=i % 2, shift=(px_ * o, py_ * o * SQUASH)) for i, o in enumerate((-1, 0, 1, 0))]
        strips[f"attack_{d}"] = [crab(d, raise_claws=3, spread=2, shift=(-fx, -fy)),
                                 crab(d, raise_claws=4, spread=2.5, shift=(-fx, -fy)),
                                 crab(d, reach=2, spread=0, shift=(fx, fy)),
                                 crab(d, reach=1, spread=0.5)]
        strips[f"hurt_{d}"] = [crab(d, flash="W"), crab(d, shift=(-fx, -fy))]
    strips["death"] = [crab("down", flash="W"), crab("down", curl=True), crab("down", curl=True, crack=True),
                       crab_debris()]
    for name, frames in strips.items():
        strip(frames).save(os.path.join(ENEMIES, f"tide_crab_{name}.png"))
    actions.F = 16
    actions.write_frames(ENEMIES, "tide_crab", os.path.join(ENEMIES, "tide_crab_frames.tres"))


def crab_debris():
    img = Image.new("RGBA", (16, 16))
    for x, y, k in ((4, 11, "m"), (5, 11, "T"), (5, 10, "w"), (9, 12, "m"), (10, 12, "s"), (10, 11, "T"),
                    (7, 13, "q"), (12, 10, "R"), (3, 13, "R")):
        put(img, x, y, k)
    img = outline(img)
    for x in range(4, 12):
        if not img.getpixel((x, 14))[3]:
            put(img, x, 14, "d")
    return img


# --- magma beetle -----------------------------------------------------------------------

MAGMA = {"#2aa8a0": "#5d6072", "#9af0e0": "#9aa2ad", "#1e3f6a": "#1f1e29", "#7ac0f0": "#e85a3a",
         "#f4f0e0": "#ffd860", "#d8d4c4": "#e09a20", "#3a7ac0": "#a82a30"}
MAGMA = {hexc(k)[:3]: hexc(v) for k, v in MAGMA.items()}
SHELL = hexc("#5d6072")


def magma_frame(img):
    out = img.copy()
    px = out.load()
    for y in range(img.height):
        for x in range(img.width):
            p = px[x, y]
            if p[3] and p[:3] in MAGMA:
                px[x, y] = MAGMA[p[:3]]
    # lava seams: shell pixels with darker shell or seam to the left and right
    src = out.copy().load()
    for y in range(1, img.height - 1):
        for x in range(1, img.width - 1):
            if src[x, y] == SHELL and src[x, y - 1] == SHELL and src[x, y + 1][:3] in (hexc("#1f1e29")[:3], hexc("#2a2935")[:3]):
                px[x, y] = hexc("#e85a3a")
    return out


def magma_beetle():
    import glob
    for path in sorted(glob.glob(os.path.join(ENEMIES, "beetle_*.png"))):
        name = os.path.basename(path)
        if not any(name.startswith(f"beetle_{a}") for a in ("idle", "walk", "attack", "hurt")):
            continue
        img = Image.open(path).convert("RGBA")
        out = Image.new("RGBA", img.size)
        for i in range(img.width // 16):
            out.paste(magma_frame(img.crop((i * 16, 0, i * 16 + 16, 16))), (i * 16, 0))
        out.save(os.path.join(ENEMIES, name.replace("beetle_", "magma_beetle_", 1)))
    actions.F = 16
    idle = magma_frame(actions.frame(os.path.join(ENEMIES, "beetle_idle_down.png")))
    strip(magma_death(idle)).save(os.path.join(ENEMIES, "magma_beetle_death.png"))
    actions.write_frames(ENEMIES, "magma_beetle", os.path.join(ENEMIES, "magma_beetle_frames.tres"))


def magma_death(idle):
    body = actions.body_only(idle)
    box = body.getbbox()
    cx, cy = (box[0] + box[2]) / 2, (box[1] + box[3]) / 2
    # 0 the seams flare up
    f0 = idle.copy()
    px = f0.load()
    for y in range(16):
        for x in range(16):
            if px[x, y][3] and px[x, y][:3] in (hexc("#e85a3a")[:3], hexc("#ffd860")[:3]):
                px[x, y] = rgb("Z")
            elif px[x, y] == SHELL:
                px[x, y] = rgb("q") if (x + y) % 3 == 0 else px[x, y]
    # 1 the shell cracks open along the middle, lava inside
    f1 = idle.copy()
    for y in range(box[1], box[3]):
        x = int(cx + math.sin(y * 1.3) * 0.8)
        put(f1, x, y, "Z")
        put(f1, x + 1, y, "q")

    def pool(r, img):
        for y in range(16):
            for x in range(16):
                d = ((x + 0.5 - cx) / r) ** 2 + ((y + 0.5 - (box[3] - 1)) / (r * 0.45)) ** 2
                if d <= 1 and not img.getpixel((x, y))[3]:
                    put(img, x, y, "Y" if d < 0.3 else ("q" if d < 0.7 else "R"))
        return img
    # 2 squashed, lava spilling around it
    f2 = pool(5, actions.squash(f1, 0.55))
    # 3 a lava puddle with shell bits
    f3 = pool(6, Image.new("RGBA", (16, 16)))
    for x, y in ((int(cx) - 3, box[3] - 2), (int(cx) + 2, box[3] - 1), (int(cx), box[3] - 3)):
        put(f3, x, y, "k")
        put(f3, x + 1, y, "e")
    return [f0, f1, f2, f3]


def main():
    strip([boulder(f) for f in range(4)]).save("assets/art/fx/warden_boulder.png")
    strip([boulder_hit(f) for f in range(4)]).save("assets/art/fx/warden_boulder_hit.png")
    strip([imp_fireball(f) for f in range(4)]).save("assets/art/fx/imp_fireball.png")
    flooded_decals().save("assets/art/tiles/flooded_decals.png")
    shop_icons2().save("assets/art/ui/shop_icons2.png")
    merchant_sign().save("assets/art/props/merchant_sign.png")
    floor_plates().save("assets/art/ui/floor_plates.png")
    tide_crab()
    magma_beetle()
    print("batch 12 art written")


if __name__ == "__main__":
    main()
