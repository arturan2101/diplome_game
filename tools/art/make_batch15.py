"""Batch 15, parts 1 and 2 drawn in code: the boss chest and the effects of the two
elemental Wardens (docs/art-style.md palette; the Wardens themselves:
tools/art/make_elemental_wardens.py).
Output:
  assets/art/pickups/chest_boss.png  24x24, 4 frames (96x24): closed, lid ajar, open,
                                     open with a flash; bottom row 22, shadow row 23
  assets/art/fx/water_orb.png        16x16 x 4, loop, flies right, centre (8, 8)
  assets/art/fx/water_orb_burst.png  32x32 x 5, once, centre (16, 18); ends as a puddle
  assets/art/fx/tide_puddle.png      32x32 x 4, loop, centre (16, 16), reach 14 x 10 px
  assets/art/fx/geyser_warn.png      16x16 x 4, loop, centre (8, 9)
  assets/art/fx/geyser.png           16x32 x 6, once, foot on row 31, centre x 8
  assets/art/fx/tide_ring.png        64x64 x 6, once, centre (32, 32), ring radius 6 ... 30
  assets/art/fx/molten_boulder.png   16x16 x 4, loop, flies right, centre (8, 8)
  assets/art/fx/lava_crack_pool.png  32x32 x 7: 0-3 loop, 4-6 cooling (once), centre (16, 16)
  assets/art/fx/molten_ring.png      64x64 x 6, once, centre (32, 32), ring radius 6 ... 30
Run from the project root: python tools/art/make_batch15.py
"""
import math
import random

from PIL import Image

PAL = {
    "o": "#08070b", "d": "#0f0e14", "k": "#17161f", "g": "#1f1e29", "5": "#2a2935",
    "f": "#343442", "F": "#3f4050", "e": "#4c4e5f", "s": "#5d6072", "T": "#767a8c",
    "n": "#263a32", "N": "#3b5a45", "m": "#9aa2ad", "w": "#d8d4c4", "W": "#f4f0e0",
    "b": "#4a2f22", "B": "#7a4a2c", "c": "#b07040", "u": "#e0a070",
    "r": "#5a1820", "R": "#a82a30", "q": "#e85a3a", "y": "#8a4a10", "Y": "#e09a20", "Z": "#ffd860",
    "j": "#1e3f6a", "l": "#3a7ac0", "L": "#7ac0f0", "h": "#4a2a78", "H": "#9a5ae0",
    "a": "#2aa8a0", "A": "#9af0e0", "G": "#5a8a4a", "V": "#8ac060",
    # fungal theme extras (docs/art-style.md "Fungal theme")
    "1": "#2e2622", "2": "#3a3029", "3": "#4a3e33", "p": "#d0a0f0", "x": "#6ae0c0", "v": "#b8e050",
    # sand temple extras (docs/art-style.md "Sand temple theme")
    "6": "#2e251c", "7": "#3a2f24", "8": "#4a3c2c", "9": "#8a7048", "S": "#b0905c", "D": "#d8bc84",
}


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


RGB = {k: hexc(v) for k, v in PAL.items()}
KEY = {v: k for k, v in RGB.items()}


