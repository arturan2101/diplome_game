"""Batch 15, part 2: two elemental variants of the Ruins Warden, made from the warden_*
strips (tools/art/finish_warden.py), so the silhouette, the frame counts and the
wind-up / strike frames stay exactly the same.

  Tide Warden    tide_warden_<anim>_<dir>.png, tide_warden_death.png, tide_warden_frames.tres
                 wet green-grey marble, corals and shells on the shoulders and the shield,
                 seaweed instead of the red sash, teal eyes and cracks (#2aa8a0), drops;
                 the boulder it holds in the throw is a ball of water.
  Molten Warden  molten_warden_<anim>_<dir>.png, molten_warden_death.png, molten_warden_frames.tres
                 black basalt with lava in the cracks, orange eyes, a red-hot shield, sparks;
                 the boulder in the throw is a molten rock.

How: every pixel is recoloured by its warden colour (maps TIDE / MOLTEN below); the
shield and the held boulder share the body's colours (see stone_parts). Corals sit on the top of the shoulders, found
from the crown (the gold pixels). Drops and sparks are placed per frame.

New attack per variant (4 directions, 8 frames, 96x96, feet at (48, 92)), built from
warden poses, with water or fire drawn over the hands:
  tide_warden_geyser_<dir>   kneels and slams a palm on the floor: 0 stand, 1-3 the fist
                             raised with water gathering round it (hold 3), 4 impact in
                             the crouch with a splash, 5-6 crouch, 7 recover
                             (summon 0-3 + slam 4-7)
  molten_warden_meteor_<dir> both arms up, a fireball gathers over the head: 1-3 wind-up
                             (fire grows, hold 3), 4 the fireball is thrown up and leaves
                             the frame, 5-7 arms come down (slam 0-3, then 3-0)
Run from the project root: python tools/art/make_elemental_wardens.py
"""
import glob
import math
import os
import random
import zlib

from PIL import Image

SRC = "assets/art/enemies"
F = 96
DIRS = ("down", "up", "left", "right")
ANIMS = ("idle", "walk", "slam", "throw", "wave", "summon", "roar", "hurt")
FPS = {"idle": 6.0, "walk": 10.0, "slam": 10.0, "throw": 10.0, "wave": 10.0, "summon": 8.0,
       "roar": 10.0, "hurt": 12.0, "death": 10.0, "geyser": 10.0, "meteor": 10.0}
LOOP = {"idle", "walk"}


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def hx(c):
    return "#%02x%02x%02x" % c[:3]


OUTLINE = "#08070b"
SHADOW = "#0f0e14"
WHITE = {"#f4f0e0", "#d8d4c4"}
GREY = {"#9aa2ad", "#767a8c", "#5d6072", "#4c4e5f", "#3f4050", "#343442", "#2a2935",
        "#9a5ae0", "#4a2a78"}
PURPLE = {"#9a5ae0", "#4a2a78"}
GOLD = {"#e09a20", "#ffd860", "#8a4a10"}

