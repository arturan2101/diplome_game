"""Batch 16: level backdrops, the rock behind the one-tile walls.

One seamless 64x64 texture per style, repeated under the whole level and seen only
outside the walls. Dark and low-contrast (well below the wall top and at or below the
floor of its style, so the floor and the walls read over it), no outline, light from the
top-left very weak (one step up on the top-left of a stone, one step down on the
bottom-right), small details scattered unevenly so the repeat does not show.
Palette: the 32 colours plus the theme extras (make_batch15.PAL).

Output: assets/art/tiles/<style>_backdrop.png for
  ruins   dark grey-violet stone, buried masonry, rare brick fragments
  fungal  dark earth with roots and mycelium threads, rare dim teal dots
  flooded wet blue-green stone, streaks, rare moss
  fire    black basalt, rare dim orange veins
  sand    dark sandstone with sand drifts
  glade   dense grass and bushes seen from above, at dusk (the merchant's glade)
Run from the project root: python tools/art/make_backdrops.py
(it prints the mean brightness next to the floor and the wall top of each style)
"""
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_batch15 import RGB  # noqa: E402

N = 64
OUT = "assets/art/tiles"


class Tex:
    """A 64x64 grid of palette keys; every coordinate wraps, so drawing is seamless."""

    def __init__(self, fill):
        self.k = [[fill] * N for _ in range(N)]
        self.keep = set()  # pixels the clean-up must not touch (intended single dots)

    def get(self, x, y):
        return self.k[int(y) % N][int(x) % N]

    def set(self, x, y, key, keep=False):
        x, y = int(round(x)) % N, int(round(y)) % N
        self.k[y][x] = key
        if keep:
            self.keep.add((x, y))

    def image(self):
        img = Image.new("RGBA", (N, N))
        px = img.load()
        for y in range(N):
            for x in range(N):
                px[x, y] = RGB[self.k[y][x]]
        return img


def periodic_noise(seed, cells, octaves=((32, 1.0), (16, 0.7), (8, 0.35))):
    """Smooth value noise that repeats every 64 px: lattice values on a wrapping grid,
    cosine-interpolated, rescaled to 0 ... 1. octaves = (lattice size in px, weight)."""
    rnd = random.Random(seed)
    field = [[0.0] * N for _ in range(N)]
    total = 0.0
    for cell, amp in octaves:
        g = N // cell
        lat = [[rnd.random() for _ in range(g)] for _ in range(g)]
        for y in range(N):
            for x in range(N):
                fx, fy = x / cell, y / cell
                x0, y0 = int(fx), int(fy)
                tx = (1 - math.cos((fx - x0) * math.pi)) / 2
                ty = (1 - math.cos((fy - y0) * math.pi)) / 2
                a = lat[y0 % g][x0 % g]
                b = lat[y0 % g][(x0 + 1) % g]
                c = lat[(y0 + 1) % g][x0 % g]
                d = lat[(y0 + 1) % g][(x0 + 1) % g]
                field[y][x] += amp * ((a * (1 - tx) + b * tx) * (1 - ty) + (c * (1 - tx) + d * tx) * ty)
        total += amp
    lo = min(min(r) for r in field)
    hi = max(max(r) for r in field)
    return [[(v - lo) / (hi - lo) for v in row] for row in field]  # 0 ... 1


def base_layers(t, noise, bands):
    """bands: [(threshold, key), ...] ascending; pixels with noise below a threshold get its key."""
    for y in range(N):
        for x in range(N):
            v = noise[y][x]
            for limit, key in bands:
                if v < limit:
                    t.k[y][x] = key
                    break


def clean(t, passes=2):
    """Remove lone pixels and 1 px spurs: a pixel whose 4 neighbours mostly share another
    key takes that key (intended dots in t.keep stay)."""
    for _ in range(passes):
        changes = []
        for y in range(N):
            for x in range(N):
                if (x, y) in t.keep:
                    continue
                me = t.k[y][x]
                nb = [t.get(x + 1, y), t.get(x - 1, y), t.get(x, y + 1), t.get(x, y - 1)]
                same = nb.count(me)
                if same <= 1:
                    best = max(set(nb), key=nb.count)
                    if nb.count(best) >= 3 or same == 0:
                        changes.append((x, y, best))
        for x, y, k in changes:
            t.k[y][x] = k