class Canvas:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h))
        self.w, self.h = w, h
        self.px = self.img.load()

    def set(self, x, y, k):
        x, y = int(round(x)), int(round(y))
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = RGB[k]

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h and self.px[x, y][3]:
            return KEY.get(self.px[x, y][:3] + (255,), "?")
        return "."

    def rect(self, x0, y0, x1, y1, k):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, k)

    def outline(self, skip=("d",)):
        edge = []
        for y in range(self.h):
            for x in range(self.w):
                if self.get(x, y) != ".":
                    continue
                if any(self.get(x + dx, y + dy) not in (".", "o") + tuple(skip)
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    edge.append((x, y))
        for x, y in edge:
            self.set(x, y, "o")


def strip(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        out.paste(f, (i * w, 0))
    return out


# --- part 1: boss chest ---------------------------------------------------------------

def chest_body(c, top):
    """Front of the chest, rows top..21, x 3..20: dark stone blocks, gold corner straps,
    a gold lock plate with a purple rune."""
    for y in range(top, 22):
        for x in range(3, 21):
            k = "g"
            if x == 3 or y == top + 1:
                k = "s"                    # lit left edge / lip under the rim
            if x == 20 or y == 21:
                k = "k"
            if y == top + 5 and 6 <= x <= 17:
                k = "k"                    # mortar between the block rows
            if x in (11,) and top + 1 < y < top + 5:
                k = "k"
            if x in (8, 15) and top + 5 < y < 21:
                k = "k"
            c.set(x, y, k)
    for x in range(3, 21):                 # gold rim along the top
        c.set(x, top, "Z" if x < 9 else "Y")
    for x0 in (4, 18):                     # corner straps with rivets
        for y in range(top, 22):
            c.set(x0, y, "Z" if x0 == 4 else "Y")
            c.set(x0 + 1, y, "Y" if x0 == 4 else "y")
        for y in (top + 3, top + 7):
            c.set(x0 + (1 if x0 == 4 else 0), y, "W")
    # lock plate
    for y in range(top + 2, top + 8):
        for x in range(10, 14):
            c.set(x, y, "Y")
    c.set(10, top + 2, "Z")
    c.set(11, top + 2, "Z")
    c.set(13, top + 7, "y")
    c.set(12, top + 7, "y")
    for x, y in ((11, top + 3), (12, top + 3), (11, top + 4), (12, top + 5), (11, top + 6), (12, top + 6)):
        c.set(x, y, "h")
    c.set(11, top + 4, "H")
    c.set(12, top + 5, "o")               # keyhole
    # purple runes cut into the blocks
    for x, y in ((6, top + 2), (7, top + 3), (6, top + 4), (16, top + 7), (16, top + 8), (17, top + 7)):
        c.set(x, y, "H")
    for x, y in ((7, top + 7), (6, top + 8)):
        c.set(x, y, "h")


def chest_lid(c, top, lift=0):
    """Closed domed lid on rows top..top+5."""
    rows = [(5, 18), (4, 19), (3, 20), (3, 20), (3, 20), (3, 20)]
    for i, (x0, x1) in enumerate(rows):
        y = top + i
        for x in range(x0, x1 + 1):
            k = "g"
            if i == 0 or (i == 1 and x < 12):
                k = "T" if i == 0 else "s"
            elif x == x0:
                k = "s"
            elif x == x1:
                k = "k"
            if i == 5:
                k = "y"
            c.set(x, y, k)
    for x0 in (4, 18):
        for i in range(1 if x0 == 4 else 1, 6):
            c.set(x0, top + i, "Z" if x0 == 4 else "Y")
            c.set(x0 + 1, top + i, "Y" if x0 == 4 else "y")
    c.set(5, top + 1, "Y")
    # rune on the lid: a purple eye in a diamond
    cx, cy = 11, top + 3
    for dx, dy in ((0, -1), (1, -1), (-1, 0), (2, 0), (0, 1), (1, 1)):
        c.set(cx + dx, cy + dy, "h")
    c.set(cx, cy, "H")
    c.set(cx + 1, cy, "H")


def chest_open_lid(c):
    """The lid thrown back: its inner face stands behind the opening, rows 3..10."""
    for y in range(3, 11):
        x0, x1 = (5, 18) if y == 3 else (4, 19) if y == 4 else (3, 20)
        for x in range(x0, x1 + 1):
            k = "k"
            if y == 3:
                k = "s"
            elif x in (x0, x1) or y == 10:
                k = "g"
            c.set(x, y, k)
    for x0 in (4, 18):
        for y in range(4, 11):
            c.set(x0, y, "Y" if x0 == 4 else "y")
            c.set(x0 + 1, y, "y")
    for x in range(6, 18):
        c.set(x, 4, "Y" if x < 12 else "y")   # the gold rim of the lid, seen from inside
    # rune glowing on the inside of the lid
    for x, y in ((11, 6), (12, 6), (10, 7), (13, 7), (11, 8), (12, 8)):
        c.set(x, y, "H")
    c.set(11, 7, "W")
    c.set(12, 7, "H")


def chest_treasure(c, glow):
    """What shows over the front rim when the chest is open (rows 11-12)."""
    for x in range(4, 20):
        c.set(x, 11, "h" if x % 5 else "H")
        c.set(x, 12, "y")
    for x, y, k in ((6, 11, "Y"), (7, 11, "Z"), (7, 10, "Y"), (9, 11, "Y"), (10, 10, "Z"),
                    (14, 11, "Y"), (15, 10, "Y"), (16, 11, "Z"), (12, 11, "H"), (13, 10, "H"),
                    (6, 12, "Y"), (10, 12, "Z"), (11, 12, "Y"), (15, 12, "Y"), (17, 12, "Z")):
        c.set(x, y, k)
    if glow:
        c.set(13, 10, "W")
        c.set(7, 10, "Z")


def chest_frame(i):
    c = Canvas(24, 24)
    if i == 0:
        chest_body(c, 13)
        chest_lid(c, 7)
    elif i == 1:
        chest_body(c, 13)
        chest_lid(c, 5)
        for x in range(4, 20):               # light leaking out of the gap
            c.set(x, 11, "h")
            c.set(x, 12, "H" if x % 3 else "Z")
    else:
        chest_open_lid(c)
        chest_treasure(c, i == 3)
        chest_body(c, 13)
    c.outline()
    if i == 3:                                # flash: a star of light and sparkles, no outline
        cx, cy = 12, 8
        for r in range(1, 7):
            for dx, dy in ((0, -1), (-1, 0), (1, 0)):
                k = "W" if r < 3 else "Z" if r < 5 else "Y"
                c.set(cx + dx * r, cy + dy * r, k)
        for r in range(1, 4):
            for dx, dy in ((-1, -1), (1, -1)):
                c.set(cx + dx * r, cy + dy * r, "Z" if r < 3 else "Y")
        c.set(cx, cy, "W")
        for x, y, k in ((3, 4, "Z"), (21, 3, "Z"), (2, 9, "Y"), (22, 8, "Y"), (6, 1, "H"), (18, 1, "H")):
            c.set(x, y, k)
    for x in range(3, 21):
        c.set(x, 23, "d")
    return c.img


def chest_boss():
    return strip([chest_frame(i) for i in range(4)])


# --- part 2: tide effects ----------------------------------------------------------------

def water_ball(c, cx, cy, r, frame, spin=True):
    """A lit ball of water: dark blue rim bottom-right, light top-left, a turning swirl."""
    for y in range(c.h):
        for x in range(c.w):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            lit = (-dx - dy) / (r * 1.414)
            k = "L" if lit > 0.35 else "l" if lit > -0.45 else "j"
            if d > r - 1 and lit < -0.2:
                k = "j"
            c.set(x, y, k)
    if spin:
        a0 = frame * math.pi / 2
        for t in range(5):
            a = a0 + t * 0.45
            c.set(cx + math.cos(a) * (r - 1.6), cy + math.sin(a) * (r - 1.6), "A" if t < 3 else "a")
    c.set(cx - r * 0.45, cy - r * 0.5, "W")


def water_orb(frame):
    c = Canvas(16, 16)
    water_ball(c, 8.5, 8.5, 4.6, frame)
    c.outline()
    # drops trailing behind it (it flies right)
    for i, (x, y) in enumerate(((2, 8), (1, 10), (3, 11), (2, 6))):
        if (i + frame) % 2 == 0:
            c.set(x + (frame % 2), y, "L" if i % 2 else "l")
    return c.img


def drop(c, x, y, big=False):
    c.set(x, y, "L")
    if big:
        c.set(x, y + 1, "l")


def water_orb_burst(frame):
    c = Canvas(32, 32)
    cx, cy = 16, 18
    rnd = random.Random(7)
    drops = [(rnd.uniform(0, math.tau), rnd.uniform(0.6, 1.0)) for _ in range(10)]
    if frame == 0:
        # the orb hits and flattens, a first ring of spray
        for y in range(32):
            for x in range(32):
                dx, dy = (x + 0.5 - cx) / 7, (y + 0.5 - cy) / 4
                if dx * dx + dy * dy <= 1:
                    c.set(x, y, "L" if dy < -0.3 else "l" if dy < 0.5 else "j")
        c.set(13, 16, "W")
        c.set(14, 16, "W")
    else:
        # puddle grows under the splash
        pr = (6, 9, 11, 12)[frame - 1]
        for y in range(32):
            for x in range(32):
                dx, dy = (x + 0.5 - cx) / pr, (y + 0.5 - cy) / (pr * 0.6)
                d = dx * dx + dy * dy
                if d <= 1:
                    c.set(x, y, "l" if d > 0.6 and dy < 0 else "j")
        # ring of foam on the edge in the early frames
        if frame <= 2:
            for a in range(0, 360, 12):
                t = math.radians(a)
                c.set(cx + math.cos(t) * pr, cy + math.sin(t) * pr * 0.6, "W" if a % 24 else "L")
        # the crown of water in the middle
        if frame in (1, 2):
            h = (6, 4)[frame - 1]
            for x in range(cx - 3, cx + 4):
                top = cy - h + abs(x - cx) // 2
                for y in range(top, cy):
                    c.set(x, y, "L" if x < cx else "l")
                c.set(x, top, "W")
    c.outline(skip=("d", "j", "l"))
    # drops flying out and falling back
    for ang, sp in drops:
        if frame == 4:
            break
        dist = (3, 7, 10, 12)[frame] * sp
        lift = (2, 7, 7, 3)[frame] * sp
        x, y = cx + math.cos(ang) * dist, cy + math.sin(ang) * dist * 0.6 - lift
        drop(c, x, y, frame < 3)
    return c.img


def puddle_mask(x, y, cx, cy, rx, ry, wobble=0.0, phase=0.0):
    dx, dy = x + 0.5 - cx, y + 0.5 - cy
    a = math.atan2(dy, dx)
    k = 1 + wobble * math.sin(a * 3 + phase) + wobble * 0.6 * math.cos(a * 5 - phase)
    return (dx / (rx * k)) ** 2 + (dy / (ry * k)) ** 2


def tide_puddle(frame):
    """A water zone on the floor: a dark body with a bright rim, ripples running out."""
    c = Canvas(32, 32)
    cx, cy, rx, ry = 16, 16, 14, 10
    for y in range(32):
        for x in range(32):
            d = puddle_mask(x, y, cx, cy, rx, ry, 0.05, frame * math.pi / 2)
            if d > 1:
                continue
            k = "j"
            if d > 0.78:
                k = "L" if (y < cy and x < cx + 6) else "a"
            elif d > 0.62:
                k = "l"
            c.set(x, y, k)
    # two ripple rings travelling out (period 4 frames)
    for ring in (frame, frame + 2):
        s = 0.12 + (ring % 4) * 0.12
        for a in range(0, 360, 6):
            t = math.radians(a)
            x = cx + math.cos(t) * rx * s * 1.4
            y = cy + math.sin(t) * ry * s * 1.4
            if c.get(x, y) == "j" and (a // 6 + ring) % 3:
                c.set(x, y, "l")
    # glints
    for x, y in ((10 + frame % 2, 12), (20, 18 - frame % 2)):
        c.set(x, y, "W")
    return c.img


def geyser_warn(frame):
    c = Canvas(16, 16)
    cx, cy = 8, 9
    # a ripple ring pulsing out from the centre, bubbles popping
    r = (2.0, 3.5, 5.0, 6.5)[frame]
    for a in range(0, 360, 8):
        t = math.radians(a)
        x, y = cx + math.cos(t) * r, cy + math.sin(t) * r * 0.6
        c.set(x, y, "L" if frame < 2 else "l")
    inner = (5.5, 1.5, 3.0, 4.5)[frame]
    if frame != 1:
        for a in range(0, 360, 10):
            t = math.radians(a)
            c.set(cx + math.cos(t) * inner, cy + math.sin(t) * inner * 0.6, "j" if frame == 0 else "l")
    bubbles = [((7, 9), (9, 8)), ((8, 8), (6, 10)), ((9, 10), (7, 8)), ((6, 9), (10, 9))][frame]
    for i, (x, y) in enumerate(bubbles):
        c.set(x, y, "A" if i == 0 else "L")
        if i == 0:
            c.set(x, y - 1, "W")
    return c.img


def geyser(frame):
    """A column of water from the floor up; bottom on row 31."""
    c = Canvas(16, 32)
    top = (26, 14, 2, 1, 8, 27)[frame]
    width = (3, 3, 4, 4, 3, 2)[frame]
    cx = 8
    for y in range(top, 31):
        wob = int(round(math.sin(y * 0.7 + frame * 1.3) * 0.8))
        hw = width + (1 if y > 27 else 0)
        for x in range(cx - hw + wob, cx + hw + wob):
            rel = x - (cx - hw + wob)
            k = "L" if rel <= 1 else "j" if rel >= 2 * hw - 1 else "l"
            if (y + frame) % 5 == 0 and rel == hw:
                k = "A"
            c.set(x, y, k)
    if frame < 5:
        # foam on the top
        for x in range(cx - width - 1, cx + width + 1):
            c.set(x, top, "W")
            if (x + frame) % 2:
                c.set(x, top - 1, "w")
    # the base splash on the floor
    for x in range(cx - 6, cx + 7):
        c.set(x, 31, "l" if abs(x - cx) < 5 else "L")
    for x in range(cx - 5, cx + 6):
        c.set(x, 30, "L" if abs(x - cx) > 3 else c.get(x, 30) if c.get(x, 30) != "." else "l")
    c.outline(skip=("d",))
    # spray drops around the column
    rnd = random.Random(frame * 3 + 1)
    n = (2, 4, 6, 6, 6, 3)[frame]
    for _ in range(n):
        y = rnd.randint(max(top, 2), 29)
        x = cx + rnd.choice((-1, 1)) * rnd.randint(width + 2, 7)
        drop(c, x, y, frame in (3, 4))
    return c.img


def ring_frames(style):
    """Ring wave like golem_shockwave, as water (tide) or fire (molten)."""
    size, cc = 64, 32.0
    radii = [6, 12, 18, 23, 27, 30]
    frames = []
    rnd = random.Random(11 if style == "tide" else 13)
    bits = [(rnd.uniform(0, math.tau), rnd.uniform(-1.5, 2.5)) for _ in range(14)]
    for i, radius in enumerate(radii):
        c = Canvas(size, size)
        thick = 3.5 if i < 4 else 2.5
        for y in range(size):
            for x in range(size):
                dx, dy = x + 0.5 - cc, y + 0.5 - cc
                r = math.hypot(dx, dy)
                ang = math.atan2(dy, dx)
                wave = math.sin(ang * 9 + i) * 0.8
                if not (radius - thick + wave <= r <= radius + wave * 0.5):
                    continue
                seg = int((ang + math.pi) / math.tau * 24)
                gaps = 0 if i < 3 else 1 if i < 5 else 2
                if gaps and seg % 4 < gaps:
                    continue
                outer = radius + wave * 0.5 - r
                if style == "tide":
                    k = "W" if outer < 1 else "L" if outer < 2 else "l"
                    if i >= 4:
                        k = "L" if outer < 1 else "l"
                else:
                    k = "Z" if outer < 1 else "Y" if outer < 2 else "q"
                    if i >= 4:
                        k = "q" if outer < 1 else "R"
                c.set(x, y, k)
        c.outline(skip=("d", "j", "a", "r"))
        # inside: wet streaks (tide) or scorched cracks with lava (molten)
        for ang, bend in bits[:8]:
            reach = min(radius - 3, 26)
            for t in range(3, int(reach)):
                a = ang + bend * 0.02 * t
                x, y = cc + math.cos(a) * t, cc + math.sin(a) * t
                if style == "tide":
                    if t % 3 and i < 5:
                        c.set(x, y, "j")
                else:
                    c.set(x, y, "k")
                    if t % 4 == 1 and i < 5:
                        c.set(x, y, "q" if i < 3 else "R")
        # spray / embers thrown out on the ring
        for ang, _ in bits:
            if i == 0:
                break
            rr = radius + 2 + (i % 2)
            x, y = cc + math.cos(ang) * rr, cc + math.sin(ang) * rr - (2 if i < 4 else 0)
            if style == "tide":
                drop(c, x, y, i < 4)
            else:
                c.set(x, y, "Z" if i < 3 else "Y" if i < 5 else "q")
        frames.append(c.img)
    return strip(frames)


# --- part 2: molten effects ----------------------------------------------------------------

def molten_boulder(frame):
    c = Canvas(16, 16)
    cx, cy, r = 8.0, 8.0, 5.2
    for y in range(16):
        for x in range(16):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            ang = math.atan2(dy, dx)
            rr = r + 0.6 * math.sin(ang * 3 + frame * math.pi / 2)
            if math.hypot(dx, dy) <= rr:
                s = (dx + dy) / r
                c.set(x, y, "s" if s < -0.9 else ("g" if s < 0.6 else "k"))
    # lava cracks turning with the roll
    a = frame * math.pi / 4
    for t in range(-3, 4):
        c.set(cx + math.cos(a) * t, cy + math.sin(a) * t, "q")
    for t in (-1, 0, 1):
        c.set(cx + math.cos(a) * t, cy + math.sin(a) * t, "Y")
    b = a + math.pi / 2
    for t in range(1, 4):
        c.set(cx + math.cos(b) * t + 0.5, cy + math.sin(b) * t, "q" if t < 3 else "R")
    c.set(cx + math.cos(a), cy + math.sin(a), "Z")
    c.outline()
    # sparks and smoke behind it
    for i, (x, y) in enumerate(((2, 9), (1, 7), (3, 11))):
        if (i + frame) % 3 != 2:
            c.set(x + frame % 2, y, "Y" if i == 0 else "q")
    c.set(0, 8 + frame % 2, "e")
    return c.img


CRACKS = [(0.3, 15, 0.05), (1.3, 12, -0.07), (2.2, 15, 0.04), (3.2, 14, -0.04),
          (4.1, 12, 0.06), (5.2, 15, -0.05)]


def lava_crack_pool(frame):
    """Cracks with lava radiating from the impact; 0-3 loop (lava pulses out along the
    cracks), 4-6 cool down (the lava darkens from the tips inwards)."""
    c = Canvas(32, 32)
    cx, cy = 16, 16
    cool = max(0, frame - 3)                 # 0 hot, 1-3 cooling
    paths = []
    for n, (ang, length, bend) in enumerate(CRACKS):
        pts = []
        for t in range(2, length):
            a = ang + bend * t * 0.6 + 0.1 * math.sin(t * 1.3 + n)
            pts.append((int(round(cx + math.cos(a) * t)), int(round(cy + math.sin(a) * t * 0.8)), t))
        # a short side branch
        bx, by, bt = pts[len(pts) // 2]
        side = ang + (0.9 if n % 2 else -0.9)
        branch = [(int(round(bx + math.cos(side) * s)), int(round(by + math.sin(side) * s * 0.8)), bt + s)
                  for s in range(1, 4)]
        paths.append((pts, branch, length))
    # dark scorched edges first (2-3 px wide near the centre)
    for pts, branch, _ in paths:
        for x, y, t in pts + branch:
            w = 1 if t < 5 else 0
            for dx in range(-1, 2 + w):
                for dy in range(-1, 2):
                    if abs(dx) + abs(dy) <= 1 + w and c.get(x + dx, y + dy) == ".":
                        c.set(x + dx, y + dy, "k" if abs(dx) + abs(dy) <= 1 else "g")
    for pts, branch, length in paths:
        for x, y, t in pts + branch:
            if cool == 0:
                hot = (t - frame * 2) % 8 < 3
                k = "Z" if hot and t < 9 else "Y" if hot or t < 5 else "q"
            else:
                k = ("q", "R", "r")[cool - 1] if t < length + 2 - 4 * cool else "k"
                if cool == 1 and t < 4:
                    k = "Y"
            c.set(x, y, k)
            if t < 4:
                c.set(x + 1, y, k if cool else ("Y" if k == "q" else k))
    # the hot core: a small crater
    core = ("Z", "W", "Z", "Y")[frame] if not cool else ("Y", "q", "R")[cool - 1]
    for dx, dy in ((0, 0), (-1, 0), (1, 0), (0, -1), (0, 1)):
        c.set(cx + dx, cy + dy, core if (dx, dy) == (0, 0) else ("Y" if not cool else core))
    # bubbles and embers rising from the lava, smoke when cooling
    if cool < 2:
        for x, y in ((8, 12 - frame % 2), (24, 19 - (frame + 1) % 2), (19, 7 - frame % 3), (11, 23)):
            c.set(x, y, "Z" if cool == 0 else "q")
    if cool:
        for x, y in ((12, 10 - cool), (21, 13 - cool), (15, 7 - cool)):
            c.set(x, y, "e")
    return c.img


def main():
    chest_boss().save("assets/art/pickups/chest_boss.png")
    fx = "assets/art/fx/"
    strip([water_orb(i) for i in range(4)]).save(fx + "water_orb.png")
    strip([water_orb_burst(i) for i in range(5)]).save(fx + "water_orb_burst.png")
    strip([tide_puddle(i) for i in range(4)]).save(fx + "tide_puddle.png")
    strip([geyser_warn(i) for i in range(4)]).save(fx + "geyser_warn.png")
    strip([geyser(i) for i in range(6)]).save(fx + "geyser.png")
    ring_frames("tide").save(fx + "tide_ring.png")
    strip([molten_boulder(i) for i in range(4)]).save(fx + "molten_boulder.png")
    strip([lava_crack_pool(i) for i in range(7)]).save(fx + "lava_crack_pool.png")
    ring_frames("molten").save(fx + "molten_ring.png")
    print("batch 15 parts 1-2 done")


if __name__ == "__main__":
    main()
