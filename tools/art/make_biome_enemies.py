"""Batch 15, parts 3 and 4: the small enemies of the fungal and the sand styles and their
effects (docs/art-style.md palette plus the theme colours of make_batch15.PAL).

Strips <enemy>_<anim>_<dir>.png (dir = down, up, left, right) and one <enemy>_death.png,
SpriteFrames <enemy>_frames.tres (animations <anim>_<dir> and death; idle 6 fps, walk 10,
attack / emerge / sink / burrow 12, hurt 12, death 10, loop on idle, walk, hidden).

Fungal:
  sporeling   24x24, squat mushroom man. idle 4, walk 6, attack 6 (cap headbutt: wind-up
              0-1, strike 2), hurt 2, death 5 (bursts into a spore cloud). Feet row 22,
              shadow row 23.
  vine_lurker 24x24, a bud mouth on a stem, stands still. hidden 1, emerge 4, idle 4,
              attack 6 (rears back 0-1, lash 2), hurt 2, death 5. Stem foot row 22,
              shadow row 23.
  spore_bat   16x16, flies (body 3 px over its shadow). idle 4 (= flight), attack 4
              (rise 0-1, dive and strike 2, back 3), hurt 2, death 4. Shadow row 14.
  fx/vine_lash.png  48x8 x 4: the vine shoots right from x 0 (row 4) and pulls back.
  fx/root_spike.png 16x24 x 6, root bursting from the floor, bottom row 23.
  fx/root_warn.png  16x16 x 4, loop: a crack opening in the floor, centre (8, 9).
  fx/spore_ring.png 64x64 x 6, once, centre (32, 32), ring radius 6 ... 30 (Mother, phase 2).
Sand:
  mummy       24x24, recoloured from the drowned (same frames and timing): idle 4, walk 6,
              attack 6 (arms back 0-1, strike 2: the bandages lash forward), hurt 2,
              death 5 (crumbles into sand and bandages). Feet row 22, shadow row 23.
  fx/grip_bandage.png 16x8 x 4, loop (grip_seaweed in bandages).
  scarab      16x16, recoloured from the beetle (gold shell, turquoise stripe): idle 4,
              walk 4, attack 4 (strike 2), hurt 2, death 4; burrow 4 and emerge 4 are one
              strip each (scarab_burrow.png, scarab_emerge.png). Shell bottom row 13.
  sand_serpent 32x32: hidden 4 (loop: a sand bump creeping), emerge 6 (strike 3), sink 4,
              hurt 2, death 5. Sand line row 28, shadow row 29.
  fx/sand_ripple.png 16x16 x 4, loop, centre (8, 8).
  fx/sun_beam.png 16x8 x 4, loop, repeats along the beam (seamless left-right).
  fx/sun_beam_warn.png 16x8 x 2, loop, a thin blinking line.
  fx/sand_ring.png 64x64 x 6, once, centre (32, 32), ring radius 6 ... 30.
  fx/sun_beam_hit.png 16x16 x 4, loop, centre (8, 8): the beam's flash on a wall.
Run from the project root: python tools/art/make_biome_enemies.py
(only the two late effects: python tools/art/make_biome_enemies.py extra)
"""
import glob
import math
import os
import random
import re
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_batch15 as b15  # noqa: E402
from make_batch15 import RGB, Canvas, strip  # noqa: E402

E = "assets/art/enemies"
FX = "assets/art/fx"
DIRS = {"down": (0, 1), "up": (0, -1), "left": (-1, 0), "right": (1, 0)}
FPS = {"idle": 6.0, "walk": 10.0, "hidden": 6.0}


