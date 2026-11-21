"""Menu background (batch 13, part 6, second take after the author's review), 640x360,
32-colour palette plus the camp's nature colours (make_title.C). Layers, back to front:
- dusk sky: banded gradient with stepped dither rows between bands, faint rays from a
  striped retro sun setting on the horizon, clouds lit from below, stars and a moon;
- far mountains with a stepped temple, ruined towers and an aqueduct, their sun-facing
  edges rimmed with sunset light, a mist band in the valley;
- the ruins gate on the right: a ruined wall with ivy that crumbles away right of the
  gate (the sunset shows behind it), pilasters with burning torches, an arch whose
  wedge stones carry purple runes (like the logo), and inside a tunnel going down:
  receding inner arches and steps into darkness towards a faint purple doorway far
  below; a light purple glow: the arch's inner rim lit, the runes bright, a thin mist
  over the threshold and a few sparks;
- the camp on the left: an A-frame canvas tent in perspective (front flaps tied back,
  side roof, ridge pole, guy ropes and pegs), a backpack, log seats, the fire pit with
  stones and logs and its warm light on the grass;
- a cobbled path to the gate, grass with tufts and flowers, dark foreground bushes and
  grass at the bottom, a vignette.
The campfire's flames are the overlay assets/art/ui/menu_fire.png (3 frames of 32x32,
loop 8 fps), drawn with its top-left at FIRE_POS. Torch flames are static.
Run from the project root: python tools/art/make_title.py (it calls this).
"""
import math
import random

from PIL import Image

from make_title import C, Canvas, rgb

W_, H_ = 640, 360
HORIZON = 232
GROUND = 252
FIRE = (196, 312)                       # the fire's base
FIRE_POS = (FIRE[0] - 16, FIRE[1] - 28)  # top-left of the 32x32 flame overlay
SUN = (250, HORIZON + 4, 30)
ARCH_CX, ARCH_SPRING, ARCH_R, ARCH_T = 478, 186, 46, 17
ARCH_FLOOR = 300
TORCHES = []                            # filled by gate(), drawn after the purple glow
DOOR = (ARCH_CX, 250)                   # the far doorway: the source of the purple light
TUNNEL = (0.86, 0.72, 0.58, 0.44, 0.32)  # sizes of the receding inner arches

PAL = {k: rgb(k)[:3] for k in C}


def nearest(c):
    return min(PAL, key=lambda k: sum((a - b) ** 2 for a, b in zip(PAL[k], c)))


DARKER = {k: nearest(tuple(int(v * 0.72) for v in PAL[k])) for k in PAL}
DARKER = {k: (v if v != k else "o") for k, v in DARKER.items()}
KEY_OF = {v: k for k, v in PAL.items()}


def key_at(cv, x, y):
    p = cv.get(x, y)
    return KEY_OF.get(p[:3]) if p[3] else None


def darken(cv, x, y, steps=1):
    k = key_at(cv, x, y)
    if k is None:
        return
    for _ in range(steps):
        k = DARKER[k]
    cv.put(x, y, k)


# --- sky -------------------------------------------------------------------------------

BANDS = [(0, "d"), (34, "k"), (70, "g"), (104, "5"), (132, "h"), (160, "r"), (186, "R"), (206, "q"), (222, "Y")]


def band_at(y, x):
    """The band colour at (x, y), with a 2-row checker dither where two bands meet."""
    k = BANDS[0][1]
    for i, (start, c) in enumerate(BANDS):
        if y >= start:
            k = c
            if 0 < i and y - start < 2 and (x + y) % 2 == 0:
                k = BANDS[i - 1][1]
    return k