# Tide Warden: wet green-grey marble (extra colours, docs/art-style.md "Elemental Wardens")
TIDE = {
    "#f4f0e0": "#cfe0d2", "#d8d4c4": "#a6c0b0", "#9aa2ad": "#7c9a8c", "#767a8c": "#5a786c",
    "#5d6072": "#3f5a50", "#4c4e5f": "#3f5a50", "#3f4050": "#263a32", "#343442": "#263a32",
    "#9a5ae0": "#2aa8a0", "#4a2a78": "#3f5a50",
    "#a82a30": "#5a8a4a", "#5a1820": "#3b5a45", "#e85a3a": "#8ac060",
}
TIDE_SHIELD = {   # the shield: darker, bluer wet stone
    "#f4f0e0": "#a6c0b0", "#d8d4c4": "#a6c0b0", "#9aa2ad": "#5a786c", "#767a8c": "#3f5a50",
    "#5d6072": "#263a32", "#4c4e5f": "#263a32", "#3f4050": "#17161f", "#343442": "#17161f",
    "#2a2935": "#17161f", "#9a5ae0": "#9af0e0", "#4a2a78": "#2aa8a0",
}
# Molten Warden: black basalt; the lit marble becomes the grey top faces of the rock
MOLTEN = {
    "#f4f0e0": "#767a8c", "#d8d4c4": "#5d6072", "#9aa2ad": "#1f1e29", "#767a8c": "#1f1e29",
    "#5d6072": "#17161f", "#4c4e5f": "#17161f", "#3f4050": "#0f0e14", "#343442": "#0f0e14",
    "#2a2935": "#0f0e14", "#1f1e29": "#0f0e14",
    "#9a5ae0": "#ffd860", "#4a2a78": "#e85a3a",
}
MOLTEN_SHIELD = {   # red-hot
    "#f4f0e0": "#ffd860", "#d8d4c4": "#e09a20", "#9aa2ad": "#e85a3a", "#767a8c": "#a82a30",
    "#5d6072": "#5a1820", "#4c4e5f": "#5a1820", "#3f4050": "#5a1820", "#343442": "#17161f",
    "#2a2935": "#17161f", "#9a5ae0": "#f4f0e0", "#4a2a78": "#ffd860",
}
MOLTEN_BOULDER = {
    "#f4f0e0": "#5d6072", "#d8d4c4": "#5d6072", "#9aa2ad": "#1f1e29", "#767a8c": "#17161f",
    "#5d6072": "#e85a3a", "#4c4e5f": "#a82a30", "#3f4050": "#17161f", "#343442": "#17161f",
    "#2a2935": "#0f0e14", "#9a5ae0": "#ffd860", "#4a2a78": "#e09a20",
}

N4 = ((1, 0), (-1, 0), (0, 1), (0, -1))