def stone(t, cx, cy, rx, ry, body, lit, shade):
    """A small stone: flat body, its top-left edge one step lighter, its bottom-right edge one
    step darker (the very weak top-left light)."""
    inside = set()
    for y in range(int(cy - ry) - 1, int(cy + ry) + 2):
        for x in range(int(cx - rx) - 1, int(cx + rx) + 2):
            if ((x + 0.5 - cx) / rx) ** 2 + ((y + 0.5 - cy) / ry) ** 2 <= 1:
                inside.add((x, y))
    for x, y in inside:
        t.set(x, y, body)
    for x, y in inside:
        if (x - 1, y) not in inside or (x, y - 1) not in inside:
            if lit and ((x - 1, y) not in inside) + ((x, y - 1) not in inside) == 2 or (
                    lit and (x, y - 1) not in inside and (x - 1, y - 1) not in inside):
                t.set(x, y, lit)
        if shade and ((x + 1, y) not in inside and (x, y + 1) not in inside):
            t.set(x, y, shade)
    if shade:  # a 1 px contact shadow under the stone
        for x, y in inside:
            if (x, y + 1) not in inside and t.get(x, y + 1) not in (body, lit):
                t.set(x, y + 1, shade)


def crack(t, rnd, x, y, length, key, keep=False):
    """A thin wandering crack with clean 1-1 steps."""
    dx, dy = rnd.choice(((1, 0), (0, 1), (1, 1), (-1, 1)))
    for _ in range(length):
        t.set(x, y, key, keep)
        r = rnd.random()
        if r < 0.55:
            x, y = x + dx, y + dy
        elif r < 0.8:
            x, y = x + (dy if dx == 0 else dx), y + (dy if dy else rnd.choice((0, 1)))
        else:
            x, y = x + (dx if dy == 0 else rnd.choice((-1, 1))), y + max(dy, 0)


def scatter(rnd, count, min_dist, taken):
    """Points spread unevenly over the wrapping tile, at least min_dist apart."""
    pts = []
    tries = 0
    while len(pts) < count and tries < 4000:
        tries += 1
        p = (rnd.uniform(0, N), rnd.uniform(0, N))
        ok = True
        for q in pts + taken:
            ddx = min(abs(p[0] - q[0]), N - abs(p[0] - q[0]))
            ddy = min(abs(p[1] - q[1]), N - abs(p[1] - q[1]))
            if math.hypot(ddx, ddy) < min_dist:
                ok = False
                break
        if ok:
            pts.append(p)
    return pts


# --- styles ---------------------------------------------------------------------------

def ruins():
    rnd = random.Random(161)
    t = Tex("g")
    base_layers(t, periodic_noise(1, None), [(0.12, "k"), (0.72, "g"), (2, "5")])
    # buried masonry: brick courses that show only where the noise is low (rock over them)
    mask = periodic_noise(2, None, ((16, 1.0), (32, 0.6)))
    for y in range(N):
        for x in range(N):
            if mask[y][x] > 0.5:
                continue
            row = y // 6
            mortar = y % 6 == 5 or (x + (row % 2) * 6) % 12 == 11
            if mortar:
                t.set(x, y, "k")
            elif y % 6 == 0 and t.get(x, y) == "g":
                t.set(x, y, "5")  # the faint top edge of a buried brick
    clean(t)
    taken = []
    for cx, cy in scatter(rnd, 11, 9, taken):
        r = rnd.uniform(1.3, 2.4)
        stone(t, cx, cy, r + 0.4, r, "5", "f", "k")
        taken.append((cx, cy))
    # rare brick fragments: small chipped blocks lying in the rock
    for cx, cy in scatter(rnd, 3, 16, taken):
        w, h = rnd.choice(((4, 3), (5, 3), (3, 2)))
        for y in range(h):
            for x in range(w):
                if (x, y) in ((w - 1, 0),) and rnd.random() < 0.7:
                    continue  # a chipped corner
                t.set(cx + x, cy + y, "f" if y == 0 or x == 0 else "5")
        for x in range(w):
            t.set(cx + x, cy + h, "k")
        taken.append((cx, cy))
    for _ in range(5):
        crack(t, rnd, rnd.randrange(N), rnd.randrange(N), rnd.randint(4, 8), "k")
    clean(t, 1)
    return t