def sky(cv):
    sx, sy, sr = SUN
    for y in range(0, GROUND + 4):
        for x in range(W_):
            k = band_at(y, x)
            # rays: every other wedge around the sun one band warmer, only in the warm
            # bands near the sun, thinning out (checker) towards their ends
            ang = math.atan2(y - sy, x - sx)
            d = math.hypot(x - sx, (y - sy) * 1.6)
            if k in ("h", "r", "R") and 36 < d < 240 and int((ang + math.pi) / (math.pi / 16)) % 2 == 0:
                if d < 150 or (x + y) % 2 == 0:
                    k = {"h": "r", "r": "R", "R": "q"}[k]
            cv.put(x, y, k)
    # the sun: discs with retro stripes cut through its lower half
    for y in range(sy - sr, HORIZON - 6):
        for x in range(sx - sr, sx + sr + 1):
            d = math.hypot(x - sx, y - sy)
            if d <= sr:
                stripe = y > sy - sr * 0.45 and (sy - y) % 6 in (0, 1) if y > sy - sr * 0.8 else False
                if stripe:
                    continue
                cv.put(x, y, "U" if d < sr * 0.45 else ("Z" if d < sr * 0.8 else "Y"))
    # glow ring around the sun
    for y in range(sy - sr - 8, sy + 1):
        for x in range(sx - sr - 10, sx + sr + 11):
            d = math.hypot(x - sx, y - sy)
            if sr < d <= sr + 6 and (x + y) % 2 == 0 and key_at(cv, x, y) in ("q", "R", "r"):
                cv.put(x, y, "Y" if d < sr + 3 else "q")
    # clouds: stacked rounded bars (pixel-art style), lit from below by the sun
    rnd = random.Random(21)
    clouds = [(70, 156, 1.0), (330, 140, 1.2), (180, 192, 0.8), (40, 206, 0.7), (300, 214, 0.6)]
    for cx, cy, size in clouds:
        bars = [(-30, 0, 46), (-10, -4, 40), (8, -8, 22), (-48, 4, 30), (12, 4, 44)]
        warm = cy > 180
        for bx, by, w in bars:
            w = int(w * size)
            x0, y0 = int(cx + bx * size), cy + by
            for y in range(y0, y0 + 4):
                inset = (2, 0, 0, 1)[y - y0]
                for x in range(x0 + inset, x0 + w - inset):
                    if y == y0 + 3:
                        k = "Z" if warm else "q"          # the lit underside
                    elif y == y0:
                        k = "r" if not warm else "R"
                    else:
                        k = "R" if not warm else "q"
                    cv.put(x, y, k)
    # stars only in the dark upper sky, a few with sparkle crosses
    for _ in range(170):
        x, y = rnd.randrange(W_), rnd.randrange(0, 110)
        if key_at(cv, x, y) in ("d", "k", "g"):
            cv.put(x, y, rnd.choice("UWLm" if y < 70 else "mT"))
    for _ in range(8):
        x, y = rnd.randrange(20, W_ - 20), rnd.randrange(4, 70)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1), (2, 0), (-2, 0), (0, 2), (0, -2)):
            cv.put(x + dx, y + dy, "U" if (dx, dy) == (0, 0) else ("L" if abs(dx) + abs(dy) == 1 else "j"))
    # moon with a soft halo
    mx, my = 86, 50
    for y in range(my - 16, my + 17):
        for x in range(mx - 16, mx + 17):
            d1 = math.hypot(x - mx, y - my)
            d2 = math.hypot(x - mx - 5, y - my + 3)
            if d1 <= 10 and d2 > 9:
                cv.put(x, y, "U" if x < mx - 4 else "W")
            elif 11 <= d1 <= 14 and (x + y) % 2 == 0 and key_at(cv, x, y) in ("d", "k"):
                cv.put(x, y, "g")


# --- far layers -----------------------------------------------------------------------

def silhouette(cv, top_fn, x0, x1, bottom, key, rim=None):
    sx = SUN[0]
    for x in range(x0, x1):
        top = top_fn(x)
        if top is None:
            continue
        for y in range(int(top), bottom):
            cv.put(x, y, key)
        if rim:
            # the edge facing the sun catches its light
            facing = (x < sx and top_fn(x + 1) is not None and top_fn(x + 1) > top) or (x > sx and top_fn(x - 1) is not None and top_fn(x - 1) > top)
            cv.put(x, int(top), rim)
            if facing:
                cv.put(x, int(top) + 1, rim)