def load_frames(path):
    im = Image.open(path).convert("RGBA")
    return [im.crop((i * F, 0, (i + 1) * F, F)) for i in range(im.width // F)]


def colours(frame):
    px = frame.load()
    return {(x, y): hx(px[x, y]) for y in range(F) for x in range(F) if px[x, y][3]}


def body_of(col):
    return {p for p, c in col.items() if c not in (OUTLINE, SHADOW)}


def components(points):
    points = set(points)
    out = []
    while points:
        start = points.pop()
        comp = [start]
        stack = [start]
        while stack:
            x, y = stack.pop()
            for dx, dy in N4:
                q = (x + dx, y + dy)
                if q in points:
                    points.remove(q)
                    comp.append(q)
                    stack.append(q)
        out.append(comp)
    return out


def crown(col):
    """Centre of the gold crown (the topmost gold cluster)."""
    gold = [p for p, c in col.items() if c in GOLD]
    if not gold:
        return None
    top = min(y for _, y in gold)
    near = [p for p in gold if p[1] <= top + 8]
    return (sum(x for x, _ in near) / len(near), sum(y for _, y in near) / len(near))


def stone_parts(col, anim, frame_index):
    """The shield and the boulder would need their own colours, but in the warden strips
    their grey shading joins the body's shadows into one region, so they cannot be
    separated by colour; they are recoloured with the body (empty sets)."""
    return set(), set()


def recolour(frame, base, part_maps):
    col = colours(frame)
    out = frame.copy()
    px = out.load()
    for p, c in col.items():
        m = base
        for pts, mp in part_maps:
            if p in pts:
                m = mp
                break
        if c in m:
            px[p] = hexc(m[c])
    return out, col


def put(img, x, y, c, only_on=None):
    x, y = int(round(x)), int(round(y))
    if 0 <= x < F and 0 <= y < F:
        if only_on is not None and not img.getpixel((x, y))[3]:
            return
        img.putpixel((x, y), hexc(c))


def outline_new(img, before):
    """Outline around pixels that were added outside the old silhouette."""
    px = img.load()
    add = []
    for y in range(F):
        for x in range(F):
            if px[x, y][3]:
                continue
            for dx, dy in N4:
                nx, ny = x + dx, y + dy
                if 0 <= nx < F and 0 <= ny < F and px[nx, ny][3] and not before[nx, ny][3] \
                        and hx(px[nx, ny]) not in (OUTLINE, SHADOW):
                    add.append((x, y))
                    break
    for p in add:
        px[p] = hexc(OUTLINE)


# --- details ----------------------------------------------------------------------------

CORAL = [            # 5 wide, grows up from the bottom row; q tips, u highlights, R base
    "q...u",
    "q.q.q",
    "Rq.qR",
    ".RqR.",
    "..R..",
]
SHELL = ["uWu", "cuc"]
BARNACLE = ["WT", "Te"]
KEYS = {"q": "#e85a3a", "u": "#e0a070", "R": "#a82a30", "W": "#f4f0e0", "c": "#b07040",
        "T": "#7c9a8c", "e": "#263a32"}


def stamp(img, pattern, x0, y0):
    for dy, row in enumerate(pattern):
        for dx, ch in enumerate(row):
            if ch != ".":
                put(img, x0 + dx, y0 + dy, KEYS[ch])


def shoulder_tops(body, cr, direction):
    """Top body pixel at the two shoulder columns (left and right of the crown)."""
    cx, cy = cr
    out = []
    offsets = (-12, 12) if direction in ("down", "up") else (-7, 7)
    for off in offsets:
        x = int(round(cx + off))
        ys = [y for (bx, y) in body if bx == x and cy - 2 <= y <= cy + 18]
        if ys:
            out.append((x, min(ys)))
    return out


def tide_details(img, col, body, shield, anim, direction, i):
    cr = crown(col)
    if cr:
        tops = shoulder_tops(body, cr, direction)
        for n, (x, y) in enumerate(tops):
            if n == 0:
                stamp(img, CORAL, x - 2, y - 3)
            else:
                stamp(img, SHELL, x - 1, y)
                stamp(img, CORAL[2:], x - 1, y - 1) if direction in ("left", "right") else None
    if shield:
        xs = sorted(shield)
        sx = sum(x for x, _ in xs) / len(xs)
        sy = sum(y for _, y in xs) / len(xs)
        for dx, dy in ((-4, -4), (3, 3), (-3, 4), (4, -2)):
            if (int(sx + dx), int(sy + dy)) in shield and (int(sx + dx) + 1, int(sy + dy) + 1) in shield:
                stamp(img, BARNACLE, sx + dx, sy + dy)
        top = min(y for _, y in shield)
        tx = [x for x, y in shield if y == top]
        if tx:
            stamp(img, ["q.q", "RqR"], tx[len(tx) // 2] - 1, top - 1)
    # drops falling from the lower edges of the arms and the shield
    rnd = random.Random(zlib.crc32(f"{anim}{direction}".encode()))
    edges = sorted((x, y) for (x, y) in body if (x, y + 1) not in body and (x, y + 2) not in body and y < 84)
    if edges:
        for k in range(3):
            x, y = edges[rnd.randrange(len(edges))]
            fall = (i * 2 + k * 3) % 6
            if fall < 5:
                put(img, x, y + 2 + fall, "#7ac0f0")
                if fall < 2:
                    put(img, x, y + 3 + fall, "#3a7ac0")


def molten_details(img, col, body, anim, direction, i):
    """Lava in the deep cracks (the darkest inner shading of the marble), sparks."""
    lava = []
    for (x, y), c in col.items():
        if c in ("#3f4050", "#343442", "#2a2935") and (x, y) in body:
            if all((x + dx, y + dy) in body for dx, dy in N4):
                lava.append((x, y))
    for x, y in lava:
        put(img, x, y, "#e85a3a" if (x + y) % 3 else "#e09a20")
    rnd = random.Random((zlib.crc32(f"{anim}{direction}".encode())) + i * 7)
    tops = sorted(p for p in body if (p[0], p[1] - 1) not in body)
    for _ in range(5):
        if not tops:
            break
        x, y = tops[rnd.randrange(len(tops))]
        rise = rnd.randint(2, 7)
        put(img, x + rnd.randint(-1, 1), y - rise, rnd.choice(("#ffd860", "#e09a20", "#e85a3a")))


def water_ball(img, cx, cy, r, phase):
    for y in range(int(cy - r - 1), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            lit = (-dx - dy) / (r * 1.414)
            put(img, x, y, "#7ac0f0" if lit > 0.35 else "#3a7ac0" if lit > -0.45 else "#1e3f6a")
    for t in range(4):
        a = phase + t * 0.5
        put(img, cx + math.cos(a) * (r - 1.4), cy + math.sin(a) * (r - 1.4), "#9af0e0")
    put(img, cx - r * 0.45, cy - r * 0.5, "#f4f0e0")


def fire_ball(img, cx, cy, r, phase):
    for y in range(int(cy - r * 1.8), int(cy + r + 2)):
        for x in range(int(cx - r - 1), int(cx + r + 2)):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            # a flame: round below, tongues licking up
            tongue = 0.6 * r * max(0, math.sin(dx * 1.3 + phase)) if dy < 0 else 0
            d = math.hypot(dx, dy if dy > 0 else dy * (r / (r + tongue + 0.01)))
            if d > r:
                continue
            k = d / r
            put(img, x, y, "#f4f0e0" if k < 0.25 else "#ffd860" if k < 0.5 else "#e09a20" if k < 0.75
                else "#e85a3a" if k < 0.92 else "#a82a30")


def top_point(body):
    top = min(y for _, y in body)
    xs = [x for x, y in body if y <= top + 2]
    return sum(xs) / len(xs), top


# --- build ------------------------------------------------------------------------------

def variant_frame(kind, frame, anim, direction, i):
    col = colours(frame)
    body = body_of(col)
    shield, boulder = stone_parts(col, anim, i)
    if kind == "tide":
        out, _ = recolour(frame, TIDE, [(shield, TIDE_SHIELD), (boulder, TIDE_SHIELD)])
        before = out.copy().load()
        if boulder:
            bx = sum(x for x, _ in boulder) / len(boulder)
            by = sum(y for _, y in boulder) / len(boulder)
            r = max(4.0, math.sqrt(len(boulder) / math.pi) + 0.5)
            water_ball(out, bx, by, r, i)
        tide_details(out, col, body, shield, anim, direction, i)
    else:
        out, _ = recolour(frame, MOLTEN, [(shield, MOLTEN_SHIELD), (boulder, MOLTEN_BOULDER)])
        before = out.copy().load()
        molten_details(out, col, body - shield - boulder, anim, direction, i)
    outline_new(out, before)
    return out


def save_strip(frames, path):
    out = Image.new("RGBA", (F * len(frames), F))
    for i, f in enumerate(frames):
        out.paste(f, (i * F, 0))
    out.save(path)


def geyser(direction):
    summon = load_frames(f"{SRC}/warden_summon_{direction}.png")
    slam = load_frames(f"{SRC}/warden_slam_{direction}.png")
    seq = [("summon", summon[n], n) for n in range(4)] + [("slam", slam[n], n) for n in range(4, 8)]
    frames = []
    for i, (anim, f, n) in enumerate(seq):
        out = variant_frame("tide", f, anim, direction, n)
        before = out.copy().load()
        body = body_of(colours(f))
        if 1 <= i <= 3:   # water gathering round the raised fist
            x, y = top_point(body)
            water_ball(out, x, y - 1, (2.5, 3.5, 4.5)[i - 1], i)
        if i == 4:        # the splash where the palms hit the floor
            for side in (-1, 1):
                for k in range(6):
                    put(out, 48 + side * (12 + k), 91 - (k % 3) - k // 2, "#7ac0f0" if k % 2 else "#f4f0e0")
                    put(out, 48 + side * (13 + k), 92 - (k % 2), "#3a7ac0")
        if i in (5, 6):   # drops falling back
            for k, x in enumerate((30, 36, 60, 66)):
                put(out, x, 80 + (i - 5) * 5 + k % 2 * 2, "#7ac0f0")
        outline_new(out, before)
        frames.append(out)
    save_strip(frames, f"{SRC}/tide_warden_geyser_{direction}.png")


def meteor(direction):
    slam = load_frames(f"{SRC}/warden_slam_{direction}.png")
    order = [0, 1, 2, 3, 3, 2, 1, 0]
    frames = []
    for i, n in enumerate(order):
        f = slam[n]
        out = variant_frame("molten", f, "slam", direction, n + i)
        body = body_of(colours(f))
        x, y = top_point(body)
        if 1 <= i <= 3:   # fire gathering over the hands
            r = (2.5, 4.0, 5.5)[i - 1]
            fire_ball(out, x, y - r - 1, r, i)
        elif i == 4:      # thrown up: the fireball leaves the top of the frame, a trail below it
            fire_ball(out, x, 5, 4.5, i)
            for yy in range(11, int(y) - 1):
                for dx in (-1, 0, 1):
                    if (yy + dx) % 3:
                        put(out, x + dx + (yy % 2), yy, "#e09a20" if abs(dx) < 1 else "#e85a3a")
        elif i == 5:      # sparks left over the hands
            for dx, dy in ((-3, -3), (2, -5), (4, -2), (-1, -7)):
                put(out, x + dx, y + dy, "#ffd860" if dy < -4 else "#e85a3a")
        frames.append(out)
    save_strip(frames, f"{SRC}/molten_warden_meteor_{direction}.png")


def write_frames(name):
    entries = []
    for path in sorted(glob.glob(os.path.join(SRC, f"{name}_*.png"))):
        anim = os.path.basename(path)[len(name) + 1:-4]
        kind = anim.split("_")[0]
        if kind not in FPS:
            continue
        entries.append((anim, os.path.basename(path), Image.open(path).width // F))
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(entries) + sum(c for _, _, c in entries)} format=3]', ""]
    for anim, fname, _ in entries:
        lines.append(f'[ext_resource type="Texture2D" path="res://{SRC}/{fname}" id="{anim}"]')
    lines.append("")
    for anim, _, count in entries:
        for i in range(count):
            lines += [f'[sub_resource type="AtlasTexture" id="{anim}_{i}"]', f'atlas = ExtResource("{anim}")',
                      f"region = Rect2({i * F}, 0, {F}, {F})", ""]
    blocks = []
    for anim, _, count in entries:
        kind = anim.split("_")[0]
        frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (anim, i) for i in range(count))
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                      % (frames, "true" if kind in LOOP else "false", anim, FPS[kind]))
    lines += ["[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    with open(os.path.join(SRC, f"{name}_frames.tres"), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(lines))


def main():
    for kind in ("tide", "molten"):
        name = f"{kind}_warden"
        for anim in ANIMS:
            for d in DIRS:
                frames = load_frames(f"{SRC}/warden_{anim}_{d}.png")
                save_strip([variant_frame(kind, f, anim, d, i) for i, f in enumerate(frames)],
                           f"{SRC}/{name}_{anim}_{d}.png")
        death = load_frames(f"{SRC}/warden_death.png")
        save_strip([variant_frame(kind, f, "death", "down", i) for i, f in enumerate(death)],
                   f"{SRC}/{name}_death.png")
    for d in DIRS:
        geyser(d)
        meteor(d)
    write_frames("tide_warden")
    write_frames("molten_warden")
    print("elemental wardens done")


if __name__ == "__main__":
    main()
