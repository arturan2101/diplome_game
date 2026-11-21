"""Batch 11 (stage 40, new element system): base elements, pairs and the third tier,
drawn in code like make_element_frames.py and make_fusion_frames.py (docs/art-style.md
palette, plus the nature theme's grass greens for the vines). Three looks per level
(l1..l3), each bigger and richer; 12 fps unless noted. Effects have no black outline
(like fire_l* and wind_l*); icons do.
Output, assets/art/fx/ (frames side by side):
  water_l<1-3>.png          wave rolling right, caster at the left edge, middle row (y 16):
                            4 frames of 48x32
  ice_burst_l3.png          the level 3 wave turning to ice over the same arc, 4 x 48x32
  frozen_mark.png           ice crust over a frozen enemy, 16x16, 1 frame (centre left clear)
  stone_spikes_l<1-3>.png   one spike breaks out of the floor and crumbles, 5 x 16x24
                            (0 cracks, 1 tip, 2 full, 3 cracking, 4 rubble; floor = row 22)
  wet_drops.png             drops falling from a wet enemy, 4 x 8x8, loop (8 fps)
  plasma_l<1-3>.png         violet-white orb with a short tail, flies right, 4 x 16x16 (l3 24x24)
  lava_pool_l<1-3>.png      round lava pool flat on the floor, 4 x 48x48, loop (8 fps)
  lightning.png             bolt from x 0 to x 63 on row 8: bright, branching, fading,
                            3 x 64x16 (stretch it between two points)
  lightning_hit.png         where the bolt lands, 3 x 16x16
  vines_l<1-3>.png          vines growing out of the floor in a ring, 5 x 48x48, hold the last
  sandstorm_l<1-3>.png      sand ring around the caster like wind_l*, 4 x 48x48, loop
  volcanic_lightning.png    red-orange bolt like lightning.png, 3 x 64x16
  storm_cloud.png           dark cloud with flashes and rain, 4 x 48x32, loop (8 fps)
  meteor.png                burning rock falling, 4 x 32x32 (rock centre (16, 20))
  meteor_shadow.png         its shadow growing on the floor, 4 x 32x32
  meteor_impact.png         impact blast, 5 x 64x64, centre (32, 36)
  element2_frames.tres      SpriteFrames with all of the above (loop as noted)
assets/art/ui/element_icons2.png: HUD icons 16x16 in a row (160x16): water, stone_spikes,
  plasma, lava, lightning, vines, sandstorm, volcanic_lightning, storm_cloud, meteor.
Run from the project root: python tools/art/make_elements2.py
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_element_frames as el  # noqa: E402

OUT = el.OUT
UI = "assets/art/ui"
C = dict(el.C)
C.update({
    "h": "#4a2a78", "H": "#9a5ae0",                    # purple
    "k": "#17161f", "e": "#4c4e5f", "T": "#767a8c",     # dark stone (T replaces teal light here)
    "d": "#0f0e14",
    "y": "#8a4a10", "c": "#b07040", "u": "#e0a070",     # sand
    "l": "#8ac060",                                     # nature grass highlight
    "a": "#2aa8a0", "A": "#9af0e0",                     # teal
})
el.C.update(C)   # el.put / el.disc look colours up in el.C


def rgb(k):
    h = C[k]
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def put(img, x, y, k):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((x, y), rgb(k))


def get(img, x, y):
    if 0 <= x < img.width and 0 <= y < img.height:
        return img.getpixel((x, y))
    return (0, 0, 0, 0)


def outline(img):
    out = img.copy()
    for y in range(img.height):
        for x in range(img.width):
            if img.getpixel((x, y))[3]:
                continue
            if any(get(img, x + dx, y + dy)[3] for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), rgb("o"))
    return out


def ellipse(img, cx, cy, rx, ry, k, ring=None):
    for y in range(img.height):
        for x in range(img.width):
            d = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
            if d <= 1 and (ring is None or d >= ring):
                put(img, x, y, k)


# --- water ---------------------------------------------------------------------

def wave_front(level, frame):
    """x of the crest for each row, and the half height of the wave."""
    h = (6, 9, 12)[level - 1]
    x0 = 6 + frame * (7 + level)
    bulge = 3 + level
    return {y: x0 + bulge * (1 - ((y - 16) / h) ** 2) for y in range(16 - h, 16 + h + 1)}, h


def water(level, frame):
    img = Image.new("RGBA", (48, 32))
    front, h = wave_front(level, frame)
    thick = 3 + level
    for y, xf in front.items():
        edge = abs(y - 16) / h
        t = max(2, int(thick * (1 - edge * 0.6)))
        # streaks of water behind the crest, back to the caster: short dashes
        if (y - 16) % 3 == 0:
            for x0 in range(1 + (frame * 2 + y) % 6, int(xf) - t - 1, 6):
                for k in range(2 + level // 2):
                    if x0 + k < xf - t:
                        put(img, x0 + k, y, "b" if x0 < xf / 2 else "B")
        for k in range(t):
            put(img, xf - k, y, ("W" if edge < 0.8 else "L") if k == 0 else ("L" if k == 1 else ("B" if k < t - 1 else "b")))
    # the curl: foam rolling over the top of the crest
    for i in range(level + 1):
        y = 16 - h + 1 + i * 2
        put(img, front[y] + 1, y, "W")
        put(img, front[y] + 1, 32 - y, "w")
    # spray ahead of the wave, more with the level
    rnd = random.Random(level * 10 + frame)
    for _ in range(level * 3):
        y = rnd.randint(16 - h, 16 + h)
        put(img, front[y] + rnd.randint(2, 4 + level), y, rnd.choice("LWW"))
    return img


def ice_burst(frame):
    img = Image.new("RGBA", (48, 32))
    front, h = wave_front(3, 2)
    reach = (0.35, 0.8, 1.0, 1.0)[frame]
    rnd = random.Random(7)
    for y, xf in front.items():
        if abs(y - 16) > h * reach:
            continue
        for k in range(4):
            put(img, xf - k, y, "W" if k == 0 else ("L" if k < 2 else "B"))
    # ice shards sticking out of the arc
    for i in range(9):
        y = 16 - h + 1 + i * (2 * h - 2) // 8
        if abs(y - 16) > h * reach:
            continue
        length = 2 + (i * 5) % 4 + (1 if frame >= 2 else 0)
        for k in range(length):
            put(img, front[y] + 1 + k, y - k // 2 * (1 if y < 16 else -1), "W" if k == length - 1 else "L")
    if frame == 3:
        # the shards break: sparkles fly off
        for _ in range(12):
            y = rnd.randint(16 - h, 16 + h)
            put(img, front[y] + rnd.randint(1, 8), y + rnd.randint(-1, 1), rnd.choice("WLw"))
        for y in range(0, 32, 3):
            if y in front:
                put(img, front[y] - 2, y, "b")
    return img


def frozen_mark():
    """Ice crust over the lower body and the edges; the middle stays open."""
    img = Image.new("RGBA", (16, 16))
    for x in range(1, 15):
        for y in range(10, 15):
            if y >= 10 + abs(x - 7.5) // 3:
                put(img, x, y, "L" if (x + y) % 3 else "B")
    for x in range(1, 15):
        put(img, x, 15, "o")
        put(img, x, 10 + int(abs(x - 7.5) // 3), "W")
    # icicles and frost on the sides
    for x, y0, n in ((1, 4, 6), (14, 3, 7), (3, 1, 3), (12, 1, 3)):
        for k in range(n):
            put(img, x, y0 + k, "W" if k == 0 else "L")
    for x, y in ((0, 6), (15, 5), (2, 9), (13, 9), (7, 1), (8, 0)):
        put(img, x, y, "W")
    return outline(img)


# --- stone spikes ----------------------------------------------------------------

def spike_shape(level):
    height = (11, 15, 19)[level - 1]
    half = (2.5, 3.5, 4.5)[level - 1]
    return height, half


def stone_spike(level, frame):
    img = Image.new("RGBA", (16, 24))
    floor = 22
    height, half = spike_shape(level)
    # cracks in the floor around the base
    if frame in (0, 1, 2, 3):
        for x, y in ((3, 22), (4, 21), (12, 22), (11, 23), (2, 23), (13, 21)):
            put(img, x, y, "k")
    if frame == 0:
        for x in range(5, 11):
            put(img, x, floor, "k" if x % 2 else "e")
        put(img, 7, floor - 1, "S")
        put(img, 9, floor - 1, "s")
        return img
    if frame == 4:
        # rubble
        for cx, cy, r in ((5, 21, 1.6), (9, 21.5, 2.0), (12, 22, 1.3), (7.5, 19.5, 1.2)):
            for y in range(24):
                for x in range(16):
                    if math.hypot(x + 0.5 - cx, y + 0.5 - cy) <= r:
                        put(img, x, y, "T" if x + 0.5 < cx and y + 0.5 < cy else "s")
        img = outline(img)
        for x in range(3, 14):
            if not img.getpixel((x, 23))[3]:
                put(img, x, 23, "d")
        return img
    shown = {1: 0.45, 2: 1.0, 3: 1.0}[frame]
    top = floor - int(height * shown)
    for y in range(top, floor + 1):
        t = (y - (floor - height)) / height     # 0 at the tip, 1 at the floor
        w = max(0.5, half * t)
        for x in range(16):
            dx = x + 0.5 - 8
            if abs(dx) <= w:
                k = "T" if dx < -w * 0.3 else ("s" if dx < w * 0.4 else "e")
                if level == 3 and abs(dx) < 0.6 and (y % 4 == 0):
                    k = "q"                       # glowing seam on level 3
                put(img, x, y, k)
    if frame == 3:
        for x, y in ((7, top + 3), (8, top + 4), (8, top + 5), (9, top + 7), (7, top + 8)):
            put(img, x, y, "k")
        for x, y in ((3, top + 2), (13, top + 5), (2, top + 9)):
            put(img, x, y, "s")
    img = outline(img)
    # dust thrown up when the tip breaks out
    if frame == 1:
        for x, y in ((2, 19), (13, 18), (4, 17), (12, 20), (1, 21), (14, 21)):
            put(img, x, y, "S")
    for x in range(4, 13):
        if not img.getpixel((x, 23))[3]:
            put(img, x, 23, "d")
    return img


def wet_drops(frame):
    img = Image.new("RGBA", (8, 8))
    for x, phase in ((1, 0), (4, 2), (6, 1)):
        y = (frame + phase) % 4 * 2
        put(img, x, y, "L")
        put(img, x, y + 1, "B")
    return img


# --- plasma --------------------------------------------------------------------

def plasma(level, frame):
    size = 24 if level == 3 else 16
    img = Image.new("RGBA", (size, size))
    r = (2.5, 3.5, 5.0)[level - 1]
    cx, cy = size / 2 + 2, size / 2
    # short tail: violet streaks behind the orb
    for i in range(2 + level):
        y = cy + (i - (1 + level) / 2) * 1.5
        length = 2 + level + (i + frame) % 2
        for k in range(int(length)):
            put(img, cx - r - k, y, "H" if k < length / 2 else "h")
    el.disc(img, cx, cy, r + 0.6, ["h", "H", "W", "W"])
    # crackling arcs around the orb
    for i in range(level + 1):
        a = frame * 1.3 + i * math.tau / (level + 1)
        x, y = cx + math.cos(a) * (r + 1.5), cy + math.sin(a) * (r + 1.5)
        put(img, x, y, "W" if i % 2 else "L")
        put(img, x + math.cos(a + 1.2), y + math.sin(a + 1.2), "H")
    return img


# --- lava ----------------------------------------------------------------------

def lava_pool(level, frame):
    img = Image.new("RGBA", (48, 48))
    rx = (11, 15, 19)[level - 1]
    ry = rx * 0.62
    c = 24
    ellipse(img, c, c, rx + 1, ry + 1, "k")
    ellipse(img, c, c, rx, ry, "r")
    ellipse(img, c, c, rx - 1.5, ry - 1.2, "R")
    ellipse(img, c - 1, c - 0.5, rx - 4, ry - 3, "q")
    ellipse(img, c - 2, c - 1, max(2, rx - 8), max(1.5, ry - 5.5), "Y")
    # cooled crust floating on the lava, drifting slowly
    rnd = random.Random(level)
    for i in range(2 + level * 2):
        a = rnd.random() * math.tau + frame * 0.15
        d = rnd.uniform(0.3, 0.85)
        x, y = c + math.cos(a) * rx * d, c + math.sin(a) * ry * d
        put(img, x, y, "r")
        put(img, x + 1, y, "k")
    # bubbles: grow and pop
    for i in range(level + 1):
        a = i * 2.1 + level
        x, y = c + math.cos(a) * rx * 0.5, c + math.sin(a) * ry * 0.5
        phase = (frame + i) % 4
        if phase == 1:
            put(img, x, y, "Z")
        elif phase == 2:
            for dx, dy in ((0, 0), (1, 0), (0, -1), (1, -1)):
                put(img, x + dx, y + dy, "Z")
            put(img, x, y - 1, "W")
        elif phase == 3:
            for dx, dy in ((-1, -1), (2, -1), (0, -2), (1, 1)):
                put(img, x + dx, y + dy, "Y")
    if level == 3:
        # embers rising from the pool
        for i in range(5):
            x = c - rx + 4 + i * (2 * rx - 8) / 4
            y = c - ry - 2 - (frame * 2 + i * 3) % 8
            put(img, x, y, "Z" if i % 2 else "q")
    return img


# --- lightning -----------------------------------------------------------------

def bolt_path(seed, x0=0, x1=63, y=8, amp=4):
    rnd = random.Random(seed)
    pts, x = [(x0, y)], x0
    while x < x1:
        x = min(x1, x + rnd.randint(4, 7))
        pts.append((x, y if x == x1 else y + rnd.randint(-amp, amp)))
    return pts


def draw_line(img, a, b, k, width=0, glow=None):
    (x0, y0), (x1, y1) = a, b
    n = max(abs(x1 - x0), abs(y1 - y0), 1)
    for i in range(n + 1):
        x = x0 + (x1 - x0) * i / n
        y = y0 + (y1 - y0) * i / n
        if glow:
            for dy in (-1 - width, 1 + width):
                if not get(img, x, y + dy)[3]:
                    put(img, x, y + dy, glow)
        for dy in range(-width, width + 1):
            put(img, x, y + dy, k)


def lightning(frame, core="W", glow="L", far="B"):
    img = Image.new("RGBA", (64, 16))
    pts = bolt_path(3 + frame % 2)
    if frame == 0:
        for a, b in zip(pts, pts[1:]):
            draw_line(img, a, b, glow, width=1)
        for a, b in zip(pts, pts[1:]):
            draw_line(img, a, b, core)
    elif frame == 1:
        for a, b in zip(pts, pts[1:]):
            draw_line(img, a, b, core, glow=glow)
        for start, seed, dirn in ((2, 11, 1), (5, 12, -1), (7, 13, 1)):
            if start < len(pts):
                x, y = pts[start]
                for s in range(3):
                    nx, ny = x + 3, y + dirn * 2
                    draw_line(img, (x, y), (nx, ny), glow if s else core)
                    x, y = nx, ny
    else:
        for a, b in zip(pts, pts[1:]):
            draw_line(img, a, b, far)
        for i, (x, y) in enumerate(pts[1:-1]):
            if i % 2 == 0:
                put(img, x, y, glow)
    return img


def lightning_hit(frame, core="W", glow="L", far="B"):
    img = Image.new("RGBA", (16, 16))
    if frame == 0:
        ellipse(img, 8, 8, 3.5, 3.5, glow)
        ellipse(img, 8, 8, 2, 2, core)
        for a in range(8):
            ang = a * math.pi / 4
            for r in range(4, 7 if a % 2 else 8):
                put(img, 8 + math.cos(ang) * r, 8 + math.sin(ang) * r, core if r < 5 else glow)
    elif frame == 1:
        ellipse(img, 8, 8, 5.5, 5.5, glow, ring=0.6)
        ellipse(img, 8, 8, 1.5, 1.5, core)
        for a in range(6):
            ang = a * math.tau / 6 + 0.3
            put(img, 8 + math.cos(ang) * 7, 8 + math.sin(ang) * 7, core)
    else:
        ellipse(img, 8, 8, 6.5, 6.5, far, ring=0.75)
        for a in range(5):
            ang = a * math.tau / 5 + 0.8
            put(img, 8 + math.cos(ang) * 5, 8 + math.sin(ang) * 5, glow)
    return img


# --- vines ---------------------------------------------------------------------

def vines(level, frame):
    img = Image.new("RGBA", (48, 48))
    c = 24
    count = 5 + level * 2
    radius = 12 + level * 3
    grow = (0.0, 0.35, 0.65, 0.9, 1.0)[frame]
    max_h = 8 + level * 2
    stems = []
    for i in range(count):
        a = i * math.tau / count + 0.3
        bx, by = c + math.cos(a) * radius, c + math.sin(a) * radius * 0.6
        stems.append((by, bx, i))
    roots = []
    for by, bx, i in sorted(stems):          # back to front
        roots.append((bx, by))
        if grow == 0:
            continue
        h = int(max_h * grow * (0.8 + (i % 3) * 0.1))
        side = 1 if i % 2 else -1
        pts = []
        for k in range(h):
            sway = math.sin(k * 0.6 + i) * (1 + k / max_h * 2) * side
            pts.append((bx + sway, by - k))
        for k, (x, y) in enumerate(pts):
            put(img, x, y, "l" if k == h - 1 else "G")   # lit side
            put(img, x + 1, y, "g")                      # shaded side
        # leaves (and thorns / flowers on the higher levels) once grown
        for k in range(2, h - 1, 3):
            x, y = pts[k]
            lx = x + (3 if side > 0 else -2)
            put(img, lx, y, "l" if frame >= 3 else "G")
            put(img, lx + side, y, "G")
            put(img, lx, y + 1, "g")
            if level == 3 and frame >= 3:
                put(img, x - (2 if side > 0 else -3), y - 1, "w")
        if frame == 4 and pts:
            x, y = pts[-1]
            put(img, x + side, y - 1, "l")               # the curl at the top
            if level >= 2 and i % 3 == 0:
                put(img, x, y - 2, "q" if level == 3 else "Z")
    img = outline(img)
    # broken soil at the roots
    for bx, by in roots:
        put(img, bx - 1, by + 1, "k")
        put(img, bx + 2, by + 1, "y")
        if grow == 0:
            put(img, bx, by, "k")
            put(img, bx + 1, by, "y")
    return img


# --- sandstorm -----------------------------------------------------------------

def sandstorm(level, frame):
    img = Image.new("RGBA", (48, 48))
    c = 24
    for ring in range(level + 1):
        radius = 10 + ring * 4 + level
        arcs = 3 + level
        for a in range(arcs):
            start = (a / arcs) * math.tau + frame * 0.4 + ring * 0.7
            for k in range(10 + level * 2):
                ang = start + k * 0.06
                x = c + math.cos(ang) * radius
                y = c + math.sin(ang) * radius * 0.6
                put(img, x, y, "u" if k > 6 + level else ("c" if k > 2 else "y"))
    # dust specks swirling inside and outside the ring
    rnd = random.Random(level)
    for i in range(6 + level * 4):
        ang = rnd.random() * math.tau + frame * 0.35
        r = rnd.uniform(6, 14 + level * 4)
        put(img, c + math.cos(ang) * r, c + math.sin(ang) * r * 0.6, rnd.choice("ucy"))
    if level == 3:
        for i in range(5):
            ang = frame * 0.5 + i * math.tau / 5
            x = c + math.cos(ang) * (16 + i % 2 * 3)
            y = c + math.sin(ang) * (16 + i % 2 * 3) * 0.6
            put(img, x, y, "s")
            put(img, x + 1, y, "e")
            put(img, x, y - 1, "S")
    return img


# --- storm cloud ---------------------------------------------------------------

CLOUD = [(14, 12, 7), (24, 9, 8), (33, 12, 7), (20, 15, 7), (29, 16, 6), (10, 16, 4.5), (38, 16, 4.5)]


def storm_cloud(frame):
    img = Image.new("RGBA", (48, 32))
    drift = (0, 1, 1, 0)[frame]
    for cx, cy, r in CLOUD:
        ellipse(img, cx + drift, cy, r + 1, r * 0.75 + 1, "k")
    for cx, cy, r in CLOUD:
        ellipse(img, cx + drift, cy, r, r * 0.75, "e")
    for cx, cy, r in CLOUD:
        ellipse(img, cx + drift - 1, cy - 1.5, r * 0.6, r * 0.4, "s")
    for cx, cy, r in CLOUD[:3]:
        ellipse(img, cx + drift - 2, cy - 3, r * 0.3, r * 0.2, "S")
    # flash inside the cloud and a short bolt under it on frames 1 and 3
    if frame in (1, 3):
        fx = 22 if frame == 1 else 30
        ellipse(img, fx, 13, 4, 2.5, "L")
        ellipse(img, fx, 13, 2, 1.2, "W")
        x, y = fx, 20
        for s in range(4):
            nx, ny = x + (1 if s % 2 else -1) * 2, y + 2
            draw_line(img, (x, y), (nx, ny), "W", glow="L")
            x, y = nx, ny
    # rain
    for i in range(9):
        x = 10 + i * 3.5 + drift
        y = 21 + (frame * 3 + i * 2) % 9
        put(img, x, y, "B")
        put(img, x, y + 1, "b")
    return img


# --- meteor --------------------------------------------------------------------

def meteor(frame):
    img = Image.new("RGBA", (32, 32))
    cx, cy, r = 16, 21, 5.5
    # the rock, outlined
    for y in range(32):
        for x in range(32):
            d = math.hypot(x + 0.5 - cx, (y + 0.5 - cy) * 1.1)
            if d <= r:
                s = (x + 0.5 - cx) + (y + 0.5 - cy)
                put(img, x, y, "T" if s < -3 else ("s" if s < 2 else "e"))
    for x, y in ((14, 20), (17, 23), (19, 19)):
        put(img, x, y, "q")                       # glowing cracks
    img = outline(img)
    # a teardrop of flame above it (it falls down onto the floor in the 3/4 view),
    # brightest against the rock, flickering at the tip; drawn only on empty pixels
    top = int(cy - r - 11 - (frame % 2))
    for y in range(top, int(cy - 1)):
        t = (y - top) / (cy - 1 - top)           # 0 at the tip, 1 at the rock
        half = 1 + t * (r + 0.5)
        wob = math.sin(y * 0.9 + frame * 1.7) * (1 - t)
        for x in range(32):
            dx = x + 0.5 - cx - wob
            if abs(dx) <= half and not img.getpixel((x, y))[3]:
                e = abs(dx) / half
                k = "W" if t > 0.75 and e < 0.35 else ("Z" if t > 0.5 and e < 0.6 else ("Y" if t > 0.3 and e < 0.8 else ("q" if t > 0.12 else "R")))
                put(img, x, y, k)
    for i in range(3):
        put(img, cx - 7 + (i * 6 + frame * 3) % 14, top + 2 + (frame + i * 2) % 5, "Z" if i % 2 else "q")
    return img


def meteor_shadow(frame):
    img = Image.new("RGBA", (32, 32))
    rx = (4, 7, 10, 13)[frame]
    ellipse(img, 16, 16, rx, rx * 0.5, "d")
    if frame >= 2:
        ellipse(img, 16, 16, rx + 1, rx * 0.5 + 1, "R", ring=0.82)
    if frame == 3:
        for x in range(32):
            for y in range(32):
                p = img.getpixel((x, y))
                if p[:3] == rgb("R")[:3] and (x + y) % 2:
                    put(img, x, y, "q")
    return img


def meteor_impact(frame):
    img = Image.new("RGBA", (64, 64))
    c, cy = 32, 36
    if frame == 0:
        ellipse(img, c, cy, 10, 7, "Y")
        ellipse(img, c, cy, 6, 4, "Z")
        ellipse(img, c, cy, 3, 2, "W")
    elif frame in (1, 2):
        r = (16, 22)[frame - 1]
        ellipse(img, c, cy, r, r * 0.6, "R", ring=0.55)
        ellipse(img, c, cy, r - 2, r * 0.6 - 1.5, "q", ring=0.6)
        ellipse(img, c, cy - 2, r * 0.55, r * 0.4, "Y")
        ellipse(img, c, cy - 3, r * 0.3, r * 0.22, "Z")
        # fire column rising from the centre
        for i in range(5):
            x = c - 4 + i * 2
            for k in range(8 + frame * 4 - abs(i - 2) * 2):
                put(img, x, cy - 4 - k, "Y" if k < 4 else ("q" if k < 9 else "R"))
    else:
        # smoke and debris, fading
        r = (25, 28)[frame - 3]
        rnd = random.Random(frame)
        ellipse(img, c, cy, r, r * 0.6, "e", ring=0.8 if frame == 3 else 0.9)
        for i in range(30 if frame == 3 else 16):
            ang = rnd.random() * math.tau
            d = rnd.uniform(4, r)
            put(img, c + math.cos(ang) * d, cy + math.sin(ang) * d * 0.6 - (frame - 2) * 2, rnd.choice("seR" if frame == 3 else "se"))
        if frame == 3:
            ellipse(img, c, cy, 8, 5, "r")
            ellipse(img, c, cy, 5, 3, "q")
    # rocks thrown out
    if frame >= 1:
        for i in range(8):
            ang = i * math.tau / 8 + 0.2
            d = 8 + frame * 5
            x, y = c + math.cos(ang) * d, cy + math.sin(ang) * d * 0.6 - (6 if frame < 3 else 2)
            put(img, x, y, "s")
            put(img, x + 1, y, "e")
            put(img, x, y - 1, "T")
    # the crater left on the floor
    if frame >= 3:
        ellipse(img, c, cy + 1, 7, 3.5, "k")
        ellipse(img, c, cy + 1, 5, 2.2, "r" if frame == 3 else "d")
    return img


# --- icons ---------------------------------------------------------------------

def icon_from(img, box, scale=1):
    part = img.crop(box)
    if scale != 1:
        part = part.resize((int(part.width * scale), int(part.height * scale)), Image.NEAREST)
    icon = Image.new("RGBA", (16, 16))
    icon.alpha_composite(part, ((16 - part.width) // 2, (16 - part.height) // 2))
    return icon


def icon_bolt(core, glow):
    icon = Image.new("RGBA", (16, 16))
    pts = [(10, 1), (6, 7), (9, 7), (5, 14), (11, 6), (8, 6), (11, 1)]
    for a, b in zip(pts, pts[1:]):
        draw_line(icon, a, b, glow)
    for x, y in ((9, 2), (8, 4), (7, 6), (8, 8), (7, 10), (6, 12)):
        put(icon, x, y, core)
    return icon


def icon_map(rows):
    icon = Image.new("RGBA", (16, 16))
    for y, row in enumerate(rows):
        for x, k in enumerate(row.ljust(16, ".")[:16]):
            if k != ".":
                put(icon, x, y, k)
    return icon


ICON_SAND = [
    "................",
    "..uuuuuuuuuuuc..",
    "..cccccccccccy..",
    "...uuuuuuuuuc...",
    "....ccccccccy...",
    ".....uuuuuuc....",
    ".....cccccy.....",
    "......uuuuc.....",
    "......cccy......",
    ".......uuc......",
    ".......ccy......",
    "........uc......",
    "........cy......",
    "..u.............",
    ".c...yy.u....c..",
    "...........y....",
]
ICON_VINES = [
    "................",
    "......l.........",
    ".....Gl.........",
    ".....Gg..lG.....",
    "......Gg.lGg....",
    "..lG...Gg.......",
    "..lGg..Gg.......",
    ".......Gg.......",
    "......Gg..lG....",
    "......Gg..lGg...",
    "......Gg.Gg.....",
    ".......GgG......",
    ".......Gg.......",
    "......yGgy......",
    ".....yyyyyy.....",
    "................",
]
ICON_METEOR = [
    "................",
    "............RR..",
    "...........RqqR.",
    "..........RqYqR.",
    ".........RqYZq..",
    "........RqYZY...",
    ".......qYZWZ....",
    "....eeeZWZ......",
    "...eTTTsZ.......",
    "..eTTssse.......",
    "..eTsseqe.......",
    "..esseqse.......",
    "..eessse........",
    "...eeee.........",
    "................",
    "................",
]


def icon_water():
    icon = Image.new("RGBA", (16, 16))
    for x in range(1, 15):
        y = 11 + math.sin(x * 0.8) * 1.2
        for k in range(int(y), 15):
            put(icon, x, k, "B" if k > y + 1 else "L")
    for x, y in ((4, 9), (5, 7), (7, 6), (9, 6), (10, 7), (11, 9), (8, 5), (6, 6)):
        put(icon, x, y, "W" if y < 7 else "L")
    put(icon, 3, 10, "W")
    return icon


def icon_cloud():
    icon = storm_cloud(1).crop((4, 2, 44, 30)).resize((16, 11), Image.NEAREST)
    out = Image.new("RGBA", (16, 16))
    out.alpha_composite(icon, (0, 0))
    for x, y in ((8, 11), (7, 12), (8, 13), (7, 14)):
        put(out, x, y, "Z")
    return out


def icons():
    row = [
        icon_water(),
        icon_from(stone_spike(2, 2), (2, 5, 14, 23), 0.85),
        icon_from(plasma(2, 0), (0, 0, 16, 16)),
        icon_from(lava_pool(1, 2), (11, 15, 37, 33), 0.6),
        icon_bolt("W", "L"),
        icon_map(ICON_VINES),
        icon_map(ICON_SAND),
        icon_bolt("Z", "q"),
        icon_cloud(),
        icon_map(ICON_METEOR),
    ]
    strip = Image.new("RGBA", (16 * len(row), 16))
    for i, icon in enumerate(row):
        clean = Image.new("RGBA", (16, 16))
        # keep a 1 px margin for the outline
        clean.alpha_composite(icon.crop((1, 1, 15, 15)), (1, 1))
        strip.paste(outline(clean), (i * 16, 0))
    return strip


# --- output --------------------------------------------------------------------

def frames_tres(entries, path):
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(entries) + sum(e[3] for e in entries)} format=3]', ""]
    for name, file, _, _, _, _ in entries:
        lines.append(f'[ext_resource type="Texture2D" path="res://{OUT}/{file}" id="{name}"]')
    lines.append("")
    for name, _, (w, h), count, _, _ in entries:
        for i in range(count):
            lines += [f'[sub_resource type="AtlasTexture" id="{name}_{i}"]', f'atlas = ExtResource("{name}")',
                      f"region = Rect2({i * w}, 0, {w}, {h})", ""]
    blocks = []
    for name, _, _, count, speed, loop in entries:
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (name, i) for i in range(count))
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                      % (fr, "true" if loop else "false", name, speed))
    lines += ["[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines))


def main():
    entries = []

    def save(name, frames, speed=12.0, loop=True):
        w, h, n = el.save_strip(frames, f"{OUT}/{name}.png")
        entries.append((name, f"{name}.png", (w, h), n, speed, loop))

    for lv in (1, 2, 3):
        save(f"water_l{lv}", [water(lv, f) for f in range(4)], loop=False)
        save(f"stone_spikes_l{lv}", [stone_spike(lv, f) for f in range(5)], loop=False)
        save(f"plasma_l{lv}", [plasma(lv, f) for f in range(4)])
        save(f"lava_pool_l{lv}", [lava_pool(lv, f) for f in range(4)], speed=8.0)
        save(f"vines_l{lv}", [vines(lv, f) for f in range(5)], loop=False)
        save(f"sandstorm_l{lv}", [sandstorm(lv, f) for f in range(4)])
    save("ice_burst_l3", [ice_burst(f) for f in range(4)], loop=False)
    frozen_mark().save(f"{OUT}/frozen_mark.png")
    save("wet_drops", [wet_drops(f) for f in range(4)], speed=8.0)
    save("lightning", [lightning(f) for f in range(3)], loop=False)
    save("lightning_hit", [lightning_hit(f) for f in range(3)], loop=False)
    save("volcanic_lightning", [lightning(f, "Z", "q", "R") for f in range(3)], loop=False)
    save("storm_cloud", [storm_cloud(f) for f in range(4)], speed=8.0)
    save("meteor", [meteor(f) for f in range(4)])
    save("meteor_shadow", [meteor_shadow(f) for f in range(4)], loop=False)
    save("meteor_impact", [meteor_impact(f) for f in range(5)], loop=False)
    icons().save(f"{UI}/element_icons2.png")
    frames_tres(entries, f"{OUT}/element2_frames.tres")
    print("batch 11 element art written")


if __name__ == "__main__":
    main()