def far_layers(cv):
    # far mountains with a stepped temple
    def mountains(x):
        return HORIZON - 18 - 14 * math.sin(x / 61.0 + 1) - 8 * math.sin(x / 23.0)
    silhouette(cv, mountains, 0, W_, HORIZON + 10, "h", "R")
    for i, (w, h) in enumerate(((70, 6), (54, 6), (38, 6), (22, 6), (10, 7))):
        y0 = HORIZON - 34 - i * 6
        for y in range(y0, y0 + h):
            for x in range(132 - w // 2, 132 + w // 2):
                cv.put(x, y, "h")
        for x in range(132 - w // 2, 132 + w // 2):
            cv.put(x, y0, "R" if x > 132 else "q")
    # mist in front of the mountains
    for x in range(W_):
        top = HORIZON - 6 + 3 * math.sin(x / 19.0)
        for y in range(int(top), HORIZON + 10):
            if (x + y) % 2 == 0 or y > top + 3:
                cv.put(x, y, "5")
    # mid ruins: towers and the aqueduct, rimmed with sunset light on the sun side
    rnd = random.Random(2)
    towers = [(28, 150, 22), (98, 178, 14), (318, 166, 22), (360, 190, 12)]
    for tx, top, w in towers:
        tops = {x: top + rnd.choice((0, 0, 1, 3, 5)) for x in range(tx - w // 2, tx + w // 2)}
        silhouette(cv, lambda x, t=tops: t.get(x), tx - w // 2, tx + w // 2, HORIZON + 16, "g")
        side = tx + w // 2 - 1 if tx < SUN[0] else tx - w // 2
        side = tx - w // 2 if tx > SUN[0] else tx + w // 2 - 1
        for y in range(top + 2, HORIZON + 8):
            cv.put(side, y, "r" if (y // 3) % 2 else "R")
        for wy in range(top + 9, HORIZON - 4, 13):
            for y in range(wy, wy + 5):
                for x in range(tx - 1, tx + 2):
                    cv.put(x, y, "q" if y > wy + 1 else "d")     # sunset seen through the window
    for x in range(150, 300):
        for y in (194, 195, 196):
            cv.put(x, y, "g")
        cv.put(x, 193, "R")
    for ax in range(152, 300, 24):
        for y in range(197, HORIZON + 12):
            for x in range(ax, ax + 4):
                cv.put(x, y, "g")
        cv.put(ax, 197, "R")
    for ax in range(156, 296, 24):
        for y in range(197, 206):
            for x in range(ax, ax + 20):
                if math.hypot(x - ax - 10, (y - 206) * 1.3) < 10 and key_at(cv, x, y) == "g":
                    cv.put(x, y, band_at(y, x))
    # near hills: the dark ground line
    for x in range(W_):
        top = HORIZON + 6 + 4 * math.sin(x / 31.0) + 2 * math.sin(x / 9.0)
        for y in range(int(top), GROUND + 4):
            cv.put(x, y, "k")


# --- ground ----------------------------------------------------------------------------

def ground(cv):
    rnd = random.Random(3)
    for y in range(GROUND, H_):
        t = (y - GROUND) / (H_ - GROUND)
        for x in range(W_):
            k = "n" if t < 0.15 else "N"
            r = rnd.random()
            if r < 0.06:
                k = "G" if t > 0.1 else "N"
            elif r < 0.09:
                k = "n"
            cv.put(x, y, k)
    # tufts and flowers, more and bigger towards the viewer
    for _ in range(420):
        x, y = rnd.randrange(W_), rnd.randrange(GROUND + 4, H_)
        h = 1 + int((y - GROUND) / 40)
        for k in range(h + 1):
            cv.put(x, y - k, "G" if k < h else "V")
            cv.put(x + 1, y - k + 1, "n")
    for _ in range(40):
        x, y = rnd.randrange(W_), rnd.randrange(GROUND + 10, H_)
        cv.put(x, y, rnd.choice("ZqUu"))
        cv.put(x, y + 1, "G")
    # cobbled path from the gate down to the bottom-left
    for y in range(ARCH_FLOOR - 2, H_):
        t = (y - ARCH_FLOOR) / (H_ - ARCH_FLOOR)
        cx = ARCH_CX - 10 - t * 250
        half = 34 + t * 40
        for x in range(int(cx - half), int(cx + half)):
            row = (y - ARCH_FLOOR) // max(2, int(3 + t * 4))
            w = int(6 + t * 8)
            joint = (x + row * (w // 2)) % w == 0 or (y - ARCH_FLOOR) % max(2, int(3 + t * 4)) == 0
            edge = abs(x - cx) > half - 4
            if edge and rnd.random() < 0.6:
                continue
            k = "5" if joint else ("w" if (x // w + row) % 3 else "v")
            if not joint and (x % w) < 2 and (y % max(2, int(3 + t * 4))) == 1:
                k = "X"                                  # lit top-left edge of each stone
            cv.put(x, y, k)


# --- the gate --------------------------------------------------------------------------

def in_arch(x, y, r, spring=ARCH_SPRING, cx=ARCH_CX, floor=ARCH_FLOOR):
    dx = x - cx
    if y > floor:
        return False
    if y >= spring:
        return abs(dx) <= r
    return dx * dx + (y - spring) ** 2 <= r * r


def gate(cv):
    rnd = random.Random(5)
    # ruined wall with brick courses, broken top, ivy
    x0 = 382
    tops = {}

    def row_end(row):
        """The wall crumbles away on the right: each brick course ends a bit further
        out than the one above it, on a half-brick step."""
        return 566 + min(44, max(0, row - 2) * 3) + (9 if (row * 7) % 3 == 0 else 0)

    for x in range(x0, W_):
        tops[x] = int(96 + 10 * math.sin(x / 15.0) + 7 * math.sin(x / 4.7) + (18 if x < 400 else 0))
        for y in range(tops[x], ARCH_FLOOR + 4):
            row = (y - 90) // 8
            if x >= row_end(row):
                continue
            joint = (y - 90) % 8 == 0 or (x + (row % 2) * 9) % 18 == 0
            k = "g" if joint else ("f" if (y - 90) % 8 == 1 else "5")
            if x == row_end(row) - 1 and not joint:
                k = "e"                                  # the broken end of each brick course
            cv.put(x, y, k)
        if x < row_end((tops[x] - 90) // 8):
            cv.put(x, tops[x], "e")
            cv.put(x, tops[x] + 1, "F")
    # the top of each step of the broken edge, and fallen bricks at its foot
    for row in range(0, (ARCH_FLOOR - 90) // 8 + 1):
        y = 90 + row * 8
        for x in range(row_end(row - 1) if row else x0, row_end(row)):
            if y >= tops.get(x, 999):
                cv.put(x, y, "F")
    for bx, by in ((618, 302), (630, 296), (612, 290), (636, 306)):
        for y in range(by - 4, by):
            for x in range(bx, bx + 8):
                cv.put(x, y, "F" if y == by - 4 else ("5" if x < bx + 6 else "g"))
        for x in range(bx - 1, bx + 9):
            cv.put(x, by, "k")
    # the tunnel inside: receding arches and steps going down into the dark
    vx, vy = DOOR
    for y in range(ARCH_SPRING - ARCH_R, ARCH_FLOOR + 1):
        for x in range(ARCH_CX - ARCH_R, ARCH_CX + ARCH_R + 1):
            if in_arch(x, y, ARCH_R):
                cv.put(x, y, "o")
    for i, s in enumerate(TUNNEL):
        r = ARCH_R * s
        spring = vy + (ARCH_SPRING - vy) * s
        floor = vy + (ARCH_FLOOR - vy) * s
        cx = vx
        col = ("5", "g", "k", "d", "d")[i]
        for y in range(int(spring - r) - 2, int(floor) + 1):
            for x in range(int(cx - r) - 2, int(cx + r) + 3):
                inside = in_arch(x, y, r, spring, cx, floor)
                ring = in_arch(x, y, r + 2, spring, cx, floor) and not inside
                if ring:
                    cv.put(x, y, col)
    # steps on the tunnel floor
    for i in range(9):
        s = 1 - i * 0.075
        y = int(vy + (ARCH_FLOOR - vy) * s)
        half = ARCH_R * s - 2
        for x in range(int(ARCH_CX - half), int(ARCH_CX + half)):
            cv.put(x, y, ("e", "f", "f", "5", "5", "g", "g", "k", "k")[i])
    # a faint purple doorway far below
    for y in range(vy - 7, vy + 4):
        for x in range(vx - 3, vx + 4):
            cv.put(x, y, "H" if abs(x - vx) < 2 and y > vy - 5 else "h")
    for x, y in ((vx - 8, vy + 2), (vx + 8, vy + 2), (vx - 12, vy + 6), (vx + 12, vy + 6)):
        cv.put(x, y, "h")
    # the arch ring: wedge stones with runes
    R1 = ARCH_R + ARCH_T
    n_stones = 13
    for y in range(ARCH_SPRING - R1 - 2, ARCH_FLOOR + 1):
        for x in range(ARCH_CX - R1, ARCH_CX + R1 + 1):
            if not in_arch(x, y, R1) or in_arch(x, y, ARCH_R):
                continue
            dx = x - ARCH_CX
            if y < ARCH_SPRING:
                ang = math.atan2(ARCH_SPRING - y, dx)
                pos = ang / (math.pi / n_stones)
                seam = abs(pos - round(pos)) < 0.05
                r = math.hypot(dx, y - ARCH_SPRING)
            else:
                seam = (y - ARCH_SPRING) % 14 == 0
                r = abs(dx)
            k = "s"
            if r > R1 - 2:
                k = "e"
            elif r < ARCH_R + 2:
                k = "T"
            if dx > 0 and k == "s":
                k = "e"
            cv.put(x, y, "g" if seam else k)
    # a rune in every other wedge stone, glowing
    for i in range(1, n_stones):
        if i % 2:
            continue
        ang = i * math.pi / n_stones + math.pi / n_stones / 2
        r = ARCH_R + ARCH_T / 2
        x, y = ARCH_CX + math.cos(ang) * r, ARCH_SPRING - math.sin(ang) * r
        for dx, dy in ((0, -1), (0, 0), (0, 1), (-1, 0) if i % 4 else (1, 1)):
            cv.put(x + dx, y + dy, "H")
        for dx, dy in ((-2, 0), (2, 0), (0, -2), (0, 2)):
            if key_at(cv, x + dx, y + dy) in ("s", "e", "T"):
                cv.put(x + dx, y + dy, "h")
    # keystone and a cornice over the arch
    ky = ARCH_SPRING - R1 - 4
    for y in range(ky, ky + 14):
        for x in range(ARCH_CX - 8 + (y - ky) // 4, ARCH_CX + 9 - (y - ky) // 4):
            cv.put(x, y, "T" if y == ky else ("s" if x < ARCH_CX else "e"))
    for x, y in ((0, 3), (0, 4), (0, 5), (-1, 6), (1, 6), (0, 7), (-2, 4), (2, 4)):
        cv.put(ARCH_CX + x, ky + y, "H")
    for y in (ky - 6, ky - 5, ky - 4):
        for x in range(ARCH_CX - R1 - 14, ARCH_CX + R1 + 15):
            cv.put(x, y, "T" if y == ky - 6 else ("s" if y == ky - 5 else "g"))
    for x in range(ARCH_CX - R1 - 12, ARCH_CX + R1 + 13, 6):
        cv.put(x, ky - 3, "g")
        cv.put(x, ky - 2, "g")
    # pilasters with capitals and torches
    for px in (ARCH_CX - R1 - 14, ARCH_CX + R1 + 3):
        for y in range(ky - 2, ARCH_FLOOR + 2):
            for x in range(px, px + 11):
                cv.put(x, y, "T" if x < px + 2 else ("s" if x < px + 8 else "e"))
            if (y - ky) % 16 == 0:
                for x in range(px, px + 11):
                    cv.put(x, y, "g")
        for x in range(px - 2, px + 13):
            cv.put(x, ARCH_FLOOR - 4, "T")
            for y in range(ARCH_FLOOR - 3, ARCH_FLOOR + 2):
                cv.put(x, y, "s" if x < px + 8 else "e")
        TORCHES.append((px + 5, ARCH_SPRING + 10))
    # ivy hanging from the wall top and the cornice
    for _ in range(26):
        x = rnd.randrange(x0 + 4, 566)
        y0 = tops[x] + 1 if rnd.random() < 0.6 else ky - 4
        length = rnd.randint(8, 34)
        for k in range(length):
            xx = x + int(math.sin(k * 0.4 + x) * 1.5)
            if key_at(cv, xx, y0 + k) in ("o",):
                break
            cv.put(xx, y0 + k, "N" if k % 3 else "G")
            if k % 4 == 1:
                cv.put(xx + 1, y0 + k, "G")
                cv.put(xx - 1, y0 + k + 1, "n")
    # broken blocks lying in front of the gate
    for bx, by, w, h in ((ARCH_CX + 82, ARCH_FLOOR + 6, 12, 6), (ARCH_CX - 92, ARCH_FLOOR + 10, 9, 5), (600, 310, 14, 7)):
        for y in range(by - h, by):
            for x in range(bx, bx + w):
                cv.put(x, y, "T" if y == by - h else ("s" if x < bx + w - 3 else "e"))
        for x in range(bx - 1, bx + w + 1):
            cv.put(x, by, "k")


def torch(cv, x, y):
    """A torch on a bracket with a static flame and a warm glow on the stone around."""
    for dy in range(-16, 17):
        for dx in range(-18, 19):
            d = math.hypot(dx, dy * 1.2)
            k = key_at(cv, x + dx, y + dy)
            if k in ("T", "s", "e", "5", "f", "g") and d < 15:
                if d < 8:
                    cv.put(x + dx, y + dy, {"T": "u", "s": "c", "e": "c", "5": "B", "f": "B", "g": "b"}[k])
                elif (x + dx + y + dy) % 2 == 0:
                    cv.put(x + dx, y + dy, {"T": "c", "s": "B", "e": "B", "5": "b", "f": "b", "g": "b"}[k])
    for k in range(6):
        cv.put(x, y + k, "b")
        cv.put(x + 1, y + k, "B")
    for dx in (-1, 2):
        cv.put(x + dx, y + 1, "y")
    flame = ["..q..", ".qYq.", "qYZYq", "qZUZq", ".YZY.", "..Y.."]
    for j, row in enumerate(flame):
        for i, ch in enumerate(row):
            if ch != ".":
                cv.put(x - 2 + i + (1 if j < 2 else 0), y - 7 + j, ch)


# --- the purple light of the gate -------------------------------------------------------

def purple_glow(cv):
    """A light glow (the author preferred the dark tunnel): the arch's inner rim lit
    purple, the runes brighter, a little mist over the threshold and a few sparks; the
    tunnel stays dark with its faint doorway, the wall and the ground are not tinted."""
    rnd = random.Random(13)
    R1 = ARCH_R + ARCH_T
    # the inner rim of the arch: a bright line, a softer one behind it
    for y in range(ARCH_SPRING - R1, ARCH_FLOOR + 1):
        for x in range(ARCH_CX - R1, ARCH_CX + R1 + 1):
            if in_arch(x, y, ARCH_R) or not in_arch(x, y, R1):
                continue
            if not in_arch(x, y, ARCH_R + 1.5):
                if in_arch(x, y, ARCH_R + 3) and (x + y) % 2 == 0 and key_at(cv, x, y) != "g":
                    cv.put(x, y, "h")
                continue
            cv.put(x, y, "H" if y < ARCH_FLOOR - 30 or (x + y) % 3 else "h")
    # the runes in the wedge stones: a white heart and a purple halo
    n_stones = 13
    for i in range(2, n_stones, 2):
        ang = i * math.pi / n_stones + math.pi / n_stones / 2
        r = ARCH_R + ARCH_T / 2
        x, y = ARCH_CX + math.cos(ang) * r, ARCH_SPRING - math.sin(ang) * r
        cv.put(x, y, "U")
        for dx, dy in ((-1, -1), (1, -1), (-1, 1), (1, 1)):
            if key_at(cv, x + dx, y + dy) in ("s", "e", "T"):
                cv.put(x + dx, y + dy, "h")
    ky = ARCH_SPRING - R1 - 4
    for x, y in ((0, 4), (0, 5)):
        cv.put(ARCH_CX + x, ky + y, "U")
    # a thin purple mist over the threshold, sparks drifting out of the tunnel
    for x in range(ARCH_CX - ARCH_R - 10, ARCH_CX + ARCH_R + 11):
        top = ARCH_FLOOR - 3 + 2 * math.sin(x / 6.0)
        for y in range(int(top), ARCH_FLOOR + 5):
            if (x + y) % 2 == 0 and abs(x - ARCH_CX) < ARCH_R + 10 - (y - top) * 3:
                cv.put(x, y, "h")
    for _ in range(18):
        x = ARCH_CX + rnd.uniform(-ARCH_R - 20, ARCH_R + 20)
        y = rnd.uniform(ARCH_SPRING - 20, ARCH_FLOOR - 4)
        if not in_arch(int(x), int(y), ARCH_R - 4):
            cv.put(x, y, rnd.choice("HHU"))


# --- camp ------------------------------------------------------------------------------

def poly_fill(cv, pts, key_fn):
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    for y in range(int(min(ys)), int(max(ys)) + 1):
        for x in range(int(min(xs)), int(max(xs)) + 1):
            inside = False
            j = len(pts) - 1
            for i in range(len(pts)):
                xi, yi = pts[i]
                xj, yj = pts[j]
                if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi:
                    inside = not inside
                j = i
            if inside:
                k = key_fn(x, y)
                if k:
                    cv.put(x, y, k)


def line(cv, a, b, k):
    n = int(max(abs(b[0] - a[0]), abs(b[1] - a[1]))) + 1
    for i in range(n + 1):
        cv.put(a[0] + (b[0] - a[0]) * i / n, a[1] + (b[1] - a[1]) * i / n, k)


def tent(cv):
    apex = (112, 236)           # front apex
    back = (74, 222)            # back apex: the ridge runs back and to the left
    fl, fr = (70, 304), (154, 304)   # front base corners
    bl = (34, 288)              # back-left base corner
    # side roof (the left slope, away from the fire: in shade), canvas seams along it
    def side(x, y):
        t = (x - bl[0]) / (apex[0] - bl[0] + 1)
        return "v" if int(x + (y - 230) * 0.9) % 12 else "5"
    poly_fill(cv, [back, apex, fl, bl], side)
    # front: the lit triangle, warmer towards the fire on the right
    def front(x, y):
        t = (y - apex[1]) / (fl[1] - apex[1])
        half = (fr[0] - fl[0]) / 2 * t
        rel = (x - apex[0]) / max(half, 1)
        return "x" if rel > 0.45 else ("X" if rel > -0.4 else "w")
    poly_fill(cv, [apex, fr, fl], front)
    # the opening: a dark triangle, flaps tied back to both sides
    op_top, op_l, op_r = (112, 258), (96, 304), (128, 304)
    def opening(x, y):
        return "k" if y < 280 else ("b" if (x + y) % 7 == 0 else "g")
    poly_fill(cv, [op_top, op_r, op_l], opening)
    poly_fill(cv, [op_top, (100, 290), (88, 304), (96, 304)], lambda x, y: "w")
    poly_fill(cv, [op_top, (124, 290), (136, 304), (128, 304)], lambda x, y: "u")
    line(cv, (100, 290), (90, 288), "B")
    line(cv, (124, 290), (134, 288), "B")
    # warm glow from inside at the bottom of the opening
    for x in range(100, 125):
        for y in range(296, 304):
            if key_at(cv, x, y) in ("g", "b", "k") and (x + y) % 2 == 0:
                cv.put(x, y, "B")
    # edges: ridge pole, outline of the front, the hem on the ground
    line(cv, back, apex, "U")
    line(cv, (back[0], back[1] - 1), (apex[0], apex[1] - 1), "o")
    line(cv, apex, fl, "o")
    line(cv, apex, fr, "o")
    line(cv, back, bl, "o")
    line(cv, bl, fl, "o")
    line(cv, fl, fr, "o")
    for k in range(9):
        cv.put(apex[0], apex[1] - 1 - k, "b")
        cv.put(back[0], back[1] - 1 - k, "b")
    # guy ropes and pegs
    for a, b in ((apex, (176, 312)), (back, (14, 300)), ((134, 270), (172, 300))):
        line(cv, a, b, "W")
        cv.put(b[0], b[1], "B")
        cv.put(b[0], b[1] + 1, "b")
    # a backpack beside it, a bedroll
    for y in range(292, 306):
        for x in range(158, 170):
            if ((x - 164) / 6) ** 2 + ((y - 300) / 8) ** 2 <= 1:
                cv.put(x, y, "c" if x > 164 else "B")
    line(cv, (158, 296), (170, 296), "b")
    for x in range(158, 171):
        cv.put(x, 307, "k")


def fire_pit(cv):
    fx, fy = FIRE
    rings = ((26, 2), (46, 1), (70, 0))
    for y in range(fy - 40, H_):
        for x in range(fx - 120, fx + 120):
            d = math.hypot(x - fx, (y - fy) * 2.3)
            k = key_at(cv, x, y)
            if y < GROUND or k is None:
                continue
            warm = {"n": "N", "N": "G", "G": "V", "V": "x", "5": "v", "v": "w", "w": "X", "X": "x"}
            hot = {"n": "G", "N": "X", "G": "x", "V": "x", "5": "w", "v": "X", "w": "x", "X": "x", "k": "v"}
            if d < 22:
                cv.put(x, y, "X" if d > 12 else "w")
            elif d < 44 and k in hot:
                cv.put(x, y, hot[k])
            elif d < 64 and k in warm:
                cv.put(x, y, warm[k])
            elif d < 80 and k in warm and (x + y) % 2 == 0:
                cv.put(x, y, warm[k])
    # stones round the pit
    for i in range(11):
        a = i * math.tau / 11
        sx, sy = fx + math.cos(a) * 16, fy + math.sin(a) * 6.5
        for dx in range(-2, 3):
            for dy in range(-2, 2):
                if abs(dx) + abs(dy) < 4:
                    cv.put(sx + dx, sy + dy, "W" if dy < -1 or (dx < 0 and dy < 0) else ("m" if dy < 1 else "T"))
        cv.put(sx - 3, sy, "o")
        cv.put(sx + 3, sy, "o")
    # charred logs crossed in the pit
    for dx in range(-9, 10):
        cv.put(fx + dx, fy - 2 + dx // 4, "b")
        cv.put(fx + dx, fy - 1 + dx // 4, "y")
        cv.put(fx + dx, fy - 1 - dx // 4, "B")
        cv.put(fx + dx, fy - dx // 4, "b")
    for dx in range(-5, 6, 2):
        cv.put(fx + dx, fy - 1, "q")
    # log seats
    for lx, ly, w in ((fx + 34, fy + 4, 22), (fx - 52, fy + 10, 18)):
        for y in range(ly, ly + 6):
            for x in range(lx, lx + w):
                cv.put(x, y, "u" if y == ly else ("c" if y < ly + 3 else "B"))
        for y in range(ly, ly + 6):
            cv.put(lx, y, "y")
            cv.put(lx + w - 1, y, "y")
            cv.put(lx + w, y, "o")
        for x in range(lx, lx + w + 1):
            cv.put(x, ly + 6, "k")


# --- foreground and finish -----------------------------------------------------------

def foreground(cv):
    rnd = random.Random(9)
    # dark bushes framing the bottom corners
    for bx, by, r in ((-6, 372, 70), (60, 380, 44), (646, 370, 74), (560, 384, 40), (300, 392, 30)):
        for y in range(by - r, H_):
            for x in range(max(0, bx - r), min(W_, bx + r)):
                d = math.hypot(x - bx, (y - by) * 1.2)
                edge = r + 3 * math.sin(math.atan2(y - by, x - bx) * 9)
                if d < edge:
                    lit = d > edge - 2 and y < by - r * 0.4 and x < bx
                    cv.put(x, y, "n" if lit else "k")
    # tall grass blades along the bottom edge
    for _ in range(160):
        x = rnd.randrange(W_)
        h = rnd.randint(5, 16)
        lean = rnd.choice((-1, 1)) * rnd.random() * 0.4
        for k in range(h):
            cv.put(x + lean * k, H_ - 1 - k, "k" if k < h - 2 else "g")


def vignette(cv):
    for y in range(H_):
        for x in range(W_):
            d = math.hypot((x - W_ / 2) / (W_ / 2), (y - H_ / 2) / (H_ / 2))
            if d > 1.12:
                darken(cv, x, y, 2 if d > 1.28 else 1)


def background():
    cv = Canvas(W_, H_)
    sky(cv)
    far_layers(cv)
    ground(cv)
    gate(cv)
    purple_glow(cv)
    for tx, ty in TORCHES:
        torch(cv, tx, ty)
    fire_pit(cv)
    tent(cv)
    foreground(cv)
    vignette(cv)
    return cv.img


def flames(frame):
    cv = Canvas(32, 32)
    rnd = random.Random(frame * 11)
    base_x, base_y = 16, 28
    for i, (dx, h) in enumerate(((-5, 10), (-2, 16), (1, 21), (4, 15), (6, 9))):
        h = h + (frame * 3 + i * 2) % 5 - 2
        for y in range(h):
            t = y / h
            half = (1 - t) * 3.2 + 0.5
            sway = math.sin(y * 0.5 + frame * 2.1 + i) * t * 2
            for x in range(int(-half), int(half) + 1):
                k = "U" if t < 0.2 and abs(x) < half * 0.35 else ("Z" if t < 0.4 and abs(x) < half * 0.6 else ("Y" if t < 0.62 else ("q" if t < 0.85 else "R")))
                cv.put(base_x + dx + x + sway, base_y - y, k)
    for _ in range(5):
        cv.put(base_x + rnd.randint(-7, 7), base_y - 19 - rnd.randint(0, 9), rnd.choice("ZYq"))
    return cv.img


def fire_strip():
    strip = Image.new("RGBA", (96, 32))
    for i in range(3):
        strip.paste(flames(i), (i * 32, 0))
    return strip