def fungal():
    rnd = random.Random(162)
    t = Tex("1")
    base_layers(t, periodic_noise(3, None), [(0.84, "1"), (2, "2")])
    clean(t)
    taken = []
    for cx, cy in scatter(rnd, 9, 10, taken):
        r = rnd.uniform(1.2, 2.0)
        stone(t, cx, cy, r + 0.5, r, "2", "3", "k")
        taken.append((cx, cy))
    # roots: long, gently curving, a darker side under them
    for n in range(4):
        x, y = rnd.uniform(0, N), rnd.uniform(0, N)
        ang = rnd.uniform(0, math.tau)
        for s in range(rnd.randint(22, 40)):
            ang += rnd.uniform(-0.25, 0.25)
            x, y = x + math.cos(ang), y + math.sin(ang) * 0.8
            t.set(x, y, "b")
            t.set(x, y + 1, "k")
            if s % 9 == 4 and rnd.random() < 0.6:  # a side rootlet
                bx, by, ba = x, y, ang + rnd.choice((-1, 1)) * 1.1
                for _ in range(rnd.randint(3, 6)):
                    bx, by = bx + math.cos(ba), by + math.sin(ba)
                    t.set(bx, by, "b")
    # mycelium: thin pale threads in short broken runs
    for n in range(7):
        x, y = rnd.uniform(0, N), rnd.uniform(0, N)
        ang = rnd.uniform(0, math.tau)
        for s in range(rnd.randint(6, 12)):
            ang += rnd.uniform(-0.6, 0.6)
            x, y = x + math.cos(ang), y + math.sin(ang)
            if s % 5 != 4:
                t.set(x, y, "5")
    clean(t, 1)
    # rare dim teal dots (glowing spores), some with a moss-dark halo pixel
    for cx, cy in scatter(rnd, 6, 14, taken):
        t.set(cx, cy, "a", keep=True)
        if rnd.random() < 0.5:
            t.set(cx + 1, cy, "n", keep=True)
    return t


def flooded():
    rnd = random.Random(163)
    t = Tex("g")
    base_layers(t, periodic_noise(4, None), [(0.18, "k"), (0.48, "g"), (0.6, "5"), (2, "n")])
    clean(t)
    taken = []
    for cx, cy in scatter(rnd, 10, 9, taken):
        r = rnd.uniform(1.3, 2.3)
        stone(t, cx, cy, r + 0.4, r, "5", "f", "k")
        taken.append((cx, cy))
    # streaks: water running down, blue-dark with a darker trail, a wet glint at the top
    for x0 in rnd.sample(range(N), 7):
        y = rnd.randrange(N)
        length = rnd.randint(7, 16)
        x = x0
        for s in range(length):
            t.set(x, y + s, "j")
            if s and rnd.random() < 0.12:
                x += rnd.choice((-1, 1))
                t.set(x, y + s, "j")
        t.set(x, y + length, "k")
        if rnd.random() < 0.6:
            t.set(x0, y, "l", keep=True)
    # rare moss clumps
    for cx, cy in scatter(rnd, 3, 18, taken):
        for y in range(-1, 2):
            for x in range(-2, 3):
                if abs(x) + abs(y) <= 2 and rnd.random() < 0.85:
                    t.set(cx + x, cy + y, "N" if y < 0 or x < 0 else "n")
    for _ in range(4):
        crack(t, rnd, rnd.randrange(N), rnd.randrange(N), rnd.randint(4, 7), "k")
    clean(t, 1)
    return t


def fire():
    rnd = random.Random(164)
    t = Tex("d")
    base_layers(t, periodic_noise(5, None), [(0.22, "o"), (0.66, "d"), (2, "k")])
    clean(t)
    taken = []
    for cx, cy in scatter(rnd, 10, 9, taken):
        r = rnd.uniform(1.3, 2.4)
        stone(t, cx, cy, r + 0.4, r, "k", "g", "o")
        taken.append((cx, cy))
    # rare veins: dark red cracks with a dull orange core in places, no glow around
    for n in range(3):
        x, y = rnd.uniform(0, N), rnd.uniform(0, N)
        ang = rnd.uniform(0, math.tau)
        hot = rnd.randint(2, 5)
        for s in range(rnd.randint(14, 24)):
            ang += rnd.uniform(-0.5, 0.5)
            x, y = x + math.cos(ang), y + math.sin(ang)
            k = "R" if hot <= s < hot + rnd.randint(2, 4) else "r"
            t.set(x, y, k, keep=True)
            if s == hot + 1 and n == 0:
                t.set(x, y, "q", keep=True)
    for _ in range(6):
        crack(t, rnd, rnd.randrange(N), rnd.randrange(N), rnd.randint(4, 8), "o")
    clean(t, 1)
    return t


