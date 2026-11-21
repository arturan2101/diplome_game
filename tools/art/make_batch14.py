"""Batch 14: the places that still used placeholders or the ruins look everywhere
(docs/art-style.md palette, light from the top-left, 1 px #08070b outline on actors,
objects and UI; none on tiles).

1. Touch controls (assets/art/ui/):
   - touch_button.png 96x48: round stone button 48x48, normal | pressed. The top disc
     stands 3 px above its dark front side; pressed, the disc sinks (1 px of side left)
     and its stone gets one step darker. The inner face (radius ~16) holds the 32 px icon.
   - touch_button_small.png 64x32: the same at 32x32 (2 px side) for swap, take, pause,
     spells.
   - touch_cooldown.png 384x48: 8 frames of a ring over the rim of the 48 px button
     (same centre as its unpressed top disc): frame i is (i + 1) / 8 filled with gold,
     clockwise from 12 o'clock, the rest a dark groove; frame 7 = full = ready.
   - touch_joystick_base.png 96x96 (radius 48, drawn 1:1 by ui/touch_joystick.gd): a
     ring of carved stone blocks round a dark recess, four purple direction notches.
   - touch_joystick_knob.png 40x40 (knob radius 18 + outline): a lighter stone cap
     standing 3 px high with a purple rune in the middle.
2. UI panels (assets/art/ui/):
   - card_frame.png 24x24, 9-slice with 6 px corners: dark stone border lit from the
     top-left, a 1 px gold inner line, flat #1f1e29 inside; edges are constant along
     their length so they stretch cleanly. Modulate it with the rarity colour.
   - death_plate.png 160x32: "YOU FELL" in carved stone letters like the title logo,
     with a red glow instead of the purple one.
   - death_art.png 96x64: the hero's sword stuck in the floor, the red scarf tied to the
     hilt, before the open portal (portal_loop.png frame 0) that lights the floor purple.
   - pause_plate.png 128x24: "PAUSED" raised on a dark stone slab, purple glow.
3. Floor styles (assets/art/level/, assets/art/tiles/), like the ruins set of batch 10:
   - cover obstacles, bottom row = bottom of the cell, taller ones rise above it:
     flooded_obstacle_coral_column 16x32, flooded_obstacle_barrel 16x16,
     flooded_obstacle_boat 32x16 (two cells); fire_obstacle_basalt_column 16x32,
     fire_obstacle_lava_rock 16x16, fire_obstacle_brazier 16x24.
   - wall details (overlays on rows 6-14 of the wall front, strip of 5 slots, 80x16):
     flooded_wall_details.png: 0 dripping water, 1 hanging seaweed, 2 barnacles,
     3 rusty grate with water behind, 4 glowing shell; fire_wall_details.png: 0 glowing
     crack, 1 red-hot chain, 2 soot stain, 3 small lava drip, 4 charred banner.
   - wall lights instead of the torch, 4 frames of 16x16 like torch.png:
     level/flooded_lantern.png (cold blue-green), level/fire_brazier.png.
   - door rubble like tiles/door_seal.png: tiles/flooded_door_seal.png (wet rocks,
     water and weed between them), tiles/fire_door_seal.png (basalt, glowing seams).
4. assets/art/fx/grip_seaweed.png 64x8: 4 frames of 16x8 loop, seaweed wrapped round
   the legs with drops falling, centred on the player's feet (bottom row = the feet row).
   (player_cast_* and player_parry_*: tools/art/import_player_cast_parry.py)
5. assets/art/ui/status_icons.png 48x12: slowed, rune key held, lucky charm active,
   sure critical hit ready.
6. assets/art/enemies/training_dummy.png 72x24 (idle, hit, hit): the hit frames now
   wobble, the top bent away from the blow and then swinging back past the middle
   (dummy_frames() in make_world_props.py).
Run from the project root: python tools/art/make_batch14.py
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_title as mt  # noqa: E402  (UI palette C: s=#5d6072, e=#4c4e5f, 5=#2a2935)
from make_world_props import Grid, draw, dummy_frames  # noqa: E402  (palette P: s=#2a2935, S=#5d6072)
from make_obstacles import column  # noqa: E402

UI, LEVEL, TILES, FX = "assets/art/ui", "assets/art/level", "assets/art/tiles", "assets/art/fx"


def strip(images):
    w, h = images[0].size
    out = Image.new("RGBA", (w * len(images), h))
    for i, im in enumerate(images):
        out.paste(im, (i * w, 0))
    return out


def outline_img(img, key="o"):
    """1 px outline (4 neighbours) round every opaque pixel, in UI palette key."""
    out = img.copy()
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and px[nx, ny][3]:
                    out.putpixel((x, y), mt.rgb(key))
                    break
    return out


def grid_map(rows):
    lines = rows.strip("\n").splitlines()
    g = Grid(len(lines[0]), len(lines))
    for y, line in enumerate(lines):
        assert len(line) == g.w, (y, line)
        for x, k in enumerate(line):
            g.set(x, y, k)
    return g


# --- 1. Touch controls ----------------------------------------------------------------

DARKER = {"m": "T", "T": "s", "s": "e", "e": "5", "f": "5", "F": "f", "5": "g", "g": "k", "k": "d"}


def light(nx, ny):
    """How much a surface normal faces the top-left light, -1..1."""
    return (-nx - ny) / math.sqrt(2)


def stone_button(size, pressed):
    depth = 3 if size >= 48 else 2
    rim_w = 4 if size >= 48 else 3
    r = (size - 2 - depth) / 2
    cx = size / 2
    cy_top = 1 + r
    cy = cy_top + (depth - 1 if pressed else 0)
    cv = mt.Canvas(size, size)
    rnd = random.Random(size)
    # dark front side: the disc extruded downwards
    for y in range(size):
        for x in range(size):
            px_, py_ = x + 0.5 - cx, y + 0.5
            for k in range(0, depth + 1):
                if px_ * px_ + (py_ - (cy_top + k)) ** 2 <= r * r:
                    cv.put(x, y, "k" if py_ > cy_top + depth - 0.5 + math.sqrt(max(0, r * r - px_ * px_)) - 1.5 else "g")
                    break
    chips = {rnd.randrange(360) for _ in range(5)}
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            nx, ny = (dx / d, dy / d) if d else (0, 0)
            ang = int(math.degrees(math.atan2(dy, dx))) % 360
            if d > r - rim_w:          # bevelled rim, lit top-left
                s = light(nx, ny)
                k = "m" if s > 0.6 and d > r - 1.5 else "T" if s > 0.25 else "s" if s > -0.35 else "e"
                if any(abs(ang - c) < 4 for c in chips) and d < r - 1:
                    k = "e" if k in ("m", "T") else "5"
            elif d > r - rim_w - 1:    # carved groove between rim and face
                k = "k"
            else:                      # sunken face: shadow under the top-left lip
                s = light(nx, ny)
                k = "5" if d > r - rim_w - 2.5 and s > 0.3 else "F" if d > r - rim_w - 2.5 and s < -0.4 else "f"
            cv.put(x, y, k)
    # a few marks on the face, kept away from the middle where the icon goes
    for i in range(6):
        a = rnd.random() * math.tau
        rr = r - rim_w - 3
        x, y = int(cx + math.cos(a) * rr), int(cy + math.sin(a) * rr)
        if cv.get(x, y)[3]:
            cv.put(x, y, "5")
    img = cv.img
    if pressed:
        px = img.load()
        rev = {mt.rgb(k): mt.rgb(v) for k, v in DARKER.items()}
        for y in range(size):
            for x in range(size):
                if px[x, y] in rev:
                    px[x, y] = rev[px[x, y]]
    # The outline is drawn inside the canvas: every opaque pixel touching the edge or
    # transparency becomes outline.
    out = img.copy()
    p = img.load()
    for y in range(size):
        for x in range(size):
            if not p[x, y][3]:
                continue
            if any(not (0 <= x + dx < size and 0 <= y + dy < size) or not p[x + dx, y + dy][3]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), mt.rgb("o"))
    return out


def cooldown_ring(frac, size=48):
    depth, rim_w = 3, 4
    r = (size - 2 - depth) / 2
    cx, cy = size / 2, 1 + r
    cv = mt.Canvas(size, size)
    lead = frac * 360
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if not (r - rim_w - 0.5 < d <= r - 0.5):
                continue
            ang = math.degrees(math.atan2(dx, -dy)) % 360   # 0 at the top, clockwise
            edge = d <= r - rim_w + 0.5 or d > r - 1.5
            if ang <= lead:
                k = "o" if edge else ("U" if lead - ang < 9 and frac < 1 else "Z" if d > r - 2.6 else "Y")
            else:
                k = "o" if edge else "k"
            cv.put(x, y, k)
    return cv.img


def joystick_base():
    size, r = 96, 47.5
    cx = cy = 48
    cv = mt.Canvas(size, size)
    rim_in = r - 7
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            nx, ny = (dx / d, dy / d) if d else (0, 0)
            s = light(nx, ny)
            ang = math.degrees(math.atan2(dy, dx)) % 360
            if d > r - 1:
                k = "o"
            elif d > rim_in:
                k = "m" if s > 0.6 and d > r - 2 else "T" if s > 0.2 else "s" if s > -0.4 else "e"
                if (ang + 15) % 30 < 1.6:          # joints between the ring blocks
                    k = "5"
                elif d < rim_in + 1.2:
                    k = "e" if s > 0 else "5"
            elif d > rim_in - 1:
                k = "o"
            else:                                   # recess, shadow under the top-left lip
                k = "k" if d > rim_in - 4 and s > 0.25 else "5" if d > rim_in - 3 and s < -0.5 else "g"
                if abs(d - 22) < 0.6:
                    k = "k"
            cv.put(x, y, k)
    # direction notches (purple triangles pointing outwards) inside the rim
    for ux, uy in ((0, -1), (1, 0), (0, 1), (-1, 0)):
        for t in range(4):           # t = distance from the tip
            for w in range(-t, t + 1):
                bx = cx + ux * (rim_in - 3 - t) + (-uy) * w
                by = cy + uy * (rim_in - 3 - t) + ux * w
                cv.put(bx - (1 if ux < 0 else 0) - (0.5 if ux == 0 else 0), by - (1 if uy < 0 else 0) - (0.5 if uy == 0 else 0),
                       "H" if t < 2 else "h")
    for x, y in ((47, 47), (48, 47), (47, 48), (48, 48)):
        cv.put(x, y, "5")
    return cv.img


def joystick_knob():
    size, depth = 40, 3
    r = (size - 2 - depth) / 2
    cx, cy = size / 2, 1 + r
    cv = mt.Canvas(size, size)
    for y in range(size):
        for x in range(size):
            px_, py_ = x + 0.5 - cx, y + 0.5
            for k in range(1, depth + 1):
                if px_ * px_ + (py_ - (cy + k)) ** 2 <= r * r:
                    cv.put(x, y, "g")
                    break
    for y in range(size):
        for x in range(size):
            dx, dy = x + 0.5 - cx, y + 0.5 - cy
            d = math.hypot(dx, dy)
            if d > r:
                continue
            nx, ny = (dx / d, dy / d) if d else (0, 0)
            s = light(nx, ny)
            if d > r - 3:
                k = "m" if s > 0.5 else "T" if s > 0 else "s" if s > -0.5 else "e"
            elif d > r - 4:
                k = "e"
            else:   # gently domed cap
                k = "T" if s * d / r > 0.25 else "s"
                if abs(d - 7) < 0.6:
                    k = "e"
            cv.put(x, y, k)
    rune = ["..H..", ".hUh.", "HUUUH", ".hUh.", "..H.."]
    for j, row in enumerate(rune):
        for i, k in enumerate(row):
            if k != ".":
                cv.put(int(cx) - 2 + i, int(cy) - 2 + j, k)
    return outline_inside(cv.img)


def outline_inside(img):
    out = img.copy()
    p = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            if p[x, y][3] and any(not (0 <= x + dx < w and 0 <= y + dy < h) or not p[x + dx, y + dy][3]
                                  for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), mt.rgb("o"))
    return out


# --- 2. UI panels ---------------------------------------------------------------------

def card_frame():
    cv = mt.Canvas(24, 24)
    n = 24
    for y in range(n):
        for x in range(n):
            d = min(x, y, n - 1 - x, n - 1 - y)
            lit = min(x, y) <= min(n - 1 - x, n - 1 - y)
            # chamfered outer corners
            cd = min(x, n - 1 - x) + min(y, n - 1 - y)
            if cd < 1:
                continue
            if d == 0 or cd == 1:
                k = "o"
            elif d == 1:
                k = "T" if lit else "e"
            elif d == 2:
                k = "s" if lit else "5"
            elif d == 3:
                k = "e" if lit else "5"
            elif d == 4:
                k = "Z" if lit else "Y"
            elif d == 5:
                k = "o"
            else:
                k = "g"
            cv.put(x, y, k)
    # corner studs (inside the 6 px corners only)
    for sx, sy in ((2, 2), (21, 2), (2, 21), (21, 21)):
        cv.put(sx, sy, "Y")
    for sx, sy in ((1, 2), (2, 1)):
        cv.put(sx, sy, "m")
    return cv.img


GLYPHS = {
    "Y": ["#...#", "#...#", ".#.#.", "..#..", "..#..", "..#..", "..#.."],
    "O": [".###.", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "F": ["#####", "#....", "#....", "####.", "#....", "#....", "#...."],
    "E": ["#####", "#....", "#....", "####.", "#....", "#....", "#####"],
    "L": ["#....", "#....", "#....", "#....", "#....", "#....", "#####"],
    "P": ["####.", "#...#", "#...#", "####.", "#....", "#....", "#...."],
    "A": [".###.", "#...#", "#...#", "#####", "#...#", "#...#", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
    "D": ["####.", "#...#", "#...#", "#...#", "#...#", "#...#", "####."],
}


def text_mask(text, unit, gap, space, x0, y0):
    mask, x = set(), x0
    for ch in text:
        if ch == " ":
            x += space
            continue
        for r, row in enumerate(GLYPHS[ch]):
            for c, cell in enumerate(row):
                if cell == "#":
                    for dy in range(unit):
                        for dx in range(unit):
                            mask.add((x + c * unit + dx, y0 + r * unit + dy))
        x += 5 * unit + gap
    return mask


def text_width(text, unit, gap, space):
    words = text.split(" ")
    return sum(len(w) * 5 * unit + (len(w) - 1) * gap for w in words) + space * (len(words) - 1)


def carve(cv, mask, depth, glow, glow2, glow_r, seed, cracks=()):
    """Carved stone letters like the title logo: glow halo, front faces, lit tops."""
    for x, y in list(mask):
        for dx in range(-glow_r, glow_r + 1):
            for dy in range(-glow_r, glow_r + 1 + depth):
                if abs(dx) + abs(dy) <= glow_r and (x + dx, y + dy) not in mask:
                    cur = cv.get(x + dx, y + dy)
                    k = glow2 if abs(dx) + abs(dy) > 1 else glow
                    if cur == mt.rgb(glow) and k == glow2:
                        continue
                    cv.put(x + dx, y + dy, k)
    for x, y in sorted(mask):
        for k in range(1, depth + 1):
            if (x, y + k) not in mask:
                cv.put(x, y + k, "e" if k <= max(1, depth // 2) else "5")
    rnd = random.Random(seed)
    for x, y in mask:
        left, up = (x - 1, y) not in mask, (x, y - 1) not in mask
        right, down = (x + 1, y) not in mask, (x, y + 1) not in mask
        k = "T"
        if up or left:
            k = "m"
        elif right or down:
            k = "s"
        elif rnd.random() < 0.08:
            k = "s"
        cv.put(x, y, k)
    for x, y in cracks:
        if (x, y) in mask:
            cv.put(x, y, "k")


def outline_canvas(img):
    return outline_img(img)


def death_plate():
    unit, gap, space, depth = 3, 3, 9, 3
    text = "YOU FELL"
    w = text_width(text, unit, gap, space)
    x0, y0 = (160 - w) // 2, 4
    mask = text_mask(text, unit, gap, space, x0, y0)
    cv = mt.Canvas(160, 32)
    carve(cv, mask, depth, "R", "r", 3, 7)
    # cracks and a little blood-red seep in the letters
    for x, y in ((x0 + 4, y0 + 2), (x0 + 5, y0 + 3), (x0 + 5, y0 + 4), (x0 + 24, y0 + 13), (x0 + 25, y0 + 14),
                 (x0 + 79, y0 + 4), (x0 + 80, y0 + 5), (x0 + 112, y0 + 16), (x0 + 113, y0 + 17)):
        if (x, y) in mask:
            cv.put(x, y, "k")
    for x, y in ((x0 + 1, y0 + 20), (x0 + 37, y0 + 19), (x0 + 74, y0 + 20), (x0 + 127, y0 + 20)):
        if (x, y) in mask:
            cv.put(x, y, "R")
            cv.put(x, y + 1, "r") if (x, y + 1) in mask else None
    return outline_canvas(cv.img)


def pause_plate():
    w, h = 128, 24
    cv = mt.Canvas(w, h)
    for y in range(h):
        for x in range(w):
            cd = min(x, w - 1 - x) + min(y, h - 1 - y)
            if cd < 2:
                continue
            d = min(x, y, w - 1 - x, h - 1 - y)
            lit = (y <= h - 1 - y and y <= min(x, w - 1 - x)) or (x <= min(y, h - 1 - y))
            if d == 0 or cd == 2:
                k = "o"
            elif d == 1:
                k = "s" if lit else "5"
            elif d == 2:
                k = "e" if lit else "g"
            else:
                k = "g"
            cv.put(x, y, k)
    unit, gap = 2, 3
    text = "PAUSED"
    tw = text_width(text, unit, gap, 0)
    x0, y0 = (w - tw) // 2, 4
    mask = text_mask(text, unit, gap, 0, x0, y0)
    carve(cv, mask, 2, "H", "h", 2, 3)
    # rune studs at both ends
    for bx in (10, w - 15):
        for j, row in enumerate(["..h..", ".hHh.", "hHUHh", ".hHh.", "..h.."]):
            for i, k in enumerate(row):
                if k != ".":
                    cv.put(bx + i, 9 + j, k)
    return cv.img


def death_art():
    w, h = 96, 64
    cv = mt.Canvas(w, h)
    rnd = random.Random(14)
    floor_y = 46
    # back wall: dark bricks
    for y in range(floor_y):
        for x in range(w):
            row = y // 5
            k = "g"
            if y % 5 == 4 or (x + (row % 2) * 6) % 12 == 0:
                k = "k"
            elif rnd.random() < 0.05:
                k = "5"
            cv.put(x, y, k)
    for x in range(w):
        cv.put(x, floor_y - 1, "o")
    # floor
    for y in range(floor_y, h):
        for x in range(w):
            k = "f" if rnd.random() > 0.08 else ("5" if rnd.random() < 0.6 else "F")
            cv.put(x, y, k)
    # portal: frame 0 of portal_loop.png, standing on the floor at the right
    portal = Image.open(f"{LEVEL}/portal_loop.png").convert("RGBA").crop((0, 0, 32, 48))
    px0, py0 = 56, floor_y + 2 - 48 + 1
    # purple light: on the wall round the portal and on the floor in front of it
    pcx = px0 + 16
    for y in range(h):
        for x in range(w):
            if y < floor_y - 1:
                d = math.hypot((x - pcx) / 1.0, (y - (py0 + 26)) / 1.3)
                base = cv.get(x, y)
                if d < 24 and base == mt.rgb("g"):
                    cv.put(x, y, "h" if d < 20 or (x + y) % 2 == 0 else "g")
            elif y >= floor_y:
                d = math.hypot((x - pcx) / 1.6, (y - floor_y) / 0.9)
                if d < 14:
                    cv.put(x, y, "H" if d < 6 and (x + y) % 2 == 0 else "h")
                elif d < 20 and (x + y) % 2 == 0:
                    cv.put(x, y, "h")
    cv.img.alpha_composite(portal, (px0, py0))
    # rubble
    for x, y, k in ((10, 58, "e"), (11, 58, "s"), (10, 59, "5"), (11, 59, "e"), (12, 59, "5"),
                    (84, 60, "e"), (85, 60, "5"), (50, 61, "e"), (51, 61, "5"), (22, 52, "5")):
        cv.put(x, y, k)
    # the sword stuck in the floor, tilted a little, shadow to the right
    sx, tip_y = 30, 55
    for y in range(tip_y - 1, tip_y + 2):
        for x in range(sx - 3, sx + 9):
            if cv.get(x, y)[3] and ((x - sx - 2) / 6) ** 2 + ((y - tip_y) / 1.4) ** 2 <= 1:
                cv.put(x, y, "d")
    for x, y in ((sx - 2, tip_y), (sx - 3, tip_y + 1), (sx + 2, tip_y + 1), (sx + 3, tip_y + 2), (sx - 1, tip_y + 1)):
        cv.put(x, y, "o")     # cracks in the floor round the blade
    blade_top = 30
    for y in range(blade_top, tip_y + 1):
        x = sx
        cv.put(x - 2, y, "o")
        cv.put(x - 1, y, "W")
        cv.put(x, y, "m")
        cv.put(x + 1, y, "T")
        cv.put(x + 2, y, "o")
        if y % 6 == 0:
            cv.put(x - 1, y, "U")
    gx = sx
    guard = ["ooooooooooo", "oyYYYYYYYyo", "ooooooooooo"]
    for j, row in enumerate(guard):
        for i, k in enumerate(row):
            cv.put(gx - 5 + i, blade_top - 3 + j, k)
    grip = ["obbo", "oBbo", "obbo", "oBbo", "obbo"]
    for j, row in enumerate(grip):
        for i, k in enumerate(row):
            cv.put(gx - 2 + i, blade_top - 8 + j, k)
    for j, row in enumerate([".ooo.", "oYZYo", "oyYyo", ".ooo."]):
        for i, k in enumerate(row):
            if k != ".":
                cv.put(gx - 2 + i, blade_top - 12 + j, k)
    # the red scarf knotted under the guard, its tail blown towards the portal
    scarf = [
        "ooo...............",
        "oqqoooo...........",
        "orqqqqRoo......oo.",
        ".orRqqqqRo...ooqqo",
        "..ooRRqqqRoooqqRo.",
        "....ooRRqqqqqRRo..",
        "......oorRRRRoo...",
        "........ooooo.....",
    ]
    for j, row in enumerate(scarf):
        for i, k in enumerate(row):
            if k != ".":
                cv.put(gx + 1 + i, blade_top - 1 + j, k)
    # vignette in the corners and a 1 px frame
    for y in range(h):
        for x in range(w):
            d = math.hypot((x - w / 2) / (w / 2), (y - h / 2) / (h / 2))
            if d > 1.18 or (d > 1.05 and (x + y) % 2 == 0):
                cv.put(x, y, "d")
            if x in (0, w - 1) or y in (0, h - 1):
                cv.put(x, y, "o")
    return cv.img


# --- 3. Floor styles ------------------------------------------------------------------

def put(rows, x, y, k):
    r = list(rows[y])
    r[x] = k
    rows[y] = "".join(r)


def coral_column():
    rows = column()
    # wet stone: the lit shaft darkens in streaks, moss becomes weed, barnacles,
    # coral growing on the capital and up from the base, water round the plinth
    rows = [r.replace("N", "a").replace("n", "N") for r in rows]
    for y in range(7, 24):
        if y % 5 in (1, 2):
            put(rows, 5, y, "S")
    for x, y in ((10, 9), (11, 10), (10, 13), (5, 18), (6, 19), (11, 20)):
        put(rows, x, y, "W")
    for x, y in ((11, 9), (10, 14), (6, 18)):
        put(rows, x, y, "m")
    coral = [  # x, y, key: a branching red coral on the capital's right
        (11, 0, "o"), (13, 0, "o"), (10, 1, "o"), (11, 1, "q"), (12, 1, "o"), (13, 1, "q"), (14, 1, "o"),
        (11, 2, "R"), (12, 2, "q"), (13, 2, "R"),
        (2, 1, "o"), (3, 1, "o"), (2, 2, "a"), (3, 2, "A"), (1, 2, "o"), (4, 2, "o"),
    ]
    for x, y, k in coral:
        put(rows, x, y, k)
    for x, y, k in ((3, 22, "o"), (3, 23, "a"), (3, 24, "a"), (2, 23, "o"), (2, 24, "o"),
                    (12, 23, "q"), (12, 22, "R"), (13, 22, "o"), (12, 21, "o"), (13, 23, "o")):
        put(rows, x, y, k)
    # water round the base instead of the dry shadow
    rows[31] = "..jjlljjjjjjjll."
    rows[30] = rows[30][:1] + "j" + rows[30][2:15] + "j"
    return draw("\n".join(rows), 16, 32)


BARREL = """
................
.....oooooo.....
...ooBccccBoo...
..oBbbbbbbbbBo..
..oSmmmmmmmmeo..
.oBcBBcBBBbbbbo.
.oBcBBcBBBbbbbo.
.oSWmmmmmmeeeso.
.oBcWWcBBBbbbbo.
.oBcBWcBBBbbbbo.
.oBcBBcBBBbbbbo.
..oSmmmmmmmeso..
..oNcBBcBBNbNo..
.loNnBBcBnNnnol.
.jlooooooooooojl
..jjjjljjjjjjj..
"""


def boat():
    """A wrecked boat hull, bow to the left, its stern broken off on the right: planks
    end at ragged lengths with two bare ribs sticking out past them, a hole in the near
    side, barnacles, weed at the waterline and a puddle round it."""
    rnd = random.Random(23)
    g = Grid(32, 16)

    def taper(x):
        return max(0, (8 - x)) // 2

    ends = {}
    for y in range(2, 14):
        ends[y] = 21 + rnd.randrange(0, 8)
    ends[9] = 27
    for x in range(1, 30):
        t = taper(x)
        top, gun, bot = 3 + t, 9, 12 - t // 2
        for y in range(top, bot + 1):
            if x > ends.get(y, 29):
                continue
            if y == top:
                k = "c"                            # far gunwale, lit
            elif y < gun:
                k = "B" if (x - 1) % 5 == 0 and y > top else "b"   # ribs across the floor
            elif y == gun:
                k = "c"                            # near gunwale
            else:
                k = "B" if (y + x // 7) % 2 == 0 else "b"           # side planks
            g.set(x, y, k)
    # bare ribs past the broken end
    for rx in (26, 29):
        for y in range(4, 10):
            if g.get(rx, y) == ".":
                g.set(rx, y, "c" if y < 6 else "B")
    # hole in the near side, barnacles, weed
    for x, y, k in ((14, 10, "d"), (15, 10, "d"), (15, 11, "d"), (16, 10, "o"), (13, 11, "o"),
                    (9, 10, "W"), (10, 11, "W"), (20, 11, "W"), (6, 6, "d"),
                    (3, 11, "N"), (4, 12, "n"), (22, 12, "N"), (23, 11, "n")):
        g.set(x, y, k)
    g.outline()
    for x in range(3, 28):                 # water round the hull
        if g.get(x, 14) == ".":
            g.set(x, 14, "j" if x % 6 else "l")
    for x in (2, 4, 25, 27):
        if g.get(x, 13) == ".":
            g.set(x, 13, "l")
    return g.image()


BASALT = """
................
....oooo........
...oTTTTo.......
..oTTTTSSo......
..oTSSSSeo......
..oSSeeeso......
..oSSeeeso......
..oSSeqeso......
..oSSeqYso......
..oSSqeeso......
..oSSeeeso......
..oSSeeeso......
..oSSeeeso......
..oSSeeesooo....
..oSSeeeoTTTo...
..oSSeeoTTTTSo..
..oSSeeoTSSSeo..
..oSSeeoSSeeso..
..oSSeeoSSeeso..
..oSSeeoSSeeso..
..oSSeeoSSqeso..
..oSSeeoSSqYso..
..oSSeeoSSeqso..
..oSSeeoSSeeso..
..oSSeeoSSeeso..
..oSSeeoSSeeso..
..oSSeeoSSeeso..
..oSSeeoSSeeso..
.oooooqoSSeeso..
oTSoqYqqooooooo.
oSeeooqYqo.oTSeo
.ddddddddddddddd
"""


def basalt_column():
    return draw(BASALT, 16, 32)


def lava_rock():
    g = Grid(16, 16)
    for y in range(16):
        for x in range(16):
            if ((x + 0.5 - 8.8) / 7.4) ** 2 + ((y + 0.5 - 14.0) / 2.0) ** 2 <= 1:
                g.set(x, y, "d")
    blobs = [(6.0, 7.0, 5.0, 4.6), (11.0, 9.5, 4.0, 3.6), (7.5, 11.5, 5.0, 2.8)]
    owner = {}
    for i, (cx, cy, rx, ry) in enumerate(blobs):
        for y in range(16):
            for x in range(16):
                v = ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2
                if v <= 1:
                    owner[(x, y)] = (i, cx, cy, rx, ry)
    for (x, y) in owner:
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            if (x + dx, y + dy) not in owner:
                g.set(x + dx, y + dy, "o")
    for (x, y), (i, cx, cy, rx, ry) in owner.items():
        s = (x + 0.5 - cx) / rx + (y + 0.5 - cy) / ry
        g.set(x, y, "S" if s < -0.7 else "e" if s < 0.0 else "F" if s < 0.8 else "s")
    # glowing seams where the blobs meet, and a few cracks with a hot core
    for (x, y), own in owner.items():
        for dx, dy in ((1, 0), (0, 1)):
            o2 = owner.get((x + dx, y + dy))
            if o2 and o2[0] != own[0]:
                g.set(x, y, "q")
    for x, y, k in ((4, 6, "q"), (5, 7, "Y"), (6, 8, "q"), (6, 9, "q"), (10, 8, "q"), (11, 9, "Y"),
                    (12, 10, "q"), (8, 12, "Y"), (9, 12, "q"), (3, 4, "T"), (4, 3, "T"), (5, 3, "S")):
        if g.get(x, y) not in (".", "o", "d"):
            g.set(x, y, k)
    return g.image()


BRAZIER = """
................
................
.......q........
.......qq...q...
......qYq..qq...
...q..qYYq.qYq..
..qq.qYZYqqYq...
..qYqqYZZYqYq...
..qYYqYZUZYYq...
.ooqYYZZUZZYqoo.
oTmmmmmmmmmmmmeo
oSqYZYqYYqZYqqso
.oSeeeeeeeeeeso.
..ooSeeeeeesoo..
....oTSeeeso....
....oSeeeeso....
...ooSSeeesoo...
..oTTSSeeessso..
.ffoSSeeeeeesof.
.fsooooooooooosf
..fs5555555555f.
...ddddddddddd..
................
................
"""


def brazier():
    rows = BRAZIER.strip("\n").splitlines()
    # floor plates broken round the sunken foot: key "5" is the floor seam here
    rows = [r.replace("5", "s") for r in rows]
    # drop the empty bottom rows: the picture's bottom row is the cell's bottom row
    rows = ["." * 16, "." * 16] + rows[:-2]
    return draw("\n".join(rows), 16, 24)


def blank_detail():
    return [["."] * 16 for _ in range(16)]


def detail_from(rows):
    lines = rows.strip("\n").splitlines()
    assert len(lines) == 16 and all(len(line) == 16 for line in lines)
    assert all(set(line) == {"."} for line in lines[:6] + lines[15:])
    return draw(rows, 16, 16)


F_DRIP = """
................
................
................
................
................
................
.......jj.......
.......jl.......
.......jl.......
........l.......
........j.......
........l.......
................
........L.......
........l.......
................
"""

F_WEED = """
................
................
................
................
................
................
.oNNNooNNNNoNNo.
.NnNnnNNnNNnNnN.
..N.nN.Nn.n.Nn..
..n.N..N..N.n...
..N.n..n..N.N...
.oa..N.N..n.a...
..n..n.a..N.....
.....N.......n..
.....a..........
................
"""

F_BARNACLES = """
................
................
................
................
................
................
................
....oo.....oo...
...oWmo...oWmo..
...oUWeo..oWeo..
....omo.oo.oo...
.oo..o.oWmo..oo.
oWmo..oUWmeooWmo
oWeo...oWeo.oWeo
.oo.....oo...oo.
................
"""

F_GRATE = """
................
................
................
................
................
................
..oooooooooooo..
..oyBcBBcBBcyo..
..oBjoBljoBjBo..
..ocljocjlocjo..
..oBjloBljoBlo..
..oyccyccycccyo.
..oBjloBjloBjBo.
..ocjjoclloBjjo.
..oyBByBBByBByo.
................
"""

F_SHELL = """
................
................
................
................
................
................
.....a....a.....
......ooooo.....
...a.oUWUWUo.a..
....oUWUWUWUo...
....oWmWmWmWo...
.a..oWmWmWmWo..a
.....oWmWmWo....
......omWmo.....
.....a.ooo..a...
................
"""

E_CRACK = """
................
................
................
................
................
................
.........o......
........qo......
........Y.......
.......qY.......
......qYZ.......
......Y..qY.....
.....qY...q.....
.....Y.....q....
....qo..........
................
"""

E_CHAIN = """
................
................
................
................
................
................
......oRRo......
.......Yo.......
.......YRo......
......Y..qo.....
......q..qo.....
.......qqo......
.......Zo.......
......oZqo......
.......YYo......
................
"""

E_SOOT = """
................
................
................
................
................
................
..o..o.oo.o..o..
...oo.ooooo.o...
..o.ooookooo.o..
...ooookkkooo...
....ookkdkkoo...
.....okdddko....
......kdddk.....
.......ddd......
.......kdk......
................
"""

E_LAVA = """
................
................
................
................
................
................
......oooo......
.....oqYYqo.....
......oqYo......
.......qY.......
.......qY.......
.......qo.......
................
.......Y........
......qZq.......
................
"""

E_BANNER = """
................
................
................
................
................
................
...yBBBBBBBBBy..
....okkkkkkso...
....okssskkso...
....oksqsskso...
....okkqkkkso...
....okkkkqso....
....oqko.okq....
.....q....o.....
................
................
"""


def wall_details(slots):
    img = Image.new("RGBA", (80, 16))
    for i, rows in enumerate(slots):
        img.paste(detail_from(rows), (16 * i, 0))
    return img


LANTERN = """
.ommmmo.........
..oeeoo.........
...oo.oo........
.......mo.......
.......m........
......ooo.......
.....oeSeo......
....oeooooe.....
....o#####o.....
....oe###eo.....
....o#####o.....
....oe###eo.....
.....oooooo.....
......oeeo......
.......oo.......
................
"""
LANTERN_LIGHT = [  # (inner fill rows 8-11) per frame: core, ring
    ("U", "A"), ("A", "a"), ("U", "A"), ("A", "A"),
]
LANTERN_HALO = [
    [(3, 9, "a"), (11, 10, "a")],
    [(3, 10, "a")],
    [(3, 8, "a"), (11, 9, "a"), (7, 14, "a")],
    [(11, 11, "a")],
]


def lantern_frames():
    out = []
    base = LANTERN.strip("\n").splitlines()
    for f in range(4):
        core, ring = LANTERN_LIGHT[f]
        rows = [list(r) for r in base]
        for y in range(16):
            for x in range(16):
                if rows[y][x] == "#":
                    centre = 6 <= x <= 8 and 9 <= y <= 10
                    rows[y][x] = core if centre else ring
        for x, y, k in LANTERN_HALO[f]:
            if rows[y][x] == ".":
                rows[y][x] = k
        out.append(draw("\n".join("".join(r) for r in rows), 16, 16))
    return strip(out)


BRAZIER_WALL = """
................
................
................
................
................
................
................
................
................
................
.oooooooooooooo.
oTmmmmmmmmmmmmeo
.oSeeeeeeeeeeso.
..ooSeeeeeesoo..
....oooeeooo....
......oeso......
"""
FLAMES = [
    """