def write_frames(actor, size):
    entries = []
    for path in sorted(glob.glob(os.path.join(E, f"{actor}_*.png"))):
        anim = os.path.basename(path)[len(actor) + 1:-4]
        if not re.match(r"^(idle|walk|attack|hurt|death|hidden|emerge|sink|burrow)(_[a-z]+)?$", anim):
            continue
        entries.append((anim, os.path.basename(path), Image.open(path).width // size))
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(entries) + sum(c for _, _, c in entries)} format=3]', ""]
    for anim, name, _ in entries:
        lines.append(f'[ext_resource type="Texture2D" path="res://{E}/{name}" id="{anim}"]')
    lines.append("")
    for anim, _, count in entries:
        for i in range(count):
            lines += [f'[sub_resource type="AtlasTexture" id="{anim}_{i}"]', f'atlas = ExtResource("{anim}")',
                      f"region = Rect2({i * size}, 0, {size}, {size})", ""]
    blocks = []
    for anim, _, count in entries:
        kind = anim.split("_")[0]
        frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (anim, i) for i in range(count))
        loop = "true" if kind in ("idle", "walk", "hidden") else "false"
        speed = FPS.get(kind, 10.0 if kind == "death" else 12.0)
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (frames, loop, anim, speed))
    lines += ["[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    with open(os.path.join(E, f"{actor}_frames.tres"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


def save(actor, name, frames):
    strip([f.img if isinstance(f, Canvas) else f for f in frames]).save(os.path.join(E, f"{actor}_{name}.png"))


def flash(c):
    """Hurt flash: every body colour to white, outline kept."""
    out = Canvas(c.w, c.h)
    for y in range(c.h):
        for x in range(c.w):
            k = c.get(x, y)
            if k != ".":
                out.set(x, y, k if k in ("o", "d") else "W")
    return out


def shadow(c, cx, row, half):
    for x in range(int(cx - half), int(cx + half) + 1):
        if c.get(x, row) == ".":
            c.set(x, row, "d")


def ellipse(c, cx, cy, rx, ry, keys, light=True):
    """Filled ellipse, lit from the top-left: keys = (light, mid, dark)."""
    for y in range(int(cy - ry - 1), int(cy + ry + 2)):
        for x in range(int(cx - rx - 1), int(cx + rx + 2)):
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            if dx * dx + dy * dy <= 1:
                lit = -dx - dy if light else 0
                c.set(x, y, keys[0] if lit > 0.8 else keys[1] if lit > -0.6 else keys[2])


# =====================================================================================
# Sporeling
# =====================================================================================

def sporeling(d, shift=(0, 0), bob=0, legs=0, lean=0, swell=0.0, squash=0.0):
    """One frame. lean: cap pushed along the facing (px), negative = leaning back."""
    fx, fy = DIRS[d]
    c = Canvas(24, 24)
    ox, oy = shift
    cx = 12 + ox
    # legs
    for side, up in ((-1, legs == 1), (1, legs == 2)):
        x = cx + side * 2 - (1 if side < 0 else 0)
        for y in range(19 + oy, 22 - (1 if up else 0)):
            c.set(x, y, "m" if side > 0 else "w")
            c.set(x + 1, y, "m")
    # stalk body
    top = 13 + oy + bob
    for y in range(top, 20 + oy):
        for x in range(cx - 3, cx + 3):
            c.set(x, y, "w" if x < cx - 1 else "m" if x < cx + 2 else "T")
    # arms (nubs)
    for side in (-1, 1):
        ax = cx - 4 if side < 0 else cx + 3
        c.set(ax, top + 3, "w" if side < 0 else "m")
        c.set(ax, top + 4, "m")
    # face on the stalk
    if d == "down":
        c.set(cx - 2, top + 2, "o")
        c.set(cx + 1, top + 2, "o")
        c.set(cx - 1, top + 4, "e")
        c.set(cx, top + 4, "e")
    elif d in ("left", "right"):
        c.set(cx + fx * 2 - (1 if fx < 0 else 0), top + 2, "o")
        c.set(cx + fx * 2 - (1 if fx < 0 else 0), top + 4, "e")
    # cap (a dome, tilted by lean)
    lx, ly = fx * lean, fy * lean * 0.7
    rx = 7.5 + swell - squash * 0.5
    ry = 4.6 + swell * 0.6 - squash
    ccx, ccy = cx + lx, 9.5 + oy + bob + ly + squash
    for y in range(24):
        for x in range(24):
            dx, dy = (x + 0.5 - ccx) / rx, (y + 0.5 - ccy) / ry
            if dx * dx + dy * dy <= 1 and y + 0.5 <= ccy + ry * 0.55:
                lit = -dx - dy * 1.2
                c.set(x, y, "p" if lit > 0.75 else "H" if lit > -0.55 else "h")
    # the cap's rim and gills
    rim = int(round(ccy + ry * 0.55))
    for x in range(int(ccx - rx + 1), int(ccx + rx)):
        if c.get(x, rim - 1) in ("H", "h", "p"):
            c.set(x, rim, "h")
    # glowing spots
    spots = [(-4, -1), (2, -2), (-1, 0), (4, 0)] if d != "up" else [(-3, -1), (1, -2), (3, 0), (-1, 1)]
    for sx, sy in spots:
        if c.get(ccx + sx, ccy + sy) in ("H", "p", "h"):
            c.set(ccx + sx, ccy + sy, "x")
    c.outline()
    shadow(c, cx, 23, 5)
    return c


def sporeling_death():
    frames = [flash(sporeling("down")), sporeling("down", swell=1.5), sporeling("down", swell=2.2, squash=1.0)]
    rnd = random.Random(4)
    blobs = [(rnd.uniform(5, 19), rnd.uniform(6, 18), rnd.uniform(2, 3.5)) for _ in range(8)]
    for j in range(2):
        c = Canvas(24, 24)
        # the stub of the stalk left on the floor
        for y in range(19, 22):
            for x in range(10, 14):
                c.set(x, y, "m" if x > 10 else "w")
        c.outline()
        for bx, by, br in blobs:
            r = br * (1.2 if j == 0 else 0.8)
            ellipse(c, bx, by - j * 2, r, r * 0.8, ("v", "V", "G"))
        shadow(c, 12, 23, 4)
        frames.append(c)
    return frames


def make_sporeling():
    for d, (fx, fy) in DIRS.items():
        save("sporeling", f"idle_{d}", [sporeling(d, bob=b) for b in (0, 0, 1, 1)])
        save("sporeling", f"walk_{d}", [sporeling(d, legs=l, bob=b, shift=(s, 0))
                                        for l, b, s in ((1, 0, 0), (1, 1, 0), (0, 0, 0), (2, 0, 0), (2, 1, 0), (0, 0, 0))])
        save("sporeling", f"attack_{d}", [
            sporeling(d, lean=-2, shift=(-fx, -fy)),
            sporeling(d, lean=-3, shift=(-fx, -fy), bob=1),
            sporeling(d, lean=4, shift=(fx * 2, fy * 2)),
            sporeling(d, lean=3, shift=(fx * 2, fy * 2)),
            sporeling(d, lean=1, shift=(fx, fy)),
            sporeling(d)])
        save("sporeling", f"hurt_{d}", [flash(sporeling(d, shift=(-fx, -fy))), sporeling(d, shift=(-fx, -fy), lean=-1)])
    save("sporeling", "death", sporeling_death())
    write_frames("sporeling", 24)


# =====================================================================================
# Vine lurker
# =====================================================================================

def vine(d, height=1.0, sway=0, reach=0, mouth=0, wilt=0.0, brown=False):
    """height 0..1 of the stem; reach: head pushed along the facing (px, negative = back);
    mouth 0 closed .. 2 wide open; wilt 0..1: the head droops to the floor."""
    fx, fy = DIRS[d]
    c = Canvas(24, 24)
    base_x, base_y = 12, 22
    stem_h = 13 * height
    hx_ = base_x + sway + fx * reach + (fx * 2 if d in ("left", "right") else 0) * height
    hy_ = base_y - stem_h - 3 + fy * reach * 0.6 + wilt * (stem_h - 2)
    if wilt:
        hx_ += 6 * wilt * (1 if fx >= 0 else -1)
    green = ("V", "G", "N") if not brown else ("c", "B", "b")
    # stem: a curve from the base to the head
    n = 16
    for i in range(n + 1):
        t = i / n
        x = base_x + (hx_ - base_x) * (t ** 1.6) + math.sin(t * math.pi) * (-1.5 if fx >= 0 else 1.5) * height
        y = base_y - (base_y - hy_) * t
        c.set(x, y, green[1])
        c.set(x + 1, y, green[2])
    # leaves at the base
    for x, y, k in ((9, 21, green[0]), (8, 20, green[0]), (10, 21, green[1]), (15, 21, green[1]),
                    (16, 20, green[0]), (14, 21, green[2])):
        c.set(x, y, k)
    if height > 0.25:
        # the bud head
        petals = ("q", "R", "r") if not brown else ("B", "b", "b")
        ellipse(c, hx_ + 0.5, hy_, 4.2, 3.6, petals)
        # sepals
        for dx in (-3, 3):
            c.set(hx_ + dx + 0.5, hy_ + 2, green[1])
        if mouth and d != "up":
            # open jaws: a dark mouth with pale teeth, facing the viewer or the side
            mx = hx_ + 0.5 + (fx * 2 if d in ("left", "right") else 0)
            my = hy_ + (1 if d == "down" else 0)
            w = 1 + mouth
            for y in range(int(my - w // 2 - 1), int(my + w // 2 + 1)):
                for x in range(int(mx - w), int(mx + w)):
                    c.set(x, y, "o" if y > my - w // 2 else "r")
            for x in range(int(mx - w), int(mx + w), 2):
                c.set(x, my - w // 2 - 1, "w")
                c.set(x + 1, my + w // 2, "w")
        elif d != "up":
            c.set(hx_, hy_ + (1 if d == "down" else 0), "r")   # closed seam
            c.set(hx_ + 1, hy_ + (1 if d == "down" else 0), "r")
        # glowing spots on the petals
        c.set(hx_ - 2, hy_ - 2, "x" if not brown else "B")
        c.set(hx_ + 2, hy_ - 1, "v" if not brown else "b")
    else:
        # only a tip poking out of the earth
        for x, y, k in ((11, 20, "q"), (12, 20, "R"), (12, 19, "q"), (13, 20, "R")):
            c.set(x, y, k)
    c.outline()
    # earth around the root
    for x in range(8, 17):
        if c.get(x, 22) == ".":
            c.set(x, 22, "3" if x % 2 else "2")
    shadow(c, 12, 23, 5)
    return c


def make_vine_lurker():
    for d, (fx, fy) in DIRS.items():
        save("vine_lurker", f"hidden_{d}", [vine(d, height=0.1)])
        save("vine_lurker", f"emerge_{d}", [vine(d, height=h, mouth=m) for h, m in ((0.3, 0), (0.6, 0), (1.1, 2), (1.0, 1))])
        save("vine_lurker", f"idle_{d}", [vine(d, sway=s, mouth=m) for s, m in ((0, 0), (1, 1), (0, 0), (-1, 1))])
        save("vine_lurker", f"attack_{d}", [vine(d, reach=-2, mouth=1), vine(d, reach=-3, mouth=2),
                                            vine(d, reach=4, mouth=2), vine(d, reach=3, mouth=1),
                                            vine(d, reach=1), vine(d)])
        save("vine_lurker", f"hurt_{d}", [flash(vine(d, reach=-1)), vine(d, reach=-2)])
    save("vine_lurker", "death", [flash(vine("down")), vine("down", wilt=0.25, brown=True),
                                  vine("down", wilt=0.55, brown=True), vine("down", wilt=0.85, brown=True, height=0.8),
                                  vine("down", height=0.2, brown=True)])
    write_frames("vine_lurker", 24)


def vine_lash():
    frames = []
    for i, length in enumerate((18, 44, 46, 26)):
        c = Canvas(48, 8)
        for x in range(length):
            y = 4 + int(round(math.sin(x * 0.35 + i) * (1.2 if i in (0, 3) else 0.6)))
            c.set(x, y, "G")
            c.set(x, y + 1, "N")
            if x % 6 == 3:
                c.set(x, y - 1, "V")   # thorns
        # the bud at the tip, jaws open on the strike
        tx = length - 1
        for dx in range(-2, 2):
            for dy in range(-2, 3):
                if abs(dx) + abs(dy) <= 3:
                    c.set(tx + dx, 4 + dy, "q" if dy < 0 else "R")
        if i in (1, 2):
            c.set(tx + 1, 4, "o")
            c.set(tx + 1, 3, "w")
            c.set(tx + 1, 5, "w")
        c.outline()
        frames.append(c.img)
    return strip(frames)


def root_spike(frame):
    c = Canvas(16, 24)
    h = (0, 6, 19, 18, 10, 3)[frame]
    for y in range(23 - h, 23):
        t = (y - (23 - h)) / max(h, 1)
        half = 0.6 + t * 2.4
        for x in range(int(8 - half), int(8 + half) + 1):
            c.set(x, y, "B" if x < 8 else "b")
        if y % 4 == 1 and half > 1:
            c.set(8 - half - 0.5, y, "B")      # a side thorn
    if h:
        c.set(8, 23 - h, "c")
        c.outline()
    # dirt around the hole and flying earth
    for x in range(3, 13):
        c.set(x, 23, "3" if x % 3 else "1")
    for k, (x, y) in enumerate(((3, 18), (12, 16), (5, 13), (11, 20))):
        if frame in (1, 2) or (frame == 3 and k < 2):
            c.set(x + (frame - 1) * (1 if k % 2 else -1), y - (frame - 1) * 2, "3")
    return c.img


def root_warn(frame):
    c = Canvas(16, 16)
    path = [(4, 9), (5, 9), (6, 8), (7, 9), (8, 9), (9, 10), (10, 9), (11, 9), (12, 8)]
    n = (3, 5, 7, 9)[frame]
    for x, y in path[:n]:
        c.set(x, y, "1")
    for x, y in path[1:n:3]:
        c.set(x, y + 1, "1")
    if frame >= 2:
        for x, y in ((7, 10), (8, 8)):
            c.set(x, y, "x" if frame == 3 else "a")
    for k, (x, y) in enumerate(((5, 7), (10, 7), (8, 11))):
        if (k + frame) % 2:
            c.set(x, y - frame % 2, "3")
    return c.img


# =====================================================================================
# Spore bat
# =====================================================================================

def tri_fill(c, p0, p1, p2, key_fn):
    xs = [p[0] for p in (p0, p1, p2)]
    ys = [p[1] for p in (p0, p1, p2)]
    for y in range(int(min(ys)) - 1, int(max(ys)) + 2):
        for x in range(int(min(xs)) - 1, int(max(xs)) + 2):
            px_, py_ = x + 0.5, y + 0.5
            d1 = (px_ - p1[0]) * (p0[1] - p1[1]) - (p0[0] - p1[0]) * (py_ - p1[1])
            d2 = (px_ - p2[0]) * (p1[1] - p2[1]) - (p1[0] - p2[0]) * (py_ - p2[1])
            d3 = (px_ - p0[0]) * (p2[1] - p0[1]) - (p2[0] - p0[0]) * (py_ - p0[1])
            neg = d1 < 0 or d2 < 0 or d3 < 0
            pos = d1 > 0 or d2 > 0 or d3 > 0
            if not (neg and pos):
                c.set(x, y, key_fn(x, y))


def bat(d, flap=0, shift=(0, 0), lift=0, fold=False):
    """flap 0 wings up, 1 level, 2 down; fold: wings swept back for the dive."""
    fx, fy = DIRS[d]
    c = Canvas(16, 16)
    cx, cy = 7.5 + shift[0], 7 + shift[1] - lift
    side = d in ("left", "right")
    tip_y = (-4.5, -1, 2.5)[flap]
    for s in (-1, 1):
        span = 7.5 if not fold else 4.5
        if side and s == -fx:
            span -= 2.5                     # far wing, foreshortened
        tip = (cx + s * span, cy + tip_y)
        top = (cx + s * 1.5, cy - 1.5)
        low = (cx + s * 1.5, cy + 2.5)
        tri_fill(c, top, tip, low, lambda x, y: "H" if y < cy + tip_y * 0.3 + 0.5 else "h")
        # scalloped trailing edge: notches between the fingers
        for k in (0.45, 0.75):
            nx = cx + s * span * k
            ny = cy + tip_y * k + 2.5 * (1 - k) + 0.5
            c.px[int(nx), int(round(ny))] = (0, 0, 0, 0) if 0 <= int(nx) < 16 and 0 <= int(round(ny)) < 16 else None
        # a glowing spot on the membrane
        c.set(cx + s * span * 0.55, cy + tip_y * 0.55 + 0.4, "x")
    # body
    ellipse(c, cx, cy + 0.5, 2.3, 3.0, ("p", "H", "h"))
    c.set(cx - 1.5, cy - 2.5, "h")         # ears
    c.set(cx + 1.5, cy - 2.5, "h")
    if d == "down":
        c.set(cx - 1, cy, "x")
        c.set(cx + 1, cy, "x")
    elif side:
        c.set(cx + fx * 1.5, cy, "x")
    c.outline()
    shadow(c, 8 + shift[0], 14, 3)
    return c


def make_spore_bat():
    for d, (fx, fy) in DIRS.items():
        save("spore_bat", f"idle_{d}", [bat(d, flap=f, lift=l) for f, l in ((0, 0), (1, 1), (2, 1), (1, 0))])
        save("spore_bat", f"attack_{d}", [bat(d, flap=0, lift=2, shift=(-fx, -fy)), bat(d, flap=0, lift=3, shift=(-fx, -fy), fold=True),
                                          bat(d, flap=2, lift=-2, shift=(fx * 3, fy * 3), fold=True), bat(d, flap=1, shift=(fx, fy))])
        save("spore_bat", f"hurt_{d}", [flash(bat(d, flap=1, shift=(-fx, -fy))), bat(d, flap=2, shift=(-fx, -fy))])
    death = [flash(bat("down", flap=1)), bat("down", flap=2, lift=-2, fold=True), bat("down", flap=2, lift=-4, fold=True)]
    c = Canvas(16, 16)
    ellipse(c, 8, 12.5, 2.5, 1.5, ("H", "h", "h"))
    c.outline()
    for x, y in ((4, 9), (11, 8), (7, 7), (10, 11)):
        c.set(x, y, "v")
    death.append(c)
    save("spore_bat", "death", death)
    write_frames("spore_bat", 16)


# =====================================================================================
# Mummy (from the drowned)
# =====================================================================================

MUMMY = {"#c8c088": "D", "#9a9470": "S", "#1f1e29": "S", "#5d6072": "D", "#4c4e5f": "S", "#2a2935": "9",
         "#17161f": "8", "#3f4050": "9", "#767a8c": "D", "#f4f0e0": "Z", "#2aa8a0": "a", "#7a4a2c": "Y",
         "#3b5a45": "9", "#263a32": "8", "#3a7ac0": "S", "#1e3f6a": "9", "#7ac0f0": "D", "#343442": "9"}


def mummy_frame(img, strike_dir=None):
    c = Canvas(24, 24)
    src = img.load()

    def colour(x, y):
        if 0 <= x < 24 and 0 <= y < 24 and src[x, y][3]:
            return "#%02x%02x%02x" % src[x, y][:3]
        return None
    for y in range(24):
        for x in range(24):
            h = colour(x, y)
            if h is None:
                continue
            if h in ("#08070b", "#0f0e14"):
                c.set(x, y, "o" if h == "#08070b" else "d")
                continue
            if h == "#0f0e14" or y == 23:
                c.set(x, y, "d")
                continue
            edge = any(colour(x + dx, y + dy) is None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if h == "#343442" and edge:
                c.set(x, y, "o")
                continue
            k = MUMMY.get(h, "S")
            # bandage wraps: darker diagonal bands across the body
            if k in ("D", "S") and (y + x // 3) % 3 == 0:
                k = {"D": "S", "S": "9"}[k]
            c.set(x, y, k)
    if strike_dir:
        # loose bandage ends whip forward from the arms
        fx, fy = DIRS[strike_dir]
        pts = [(x, y) for y in range(24) for x in range(24) if c.get(x, y) not in (".", "o", "d") and 8 <= y <= 15]
        if pts:
            if fx:
                lead = max(pts, key=lambda p: p[0] * fx)
            else:
                lead = max(pts, key=lambda p: p[1] * fy) if fy > 0 else min(pts, key=lambda p: p[1])
            for k in range(1, 7):
                x = lead[0] + fx * k + (0 if fx else (1 if k % 2 else 0))
                y = lead[1] + fy * k * 0.6 + (int(math.sin(k) * 1.2) if fx else 0)
                c.set(x, y, "D" if k % 2 else "S")
            c.outline()
    return c


def mummy_death():
    src = Image.open(f"{E}/drowned_death.png").convert("RGBA")
    frames = [mummy_frame(src.crop((i * 24, 0, i * 24 + 24, 24))) for i in range(3)]
    for j in range(2):   # a heap of sand with bandage strips
        c = Canvas(24, 24)
        for y in range(16, 23):
            for x in range(4, 21):
                d = ((x + 0.5 - 12) / (8 - j)) ** 2 + ((y + 0.5 - 22) / (5 - j * 1.5)) ** 2
                if d <= 1:
                    c.set(x, y, "D" if d < 0.3 and y < 20 else "S" if d < 0.7 else "9")
        for x, y in ((7, 19), (8, 19), (9, 20), (15, 18), (16, 19), (14, 20)):
            if c.get(x, y) != ".":
                c.set(x, y, "W" if j == 0 else "w")
        if j == 0:
            c.set(11, 18, "Z")
        c.outline()
        for x in range(5, 20):
            if c.get(x, 23) == ".":
                c.set(x, 23, "d")
        if j == 0:
            for x, y in ((5, 13), (18, 12), (12, 11)):
                c.set(x, y, "S")       # sand still falling
        frames.append(c)
    return frames


def make_mummy():
    for path in sorted(glob.glob(f"{E}/drowned_*_*.png")):
        name = os.path.basename(path)[len("drowned_"):-4]
        anim, d = name.split("_")
        img = Image.open(path).convert("RGBA")
        frames = []
        for i in range(img.width // 24):
            f = img.crop((i * 24, 0, i * 24 + 24, 24))
            frames.append(mummy_frame(f, strike_dir=d if anim == "attack" and i in (2, 3) else None))
        save("mummy", name, frames)
    save("mummy", "death", mummy_death())
    write_frames("mummy", 24)


def grip_bandage():
    src = Image.open(f"{FX}/grip_seaweed.png").convert("RGBA")
    m = {"#3b5a45": "D", "#263a32": "9", "#2aa8a0": "S", "#3a7ac0": "S", "#7ac0f0": "D", "#08070b": "o"}
    c = Canvas(src.width, src.height)
    for y in range(src.height):
        for x in range(src.width):
            p = src.getpixel((x, y))
            if p[3]:
                c.set(x, y, m.get("#%02x%02x%02x" % p[:3], "S"))
    return c.img


# =====================================================================================
# Scarab (from the beetle)
# =====================================================================================

SCARAB = {"#2aa8a0": "Y", "#1e3f6a": "y", "#7ac0f0": "Z", "#9af0e0": "Z", "#3a7ac0": "a",
          "#f4f0e0": "A", "#d8d4c4": "Z"}


def scarab_frame(img):
    c = Canvas(16, 16)
    for y in range(16):
        for x in range(16):
            p = img.getpixel((x, y))
            if not p[3]:
                continue
            h = "#%02x%02x%02x" % p[:3]
            k = SCARAB.get(h)
            if k is None:
                k = b15.KEY.get(p[:3] + (255,), "o")
            c.set(x, y, k)
    # a turquoise stripe down the middle of the shell
    for y in range(16):
        row = [x for x in range(16) if c.get(x, y) in ("Y", "y")]
        if len(row) >= 4:
            mid = (row[0] + row[-1]) // 2
            if c.get(mid, y) in ("Y", "y"):
                c.set(mid, y, "a")
    return c


def scarab_strip(name):
    img = Image.open(f"{E}/beetle_{name}.png").convert("RGBA")
    return [scarab_frame(img.crop((i * 16, 0, i * 16 + 16, 16))) for i in range(img.width // 16)]


def sand_mound(c, cx, base, w, h):
    for y in range(base - h, base + 1):
        for x in range(cx - w, cx + w + 1):
            d = ((x + 0.5 - cx - 0.5) / (w + 0.5)) ** 2 + ((y - base) / (h + 0.5)) ** 2
            if d <= 1:
                c.set(x, y, "D" if y == base - h or (x < cx and d < 0.5) else "S" if d < 0.8 else "9")


def burrow_frames(reverse=False):
    idle = scarab_strip("idle_down")[0]
    frames = []
    for i, sink in enumerate((0, 3, 6, 9)):
        c = Canvas(16, 16)
        for y in range(16 - sink):
            for x in range(16):
                k = idle.get(x, y)
                if k != "." and k != "d" and y + sink <= 13:
                    c.set(x, y + sink, k)
        sand_mound(c, 7, 14, 4 + i // 2, 1 + i // 2)
        rnd = random.Random(i)
        for _ in range(3 + i):
            c.set(rnd.randint(2, 13), rnd.randint(6, 12) - (i if reverse else 0), "S")
        frames.append(c)
    return frames[::-1] if reverse else frames


def make_scarab():
    for d in DIRS:
        idle = scarab_strip(f"idle_{d}")
        save("scarab", f"idle_{d}", idle[0:8:2])
        for anim in ("walk", "attack", "hurt"):
            save("scarab", f"{anim}_{d}", scarab_strip(f"{anim}_{d}"))
    save("scarab", "death", scarab_strip("death"))
    save("scarab", "burrow", burrow_frames())
    save("scarab", "emerge", burrow_frames(reverse=True))
    write_frames("scarab", 16)


# =====================================================================================
# Sand serpent
# =====================================================================================

SAND_LINE = 28


def serpent(d, rise=1.0, lunge=0, jaw=0, flashing=False, sunk=0.0, lying=0.0):
    """rise 0..1: how far the neck stands out of the sand; lunge: head pushed along the
    facing; jaw 0 closed / 1 open; lying 0..1 for the death."""
    fx, fy = DIRS[d]
    c = Canvas(32, 32)
    base_x = 16 - fx * 3
    hole_y = SAND_LINE
    neck_h = 16 * rise * (1 - sunk)
    hx_ = base_x + fx * (5 * rise + lunge) + (1 if d == "down" else 0)
    hy_ = hole_y - neck_h + fy * lunge * 0.5
    if lying:
        hx_ = base_x + (12 * lying) * (1 if fx >= 0 else -1)
        hy_ = hole_y - neck_h * (1 - lying) - 2
    # the neck: a thick curve from the hole to the head, banded
    n = 24
    for i in range(n + 1):
        t = i / n
        x = base_x + (hx_ - base_x) * (t ** 2) - math.sin(t * math.pi) * 3 * fx * (1 - lying)
        y = hole_y - (hole_y - hy_) * t
        w = 3.2 - t * 0.9
        for dx in range(-int(w), int(w) + 1):
            k = "D" if dx < -w / 3 else "S" if dx < w / 2 else "9"
            if (i // 3) % 3 == 1:
                k = "a" if abs(dx) < w - 1 else "y"
            c.set(x + dx, y, k)
    if neck_h > 3 or lying:
        # the head
        ellipse(c, hx_, hy_ - 1, 4.0, 3.2, ("D", "S", "9"))
        if d != "up":
            ex = (-1.5, 1.5) if d == "down" else ((1.5 * fx, 1.5 * fx))
            for e in ex:
                c.set(hx_ + e, hy_ - 2, "Z")
                c.set(hx_ + e, hy_ - 1, "y")
        for k in (-1, 1):       # turquoise hood marks
            c.set(hx_ + k * 3, hy_ - 1, "a")
        if jaw:
            mx = hx_ + (fx * 3 if fx else 0)
            my = hy_ + (2 if d == "down" else 0) + (fy * 2 if fy < 0 else 0)
            for dx in range(-2, 3):
                c.set(mx + dx, my, "o")
                c.set(mx + dx, my + 1, "r")
            c.set(mx - 2, my - 1, "W")
            c.set(mx + 2, my - 1, "W")
            c.set(mx, my + 2, "q")   # tongue
    if flashing:
        c = flash(c)
    c.outline()
    # the sand around the hole
    sand_mound(c, base_x, SAND_LINE, 7, 2)
    shadow(c, base_x, SAND_LINE + 1, 7)
    return c


def bump(frame, d, big=False):
    fx, fy = DIRS[d]
    c = Canvas(32, 32)
    off = (frame % 4) - 1.5
    cx = 16 + int(round(fx * off))
    cy = SAND_LINE + int(round(fy * off * 0.5))
    sand_mound(c, cx, cy, 8 if big else 7, 4 if big else 3)
    # trail behind it and grains thrown up
    for k in range(1, 4):
        c.set(cx - fx * (6 + k * 2), cy - fy * k * 2, "9")
    for k, (x, y) in enumerate(((cx - 3, cy - 4), (cx + 3, cy - 5), (cx, cy - 6))):
        if (k + frame) % 2:
            c.set(x, y, "D")
    shadow(c, cx, SAND_LINE + 1, 6)
    return c


def make_serpent():
    for d, (fx, fy) in DIRS.items():
        save("sand_serpent", f"hidden_{d}", [bump(i, d) for i in range(4)])
        save("sand_serpent", f"emerge_{d}", [bump(0, d, big=True), serpent(d, rise=0.45), serpent(d, rise=1.0, lunge=-3, jaw=1),
                                             serpent(d, rise=1.0, lunge=5, jaw=1), serpent(d, rise=1.0, lunge=3), serpent(d)])
        save("sand_serpent", f"sink_{d}", [serpent(d, sunk=0.2), serpent(d, sunk=0.55), serpent(d, rise=0.2), bump(0, d, big=True)])
        save("sand_serpent", f"hurt_{d}", [serpent(d, flashing=True, lunge=-2), serpent(d, lunge=-2)])
    save("sand_serpent", "death", [serpent("down", flashing=True), serpent("right", lying=0.4), serpent("right", lying=1.0),
                                   serpent("right", lying=1.0, sunk=0.5), bump(0, "down")])
    write_frames("sand_serpent", 32)


# --- sand effects ------------------------------------------------------------------

def sand_ripple(frame):
    c = Canvas(16, 16)
    for ring in (frame, frame + 2):
        r = 1.5 + (ring % 4) * 1.6
        for a in range(0, 360, 9):
            t = math.radians(a)
            x, y = 8 + math.cos(t) * r, 8 + math.sin(t) * r * 0.65
            if (a // 9 + ring) % 4:
                c.set(x, y, "9" if r > 5 else "S")
    c.set(8, 8, "D" if frame % 2 else "S")
    return c.img


def sun_beam(frame):
    """A piece of the beam, seamless left-right: a white core, gold and orange edges,
    light knots running along it."""
    c = Canvas(16, 8)
    for x in range(16):
        wob = 1 if (x + frame * 4) % 8 in (0, 1) else 0
        for y, k in ((0 + (1 - wob), "q"), (1, "Y"), (2, "Z"), (3, "W"), (4, "W"), (5, "Z"), (6, "Y"), (7 - (1 - wob), "q")):
            c.set(x, y, k)
        if (x + frame * 4) % 8 == 3:
            c.set(x, 2, "W")
            c.set(x, 5, "W")
    return c.img


def sun_beam_warn(frame):
    c = Canvas(16, 8)
    for x in range(16):
        if frame == 0 or x % 4 < 2:
            c.set(x, 3, "Y" if frame == 0 else "q")
            c.set(x, 4, "Z" if frame == 0 else "Y")
    return c.img


def sand_ring():
    size, cc = 64, 32.0
    radii = [6, 12, 18, 23, 27, 30]
    rnd = random.Random(17)
    grains = [rnd.uniform(0, math.tau) for _ in range(16)]
    frames = []
    for i, radius in enumerate(radii):
        c = Canvas(size, size)
        thick = 4.0 if i < 4 else 2.5
        for y in range(size):
            for x in range(size):
                dx, dy = x + 0.5 - cc, y + 0.5 - cc
                r = math.hypot(dx, dy)
                ang = math.atan2(dy, dx)
                wave = math.sin(ang * 7 + i * 0.8) * 0.9
                if not (radius - thick + wave <= r <= radius + wave * 0.4):
                    continue
                seg = int((ang + math.pi) / math.tau * 24)
                gaps = 0 if i < 3 else 1 if i < 5 else 2
                if gaps and seg % 4 < gaps:
                    continue
                outer = radius + wave * 0.4 - r
                k = "D" if outer < 1 else "S" if outer < 2.2 else "9"
                if i >= 4:
                    k = "S" if outer < 1 else "9"
                c.set(x, y, k)
        c.outline(skip=("d", "9"))
        for ang in grains:
            if i == 0:
                break
            rr = radius + 2 + (i % 2) + (ang * 3) % 2
            c.set(cc + math.cos(ang) * rr, cc + math.sin(ang) * rr - (1 if i < 4 else 0), "D" if i < 3 else "S")
        frames.append(c.img)
    return strip(frames)


def spore_ring():
    """Mycelium Mother's phase-2 wave: a toxic green spore ring with violet sparks,
    built like sand_ring (radius 6 ... 30, gaps open as it fades)."""
    size, cc = 64, 32.0
    radii = [6, 12, 18, 23, 27, 30]
    rnd = random.Random(19)
    sparks = [(rnd.uniform(0, math.tau), rnd.uniform(0, 2)) for _ in range(24)]
    frames = []
    for i, radius in enumerate(radii):
        c = Canvas(size, size)
        thick = 4.0 if i < 4 else 2.5
        for y in range(size):
            for x in range(size):
                dx, dy = x + 0.5 - cc, y + 0.5 - cc
                r = math.hypot(dx, dy)
                ang = math.atan2(dy, dx)
                # puffy edge: round bumps like little spore clouds
                wave = abs(math.sin(ang * 6 + i * 0.7)) * 1.4 - 0.5
                if not (radius - thick + wave * 0.3 <= r <= radius + wave):
                    continue
                seg = int((ang + math.pi) / math.tau * 24)
                gaps = 0 if i < 3 else 1 if i < 5 else 2
                if gaps and (seg + i) % 4 < gaps:
                    continue
                outer = radius + wave - r
                k = "v" if outer < 1 else "V" if outer < 2.2 else "G"
                if i >= 4:
                    k = "V" if outer < 1 else "G"
                if outer >= 1 and (x * 7 + y * 13 + i * 5) % 17 == 0:
                    k = "H"  # violet spores inside the band
                c.set(x, y, k)
        c.outline(skip=())
        for y in range(size):  # gas, not a solid: dark green rim instead of black
            for x in range(size):
                if c.get(x, y) == "o":
                    c.set(x, y, "N")
        if i > 0:
            for n, (ang, off) in enumerate(sparks):
                rr = radius + 1 + off + (n % 3) - (i % 2)
                x, y = cc + math.cos(ang + i * 0.05) * rr, cc + math.sin(ang + i * 0.05) * rr
                if n % 3 == 0:
                    c.set(x, y, "p" if i < 4 else "H")
                elif n % 3 == 1 and i < 5:
                    c.set(x, y, "H")
                elif i < 3:
                    c.set(x, y, "x")
                if n % 4 == 0 and i < 4:  # bright violet crosses on the strongest frames
                    for ddx, ddy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        c.set(x + ddx, y + ddy, "H")
                    c.set(x, y, "p")
        frames.append(c.img)
    return strip(frames)


def sun_beam_hit(frame):
    """Flash where the sun beam meets a wall, loop of 4: white-gold core, rays that flicker,
    sparks thrown back. Centre (8, 8)."""
    c = Canvas(16, 16)
    core = (3.2, 4.2, 3.6, 4.6)[frame]
    rnd = random.Random(23 + frame)
    for y in range(16):
        for x in range(16):
            d = math.hypot(x + 0.5 - 8, y + 0.5 - 8)
            if d <= core:
                c.set(x, y, "W" if d < core - 2.2 else "Z" if d < core - 1 else "Y")
    rays = ((1, 0), (-1, 0), (0, 1), (0, -1)) if frame % 2 == 0 else ((1, 1), (-1, -1), (1, -1), (-1, 1))
    reach = 6 + frame % 2
    for dx, dy in rays:
        start = int(core)
        for t in range(start, reach + 1):
            c.set(8 + dx * t - (dx < 0) * 0, 8 + dy * t, "Z" if t < reach - 1 else "q")
    for _ in range(3):
        a = rnd.uniform(0, math.tau)
        rr = rnd.uniform(5, 7)
        c.set(8 + math.cos(a) * rr, 8 + math.sin(a) * rr, rnd.choice("YZq"))
    return c.img


def make_extra():
    spore_ring().save(f"{FX}/spore_ring.png")
    strip([sun_beam_hit(i) for i in range(4)]).save(f"{FX}/sun_beam_hit.png")


def main():
    make_sporeling()
    make_vine_lurker()
    make_spore_bat()
    vine_lash().save(f"{FX}/vine_lash.png")
    strip([root_spike(i) for i in range(6)]).save(f"{FX}/root_spike.png")
    strip([root_warn(i) for i in range(4)]).save(f"{FX}/root_warn.png")
    make_mummy()
    grip_bandage().save(f"{FX}/grip_bandage.png")
    make_scarab()
    make_serpent()
    strip([sand_ripple(i) for i in range(4)]).save(f"{FX}/sand_ripple.png")
    strip([sun_beam(i) for i in range(4)]).save(f"{FX}/sun_beam.png")
    strip([sun_beam_warn(i) for i in range(2)]).save(f"{FX}/sun_beam_warn.png")
    sand_ring().save(f"{FX}/sand_ring.png")
    make_extra()
    print("biome enemies done")


if __name__ == "__main__":
    if sys.argv[1:] == ["extra"]:
        make_extra()
        print("spore_ring, sun_beam_hit done")
    else:
        main()
