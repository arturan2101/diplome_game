"""Title screen art (batch 13, part 6), 32-colour palette plus the nature theme's greens
and warm stones (the camp's colours, tools/art/make_camp.py).
- assets/art/ui/title_logo.png, 160x48: "RUINS" in blocky carved stone letters (5x7
  units of 5 px), lit from the top-left with a front face below each letter, cracks
  and moss, purple runes cut into the faces and a purple glow around the letters.
- assets/art/ui/menu_background.png, 640x360: the arch into the ruins at dusk on the
  right, the camp on the left (tent, campfire with a ring of stones, its warm light on
  the ground and on the near stones), distant ruined towers against a banded dusk sky.
  The flames are not in it: they are the overlay below.
- assets/art/ui/menu_fire.png, 3 frames of 32x32 side by side: the campfire's flames,
  drawn at FIRE_POS (top-left corner of the frame in the background), 8 fps loop.
Run from the project root: python tools/art/make_title.py
"""
import math
import random

from PIL import Image, ImageDraw

C = {
    "o": "#08070b", "d": "#0f0e14", "k": "#17161f", "g": "#1f1e29", "5": "#2a2935",
    "f": "#343442", "F": "#3f4050", "e": "#4c4e5f", "s": "#5d6072", "T": "#767a8c",
    "n": "#263a32", "N": "#3b5a45", "m": "#9aa2ad", "W": "#d8d4c4", "U": "#f4f0e0",
    "b": "#4a2f22", "B": "#7a4a2c", "c": "#b07040", "u": "#e0a070",
    "r": "#5a1820", "R": "#a82a30", "q": "#e85a3a", "y": "#8a4a10", "Y": "#e09a20", "Z": "#ffd860",
    "j": "#1e3f6a", "l": "#3a7ac0", "L": "#7ac0f0", "h": "#4a2a78", "H": "#9a5ae0",
    "G": "#5a8a4a", "V": "#8ac060", "w": "#8a8466", "v": "#6a6656", "X": "#9a9470", "x": "#c8c088",
}
W_, H_ = 640, 360
FIRE_POS = (178, 278)       # top-left of the 32x32 flame frame; the fire's base is at (194, 306)
FIRE = (194, 306)
ARCH_CX, ARCH_SPRING, ARCH_R, ARCH_T = 470, 196, 52, 15   # centre x, springing row, opening half width, ring
GROUND = 300


def rgb(k):
    h = C[k]
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


class Canvas:
    def __init__(self, w, h):
        self.img = Image.new("RGBA", (w, h))
        self.px = self.img.load()
        self.w, self.h = w, h

    def put(self, x, y, k):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[x, y] = rgb(k)

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[x, y]
        return (0, 0, 0, 0)

    def rect(self, x0, y0, x1, y1, k):
        for y in range(max(0, y0), min(self.h, y1 + 1)):
            for x in range(max(0, x0), min(self.w, x1 + 1)):
                self.px[x, y] = rgb(k)


# --- logo -------------------------------------------------------------------------------

FONT = {
    "R": ["####.", "#...#", "#...#", "####.", "#.#..", "#..#.", "#...#"],
    "U": ["#...#", "#...#", "#...#", "#...#", "#...#", "#...#", ".###."],
    "I": [".###.", "..#..", "..#..", "..#..", "..#..", "..#..", ".###."],
    "N": ["#...#", "##..#", "#.#.#", "#..##", "#...#", "#...#", "#...#"],
    "S": [".####", "#....", "#....", ".###.", "....#", "....#", "####."],
}
# Rune strokes cut into each letter (unit coordinates, drawn as 1 px purple lines).
RUNES = {"R": [(0, 1), (0, 2)], "U": [(4, 2), (4, 3)], "I": [(2, 2), (2, 4)], "N": [(0, 4), (0, 5)], "S": [(1, 3), (2, 3)]}