........q.......
.......qq...q...
...q...qYq..qq..
..qq..qYYq.qYq..
..qYq.qYZYqqYq..
..qYYqYZZYqYYq..
.qYZYqYZUZYZYq..
.qYZZYZUUZZZYq..
.qYZUZZUUUZUZYq.
.qqYYYYYYYYYYqq.
""",
    """
.......q........
.......qq.......
..q...qYq...q...
..qq..qYYq..qq..
..qYq.qYZYq.qYq.
.qYYq.qYZYq.qYq.
.qYZYqYZUZqYZYq.
.qYZZYZUUZYZZYq.
.qYZUZZUUUZUZYq.
.qqYYYYYYYYYYqq.
""",
    """
................
.........q......
...q....qq......
..qq...qYq..q...
..qYq..qYYq.qq..
..qYYqqYZYqqYq..
.qYZYqYZUZYZYq..
.qYZZYZUUZZZYq..
.qYZUZZUUUZUZYq.
.qqYYYYYYYYYYqq.
""",
    """
......q.........
......qq.....q..
...q..qYq...qq..
..qq..qYYq..qYq.
.qYq.qYZYq..qYq.
.qYYqqYZZYqqYYq.
.qYZYqYZUZYZYq..
.qYZZYZUUZZZYq..
.qYZUZZUUUZUZYq.
.qqYYYYYYYYYYqq.
""",
]


def fire_brazier_frames():
    out = []
    base = BRAZIER_WALL.strip("\n").splitlines()
    for fl in FLAMES:
        top = fl.strip("\n").splitlines()
        rows = [list(r) for r in base]
        for y, line in enumerate(top):
            for x, k in enumerate(line):
                if k != "." and (y < 10 and rows[y][x] == "."):
                    rows[y][x] = k
        # glowing coals in the bowl's rim
        for x in (3, 6, 9, 12):
            rows[10][x] = "q"
        out.append(draw("\n".join("".join(r) for r in rows), 16, 16))
    return strip(out)


def seal(kind):
    """Rubble filling a door cell (like door_seal.png) in the flooded or fire look."""
    rocks = [(4.0, 4.0, 4.2, 3.6), (11.5, 3.5, 4.0, 3.4), (8.0, 8.5, 4.6, 3.8),
             (2.5, 11.5, 3.2, 3.0), (13.0, 11.0, 3.4, 3.4), (7.5, 13.5, 3.0, 2.2)]
    g = Grid(16, 16)
    g.rect(0, 0, 15, 15, "f" if kind == "flooded" else "s")
    owner = {}
    for i, (cx, cy, rx, ry) in enumerate(rocks):
        for y in range(16):
            for x in range(16):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    owner[(x, y)] = (i, dx + dy)
    for (x, y), (i, s) in owner.items():
        if kind == "flooded":
            k = "T" if s < -0.55 else "s" if s > 0.5 else "S"
            if s > 0.5:
                k = "e"
        else:
            k = "S" if s < -0.55 else "s" if s > 0.5 else "e"
        g.set(x, y, k)
    gaps = [(x, y) for y in range(16) for x in range(16) if (x, y) not in owner]
    for x, y in gaps:
        if any((x + dx, y + dy) in owner for dx, dy in ((1, 0), (0, 1), (-1, 0), (0, -1))):
            g.set(x, y, "k")
    if kind == "flooded":
        # water pooled in the gaps, weed on the rocks, wet shine
        for x, y in gaps:
            if g.get(x, y) == "f":
                g.set(x, y, "j")
        for x, y, k in ((1, 7, "l"), (15, 7, "l"), (10, 15, "l"), (0, 15, "j"), (5, 9, "N"), (6, 10, "n"),
                        (11, 6, "N"), (12, 6, "n"), (3, 13, "N"), (2, 2, "L"), (10, 1, "L"), (6, 6, "L")):
            g.set(x, y, k)
    else:
        # lava glowing in the gaps between the basalt blocks
        for x, y in gaps:
            if g.get(x, y) == "k" and (x * 3 + y) % 4 != 0:
                g.set(x, y, "r")
        for x, y, k in ((7, 5, "q"), (6, 4, "q"), (12, 8, "q"), (11, 8, "Y"), (4, 9, "q"), (9, 12, "q"),
                        (10, 13, "Y"), (13, 15, "q"), (1, 8, "r"), (14, 1, "r")):
            g.set(x, y, k)
    return g.image()


# --- 4. Grip seaweed ------------------------------------------------------------------

def grip_frames():
    out = []
    for f in range(4):
        g = Grid(16, 8)
        ph = f * math.pi / 2
        # strands rising from the floor round the legs, tips curling towards the middle
        for sx, top, off in ((2, 1, 0.0), (5, 0, 1.3), (11, 0, 2.6), (14, 1, 3.9)):
            for y in range(7, top - 1, -1):
                sway = 0.8 * math.sin(ph + off + y * 0.8) * (7 - y) / 7
                inward = (1 if sx < 8 else -1) * (2 if y == top else 1 if y == top + 1 else 0)
                x = int(round(sx + sway + inward))
                g.set(x, y, "N" if (y + f) % 3 else "n")
            tip_x = int(round(sx + (1 if sx < 8 else -1) * 2 + 0.8 * math.sin(ph + off + top * 0.8) * (7 - top) / 7))
            g.set(tip_x, top, "a" if (f + int(off)) % 2 == 0 else "N")
        # a loop wrapped round the shins (front half), bobbing
        for i in range(20):
            a = math.pi * i / 19
            x = 8 + 5.2 * math.cos(a)
            y = 3.6 + 1.3 * math.sin(a) + (0.5 if f in (1, 2) else 0)
            g.set(int(round(x - 0.5)), int(round(y)), "N" if i % 4 else "n")
        # drops falling off the weed
        for dx, start in ((4, 0), (12, 2)):
            y = 3 + (f + start) % 5
            if y < 8:
                g.set(dx, y, "l" if y < 7 else "L")
        g.outline()
        out.append(g.image())
    return strip(out)


# --- 5. Status icons ------------------------------------------------------------------

ICON_SLOWED = """
...oooo.....
...oBco..o..
..ooNBo.oNo.
.oNNNNo.oNo.
..ooBNNooNo.
...oBBNNNo..
.ooocBBNNo..
oNNNNBBBBooo
.ooNBBBBBBBo
..oNbbbbbbbo
.oNNooooooo.
.oo.........
"""

ICON_KEY = """
............
..oooo......
.oHUHHo.....
oHhooHho....
oHo..oHo....
oHho.hHo....
.oHhhHoooo..
..ooHHHHHHo.
....ooHoHho.
.....oHooHo.
......o..o..
............
"""

ICON_CHARM = """
....o..o....
....oyyo....
.....oo.....
...oooooo...
..oYZZZYYo..
.oYZNVNNYyo.
.oZNVNNNNyo.
.oYNNnNNNyo.
.oYYNNnNyyo.
..oyYYyyyo..
...oooooo...
............
"""

ICON_CRIT = """
.........oo.
........oUo.
.......oUmo.
..Z...oUmo..
.ZUZ.oUmo...
..Z.oUmo....
.oo.omo.....
.oyoYo......
..oYyo....Z.
.oYoyo...ZUZ
oyo..o....Z.
.o..........
"""


def status_icons():
    # V = grass highlight (nature theme) is not in the main palette: use teal A for the
    # clover's light leaves instead
    icons = [ICON_SLOWED, ICON_KEY, ICON_CHARM.replace("V", "a"), ICON_CRIT]
    img = Image.new("RGBA", (48, 12))
    for i, rows in enumerate(icons):
        img.paste(draw(rows, 12, 12), (12 * i, 0))
    return img


def main():
    strip([stone_button(48, False), stone_button(48, True)]).save(f"{UI}/touch_button.png")
    strip([stone_button(32, False), stone_button(32, True)]).save(f"{UI}/touch_button_small.png")
    strip([cooldown_ring((i + 1) / 8) for i in range(8)]).save(f"{UI}/touch_cooldown.png")
    joystick_base().save(f"{UI}/touch_joystick_base.png")
    joystick_knob().save(f"{UI}/touch_joystick_knob.png")
    card_frame().save(f"{UI}/card_frame.png")
    death_plate().save(f"{UI}/death_plate.png")
    death_art().save(f"{UI}/death_art.png")
    pause_plate().save(f"{UI}/pause_plate.png")

    coral_column().save(f"{LEVEL}/flooded_obstacle_coral_column.png")
    draw(BARREL, 16, 16).save(f"{LEVEL}/flooded_obstacle_barrel.png")
    boat().save(f"{LEVEL}/flooded_obstacle_boat.png")
    basalt_column().save(f"{LEVEL}/fire_obstacle_basalt_column.png")
    lava_rock().save(f"{LEVEL}/fire_obstacle_lava_rock.png")
    brazier().save(f"{LEVEL}/fire_obstacle_brazier.png")
    wall_details([F_DRIP, F_WEED, F_BARNACLES, F_GRATE, F_SHELL]).save(f"{TILES}/flooded_wall_details.png")
    wall_details([E_CRACK, E_CHAIN, E_SOOT, E_LAVA, E_BANNER]).save(f"{TILES}/fire_wall_details.png")
    lantern_frames().save(f"{LEVEL}/flooded_lantern.png")
    fire_brazier_frames().save(f"{LEVEL}/fire_brazier.png")
    seal("flooded").save(f"{TILES}/flooded_door_seal.png")
    seal("fire").save(f"{TILES}/fire_door_seal.png")

    grip_frames().save(f"{FX}/grip_seaweed.png")
    status_icons().save(f"{UI}/status_icons.png")
    dummy_frames().save("assets/art/enemies/training_dummy.png")
    print("batch 14 art written")


if __name__ == "__main__":
    main()