def sand():
    rnd = random.Random(165)
    t = Tex("6")
    base_layers(t, periodic_noise(6, None), [(2, "6")])
    clean(t)
    taken = []
    for cx, cy in scatter(rnd, 8, 10, taken):
        r = rnd.uniform(1.3, 2.4)
        stone(t, cx, cy, r + 0.6, r, "7", "8", "k")
        taken.append((cx, cy))
    # sand drifts: soft heaps with ripple lines, the lit crest on their upper-left side
    drift = periodic_noise(7, None)
    for y in range(N):
        for x in range(N):
            v = drift[y][x]
            if v > 0.6:
                ripple = (x + 2 * y + int(v * 20)) % 6 == 0 or v > 0.78 and (x + 2 * y) % 6 == 1
                t.set(x, y, "8" if ripple else "7")
    clean(t)
    for _ in range(4):
        crack(t, rnd, rnd.randrange(N), rnd.randrange(N), rnd.randint(4, 7), "k")
    clean(t, 1)
    return t


def glade():
    rnd = random.Random(166)
    t = Tex("n")
    base_layers(t, periodic_noise(8, None), [(0.08, "g"), (2, "n")])
    # grass blades: short strokes leaning one way, lighter tip
    for n in range(260):
        x, y = rnd.randrange(N), rnd.randrange(N)
        lean = rnd.choice((0, 0, 1, -1))
        h = rnd.randint(2, 3)
        for s in range(h):
            t.set(x + (lean if s == h - 1 else 0), y - s, "N" if s else "n")
    clean(t, 1)
    # bushes: round clumps, mid green, a few lit leaves top-left, dark under the clump
    for cx, cy in scatter(rnd, 24, 7, []):
        r = rnd.uniform(3.0, 5.0)
        lobes = [(cx + math.cos(a) * r * 0.45, cy + math.sin(a) * r * 0.4, r * rnd.uniform(0.55, 0.7))
                 for a in (rnd.uniform(0, math.tau) + i * math.tau / 4 for i in range(4))]
        cells = set()
        for y in range(int(cy - r) - 2, int(cy + r) + 3):
            for x in range(int(cx - r) - 2, int(cx + r) + 3):
                if any(math.hypot(x + 0.5 - lx, y + 0.5 - ly) <= lr for lx, ly, lr in lobes):
                    cells.add((x, y))
        for x, y in cells:
            if (x, y + 1) not in cells:
                t.set(x, y + 1, "k")
            if (x + 1, y + 1) not in cells:
                t.set(x + 1, y + 1, "g")
        for x, y in cells:
            edge_lit = (x - 1, y) not in cells or (x, y - 1) not in cells
            edge_dark = (x + 1, y) not in cells or (x, y + 1) not in cells
            k = "N"
            if edge_dark:
                k = "n"
            elif edge_lit and (x + y) % 3 == 0:
                k = "G"
            elif (x * 3 + y * 5) % 11 == 0:
                k = "n"  # leaf gaps
            t.set(x, y, k)
    clean(t, 1)
    return t


STYLES = {"ruins": ruins, "fungal": fungal, "flooded": flooded, "fire": fire, "sand": sand, "glade": glade}
# atlas, floor slot, wall top slot (for the brightness report)
REF = {"ruins": ("ruins", 0, 4), "fungal": ("fungal", 0, 4), "flooded": ("flooded", 0, 4),
       "fire": ("fire", 0, 4), "sand": ("sand", 0, 4), "glade": ("nature", 7, 4)}


def lum_of(pixels):
    px = [p for p in pixels if p[3]]
    return sum(0.299 * p[0] + 0.587 * p[1] + 0.114 * p[2] for p in px) / len(px)


def main():
    for name, make in STYLES.items():
        img = make().image()
        img.save(f"{OUT}/{name}_backdrop.png")
        atlas, fslot, wslot = REF[name]
        at = Image.open(f"{OUT}/{atlas}_tiles_atlas.png").convert("RGBA")
        floor = lum_of(at.crop((fslot * 16, 0, fslot * 16 + 16, 16)).getdata())
        top = lum_of(at.crop((wslot * 16, 0, wslot * 16 + 16, 16)).getdata())
        me = lum_of(img.getdata())
        print(f"{name:8s} backdrop {me:5.1f}  floor {floor:5.1f}  wall top {top:5.1f}  "
              f"({100 * (1 - me / top):.0f}% darker than the wall top)")


if __name__ == "__main__":
    main()