def logo():
    unit, gap, depth = 5, 4, 4
    cv = Canvas(160, 48)
    mask = set()
    x0, y0 = 9, 4
    letter_cells = []
    for i, ch in enumerate("RUINS"):
        lx = x0 + i * (5 * unit + gap)
        for r, row in enumerate(FONT[ch]):
            for c, cell in enumerate(row):
                if cell == "#":
                    for dy in range(unit):
                        for dx in range(unit):
                            mask.add((lx + c * unit + dx, y0 + r * unit + dy))
        letter_cells.append((ch, lx))
    # purple glow halo (2 px), under everything
    for x, y in list(mask):
        for dx in range(-3, 4):
            for dy in range(-3, 4 + depth):
                if abs(dx) + abs(dy) <= 3 and (x + dx, y + dy) not in mask:
                    cv.put(x + dx, y + dy, "h" if abs(dx) + abs(dy) > 1 else "H")
    # front faces: the letters extruded downwards
    for x, y in sorted(mask):
        for k in range(1, depth + 1):
            if (x, y + k) not in mask:
                cv.put(x, y + k, "e" if k <= 2 else "5")
    rnd = random.Random(4)
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
    # block seams every unit (mortar) and a few cracks
    for x, y in mask:
        if (x - x0) % 10 == 0 and (y - y0) % 5 != 0 and rnd.random() < 0.5:
            if (x - 1, y) in mask and (x + 1, y) in mask:
                cv.put(x, y, "e")
    for ch, lx in letter_cells:
        for ux, uy in RUNES[ch]:
            cx, cy = lx + ux * unit + 2, y0 + uy * unit
            for t in range(unit + 1):
                if (cx, cy + t) in mask:
                    cv.put(cx, cy + t, "H")
            cv.put(cx - 1, cy + 1, "H") if (cx - 1, cy + 1) in mask else None
    for x, y in ((14, 10), (15, 11), (15, 12), (88, 30), (89, 31), (138, 8), (137, 9)):
        if (x, y) in mask:
            cv.put(x, y, "k")
    for x, y in ((10, 37), (11, 37), (64, 37), (120, 37), (121, 36)):
        if (x, y - 1) in mask:
            cv.put(x, y - 1, "N")
    # outline
    img = cv.img
    out = img.copy()
    for y in range(48):
        for x in range(160):
            if img.getpixel((x, y))[3]:
                continue
            if any(0 <= x + dx < 160 and 0 <= y + dy < 48 and img.getpixel((x + dx, y + dy))[3]
                   for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out.putpixel((x, y), rgb("o"))
    return out


# --- background ------------------------------------------------------------------------

SKY = [(0, "d"), (40, "k"), (85, "g"), (120, "5"), (150, "h"), (178, "r"), (198, "R"), (212, "q")]


def sky(cv):
    rnd = random.Random(1)
    for y in range(0, 240):
        k = [c for start, c in SKY if y >= start][-1]
        for x in range(W_):
            # stepped band edges instead of straight lines
            yy = y + (2 if (x // 23 + y) % 7 == 0 else 0)
            k2 = [c for start, c in SKY if yy >= start][-1]
            cv.put(x, y, k2 if abs(yy - y) else k)
    for _ in range(140):
        x, y = rnd.randrange(W_), rnd.randrange(0, 140)
        cv.put(x, y, rnd.choice("UWLLm"))
    for _ in range(6):
        x, y = rnd.randrange(W_), rnd.randrange(0, 90)
        for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
            cv.put(x + dx, y + dy, "U" if (dx, dy) == (0, 0) else "L")
    # a thin moon
    for y in range(40, 62):
        for x in range(70, 92):
            d1 = math.hypot(x - 80, y - 51)
            d2 = math.hypot(x - 85, y - 48)
            if d1 <= 9 and d2 > 8:
                cv.put(x, y, "W" if x < 76 else "m")


def far_ruins(cv):
    rnd = random.Random(2)
    # rolling far hills, then ruined towers and broken walls in silhouette
    for x in range(W_):
        top = 222 + int(6 * math.sin(x / 37.0) + 4 * math.sin(x / 13.0))
        for y in range(top, 260):
            cv.put(x, y, "k")
    towers = [(40, 150, 18), (120, 178, 12), (250, 160, 20), (300, 190, 10), (610, 170, 16)]
    for tx, top, w in towers:
        for y in range(top, 232):
            for x in range(tx - w // 2, tx + w // 2):
                cv.put(x, y, "k")
        # broken top
        for x in range(tx - w // 2, tx + w // 2):
            for y in range(top - rnd.randint(0, 6), top):
                if rnd.random() < 0.6:
                    cv.put(x, y, "k")
        # dark windows
        for wy in range(top + 8, 220, 14):
            cv.rect(tx - 2, wy, tx + 1, wy + 5, "d")
    # a long broken aqueduct
    for x in range(150, 330):
        cv.put(x, 196, "k")
        cv.put(x, 197, "k")
    for ax in range(155, 330, 26):
        cv.rect(ax, 198, ax + 4, 232, "k")
    for ax in range(159, 325, 26):
        for y in range(198, 206):
            for x in range(ax, ax + 22):
                if math.hypot(x - ax - 11, (y - 206) * 1.4) < 11:
                    cv.put(x, y, "d" if y > 199 else "k")


def ground(cv):
    rnd = random.Random(3)
    for y in range(240, H_):
        for x in range(W_):
            top = 252 + int(4 * math.sin(x / 29.0))
            if y >= top:
                cv.put(x, y, "n" if y < 262 else "N")
    for y in range(262, H_):
        for x in range(W_):
            if rnd.random() < 0.05:
                cv.put(x, y, "G" if rnd.random() < 0.6 else "n")
    # the path from the arch down to the bottom-left, past the fire
    for y in range(GROUND, H_):
        t = (y - GROUND) / (H_ - GROUND)
        cx = ARCH_CX - t * 230
        half = 26 + t * 30
        for x in range(int(cx - half), int(cx + half)):
            edge = abs(x - cx) > half - 3
            cv.put(x, y, "n" if edge and rnd.random() < 0.5 else ("v" if (x * 7 + y * 3) % 11 else "w"))


def arch(cv):
    rnd = random.Random(5)
    # the rock face / ruined wall the arch is built into
    wall_x0, wall_x1 = 370, 640
    for x in range(wall_x0, wall_x1):
        top = 104 + int(10 * math.sin(x / 17.0) + 6 * math.sin(x / 5.3)) + (24 if x > 590 else 0)
        for y in range(top, GROUND + 2):
            cv.put(x, y, "5")
        # bricks
        for y in range(top, GROUND + 2):
            row = (y - 100) // 7
            if (y - 100) % 7 == 0 or (x + row * 9) % 18 == 0:
                cv.put(x, y, "g")
            elif (y - 100) % 7 == 1:
                cv.put(x, y, "f")
        for y in range(top, top + 3):
            cv.put(x, y, "e" if y == top else "f")
        if rnd.random() < 0.15:
            for y in range(top - 2, top + 1):
                cv.put(x, y, "N")
    # the opening: dark, a purple glow deep inside
    for y in range(ARCH_SPRING - ARCH_R, GROUND + 1):
        for x in range(ARCH_CX - ARCH_R, ARCH_CX + ARCH_R + 1):
            dx = x - ARCH_CX
            if y >= ARCH_SPRING or dx * dx + (y - ARCH_SPRING) ** 2 <= ARCH_R ** 2:
                d = math.hypot(dx * 0.9, (y - (GROUND - 20)) * 1.3)
                cv.put(x, y, "H" if d < 7 else ("h" if d < 17 else "o"))
    # arch ring: wedge stones; the left side catches the fire's warm light
    R1 = ARCH_R + ARCH_T
    for y in range(ARCH_SPRING - R1, GROUND + 1):
        for x in range(ARCH_CX - R1, ARCH_CX + R1 + 1):
            dx = x - ARCH_CX
            inside = (y >= ARCH_SPRING and abs(dx) <= ARCH_R) or (y < ARCH_SPRING and dx * dx + (y - ARCH_SPRING) ** 2 <= ARCH_R ** 2)
            outer = (y >= ARCH_SPRING and abs(dx) <= R1) or (y < ARCH_SPRING and dx * dx + (y - ARCH_SPRING) ** 2 <= R1 ** 2)
            if not outer or inside:
                continue
            if y < ARCH_SPRING:
                ang = math.atan2(ARCH_SPRING - y, dx)
                seam = abs((ang / (math.pi / 11)) - round(ang / (math.pi / 11))) < 0.06
            else:
                seam = (y - ARCH_SPRING) % 16 == 0
            r = math.hypot(dx, min(0, y - ARCH_SPRING))
            k = "e"
            if r > R1 - 2:
                k = "s"
            if r < ARCH_R + 2:
                k = "f"
            if dx < 0:
                k = {"e": "s", "s": "T", "f": "e"}[k]
                if dx < -ARCH_R - 4 and y > ARCH_SPRING - 10:
                    k = "u" if x < ARCH_CX - R1 + 2 else "c"   # warm light from the fire
            cv.put(x, y, "g" if seam else k)
    # keystone with a rune
    cv.rect(ARCH_CX - 6, ARCH_SPRING - R1 - 2, ARCH_CX + 6, ARCH_SPRING - ARCH_R + 1, "s")
    cv.rect(ARCH_CX - 6, ARCH_SPRING - R1 - 2, ARCH_CX + 6, ARCH_SPRING - R1 - 1, "T")
    for x, y in ((0, 6), (0, 7), (0, 8), (-1, 9), (1, 9), (0, 10)):
        cv.put(ARCH_CX + x, ARCH_SPRING - R1 + y, "H")
    # steps
    for i, (w, y) in enumerate(((ARCH_R + 22, GROUND - 2), (ARCH_R + 30, GROUND + 3), (ARCH_R + 38, GROUND + 8))):
        cv.rect(ARCH_CX - w, y, ARCH_CX + w, y + 1, "T" if i else "s")
        cv.rect(ARCH_CX - w, y + 2, ARCH_CX + w, y + 4, "f")
        for x in range(ARCH_CX - w, ARCH_CX - w + 20):
            cv.put(x, y, "c")


def column(cv, x0, top, bottom, w, warm):
    for y in range(top, bottom):
        for x in range(x0, x0 + w):
            k = "T" if x < x0 + 3 else ("s" if x < x0 + w - 3 else "e")
            if warm and x < x0 + 2:
                k = "u"
            cv.put(x, y, k)
        cv.put(x0 - 1, y, "o")
        cv.put(x0 + w, y, "o")
    # broken top and a plinth
    rnd = random.Random(x0)
    for x in range(x0, x0 + w):
        for y in range(top - rnd.randint(0, 5), top):
            cv.put(x, y, "T")
        cv.put(x, top - 6 if rnd.random() < 0.2 else top - 7, "o")
    cv.rect(x0 - 3, bottom - 5, x0 + w + 2, bottom, "s")
    cv.rect(x0 - 3, bottom - 5, x0 + w + 2, bottom - 4, "T")


def tent(cv):
    apex, base_y, x0, x1 = (110, 238), 302, 52, 168
    for y in range(apex[1], base_y):
        t = (y - apex[1]) / (base_y - apex[1])
        l, r = apex[0] - (apex[0] - x0) * t, apex[0] + (x1 - apex[0]) * t
        for x in range(int(l), int(r) + 1):
            k = "B" if x < apex[0] - 4 else ("c" if x < r - 6 else "u")     # lit side faces the fire
            if abs(x - apex[0]) < 12 * t and y > apex[1] + 22:
                k = "b"                                                     # the opening
            cv.put(x, y, k)
        cv.put(l - 1, y, "o")
        cv.put(r + 1, y, "o")
    for x in range(x0 - 4, x1 + 5):
        cv.put(x, base_y, "o")
    # poles and ropes
    for k in range(8):
        cv.put(apex[0], apex[1] - k, "b")
    for t in range(40):
        cv.put(x1 + t * 0.8, base_y - 30 + t * 0.75, "w")


def fire_place(cv):
    fx, fy = FIRE
    # warm light on the ground: banded rings
    for y in range(fy - 40, min(H_, fy + 40)):
        for x in range(fx - 110, fx + 110):
            d = math.hypot((x - fx) / 1.0, (y - fy) * 2.4)
            p = cv.get(x, y)
            if y < 248 or p[3] == 0:
                continue
            grassy = p[:3] in (rgb("N")[:3], rgb("n")[:3], rgb("G")[:3])
            if d < 24:
                cv.put(x, y, "w" if d > 14 else "X")              # trodden earth round the fire
            elif d < 52 and grassy:
                cv.put(x, y, "V" if p[:3] == rgb("G")[:3] else "G")   # grass in the warm light
            elif d < 80 and grassy and p[:3] == rgb("n")[:3]:
                cv.put(x, y, "N")
    # ring of stones and logs
    for i in range(10):
        a = i * math.tau / 10
        sx, sy = fx + math.cos(a) * 15, fy + math.sin(a) * 6
        for dx in range(-2, 3):
            for dy in range(-1, 2):
                cv.put(sx + dx, sy + dy, "m" if dy < 0 else "T")
        cv.put(sx - 3, sy, "o")
        cv.put(sx + 3, sy, "o")
    for dx in range(-9, 10):
        cv.put(fx + dx, fy - 1 + dx // 5, "B")
        cv.put(fx + dx, fy + dx // 5, "b")
        cv.put(fx + dx, fy + 1 - dx // 4, "B")


def bushes(cv):
    rnd = random.Random(8)
    for bx, by, r in ((10, 300, 22), (240, 340, 18), (620, 330, 24), (330, 296, 14), (560, 352, 16)):
        for y in range(by - r, by + r // 2):
            for x in range(bx - r, bx + r):
                d = math.hypot(x - bx, (y - by) * 1.3)
                if d < r:
                    cv.put(x, y, "n" if d > r * 0.75 or y > by else ("G" if (x - bx) + (y - by) < -r * 0.6 else "N"))


def background():
    cv = Canvas(W_, H_)
    sky(cv)
    far_ruins(cv)
    ground(cv)
    arch(cv)
    column(cv, 352, 182, GROUND + 2, 14, True)
    column(cv, 596, 214, GROUND + 6, 12, False)
    tent(cv)
    fire_place(cv)
    bushes(cv)
    return cv.img


def flames(frame):
    cv = Canvas(32, 32)
    rnd = random.Random(frame * 11)
    base_x, base_y = 16, 28
    for i, (dx, h) in enumerate(((-5, 10), (-2, 16), (1, 20), (4, 14), (6, 9))):
        h = h + (frame * 3 + i * 2) % 5 - 2
        for y in range(h):
            t = y / h
            half = (1 - t) * 3.2 + 0.5
            sway = math.sin(y * 0.5 + frame * 2.1 + i) * t * 2
            for x in range(int(-half), int(half) + 1):
                k = "Z" if t < 0.35 and abs(x) < half * 0.5 else ("Y" if t < 0.6 else ("q" if t < 0.85 else "R"))
                cv.put(base_x + dx + x + sway, base_y - y, k)
    for _ in range(4):
        cv.put(base_x + rnd.randint(-7, 7), base_y - 20 - rnd.randint(0, 8), rnd.choice("ZYq"))
    return cv.img


def main():
    logo().save("assets/art/ui/title_logo.png")
    bg = background()
    bg.save("assets/art/ui/menu_background.png")
    strip = Image.new("RGBA", (96, 32))
    for i in range(3):
        strip.paste(flames(i), (i * 32, 0))
    strip.save("assets/art/ui/menu_fire.png")
    print("title art written")


if __name__ == "__main__":
    main()
