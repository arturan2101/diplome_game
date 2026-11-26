"""Batch 16: level backdrops, the rock behind the one-tile walls.

One seamless 64x64 texture per style (the glade 128x128), repeated under the whole level and seen only
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
  glade   v2, 128x128: the merchant's glade going on at dusk - darker grass in the
          floor's hue, a winding path, tree crowns and bushes like the cover tree
Run from the project root: python tools/art/make_backdrops.py [style ...]
(it prints the mean brightness next to the floor and the wall top of each style)
"""
import contextlib
import math
import os
import random
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from make_batch15 import RGB, hexc  # noqa: E402

N = 64
OUT = "assets/art/tiles"


class Tex:
    """An NxN grid of palette keys (64, the glade 128); every coordinate wraps, so drawing is seamless."""

    def __init__(self, fill):
        self.k = [[fill] * N for _ in range(N)]
        self.keep = set()  # pixels the clean-up must not touch (intended single dots)

    def get(self, x, y):
        n = len(self.k)
        return self.k[int(y) % n][int(x) % n]

    def set(self, x, y, key, keep=False):
        n = len(self.k)
        x, y = int(round(x)) % n, int(round(y)) % n
        self.k[y][x] = key
        if keep:
            self.keep.add((x, y))

    def image(self):
        n = len(self.k)
        img = Image.new("RGBA", (n, n))
        px = img.load()
        for y in range(n):
            for x in range(n):
                px[x, y] = RGB[self.k[y][x]]
        return img


def periodic_noise(seed, cells, octaves=((32, 1.0), (16, 0.7), (8, 0.35))):
    """Smooth value noise that repeats every N px: lattice values on a wrapping grid,
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
                    best = max(sorted(set(nb)), key=nb.count)  # sorted: same result every run
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


# dusk grass of the glade backdrop (nature theme extras, docs/art-style.md): the glade
# floor's #5a8a4a one step darker, same hue
RGB.update({"gd": hexc("#466b3a"), "gD": hexc("#34502c"), "ws": hexc("#6a6656")})


@contextlib.contextmanager
def tile_size(n):
    """Draw one texture at another size (every helper reads N when it is called)."""
    global N
    old, N = N, n
    try:
        yield
    finally:
        N = old


def blob_cells(cx, cy, r, rnd, lobes=4):
    """A round, slightly lumpy crown: a few overlapping circles."""
    parts = [(cx, cy, r * 0.8)]
    for i in range(lobes):
        a = rnd.uniform(0, math.tau) + i * math.tau / lobes
        parts.append((cx + math.cos(a) * r * 0.35, cy + math.sin(a) * r * 0.3, r * rnd.uniform(0.6, 0.72)))
    cells = set()
    for y in range(int(cy - r) - 2, int(cy + r) + 3):
        for x in range(int(cx - r) - 2, int(cx + r) + 3):
            if any(math.hypot(x + 0.5 - px, y + 0.5 - py) <= pr for px, py, pr in parts):
                cells.add((x, y))
    return cells


def crown(t, cells, cx, cy, r):
    """A tree crown or a bush in the style of the cover tree (nature slot 5), one step
    darker: body #466b3a, lit top-left #5a8a4a with a few #8ac060 leaves, shade #3b5a45 on
    the bottom-right, a dark green rim #263a32 instead of the black outline (the backdrop
    must not look like cover the player can reach), a shadow on the grass to the
    bottom-right."""
    for x, y in cells:  # shadow first, so the crown covers its own part
        for sx, sy in ((1, 1), (2, 2), (2, 1)):
            if (x + sx, y + sy) not in cells:
                t.set(x + sx, y + sy, "g" if sx == 2 and sy == 2 else "n")
    for x, y in cells:
        if any((x + dx, y + dy) not in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
            t.set(x, y, "n")
            continue
        lit = math.hypot(x + 0.5 - (cx - r * 0.3), y + 0.5 - (cy - r * 0.32)) <= r * 0.5
        shade = (x - 2, y - 2) not in cells or (x - 3, y - 1) not in cells or (x - 1, y - 3) not in cells
        t.set(x, y, "G" if lit else "N" if shade else "gd")
    # leaf texture: little lit tufts on the lit half, dark gaps on the shaded half
    for x, y in cells:
        inner = all((x + dx, y + dy) in cells for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
        if not inner:
            continue
        h = (x * 7 + y * 13) % 17
        here = t.get(x, y)
        if here == "G" and h in (0, 7):
            t.set(x, y, "V")  # a few bright leaves in the light
        elif here == "gd" and h in (3, 11):
            t.set(x, y, "G")  # leaf clusters catching some light
        elif here in ("gd", "N") and h == 5:
            t.set(x, y, "gD")  # gaps between the leaves


def glade():
    """v2, 128x128: the glade going on behind the walls at dusk. Grass in the floor's hue
    one step darker, a winding trodden path, tree crowns and bushes like the cover tree."""
    rnd = random.Random(266)
    with tile_size(128):
        t = Tex("gd")
        # grass: darker and lighter patches, then blades
        base_layers(t, periodic_noise(9, None, ((64, 1.0), (32, 0.7), (16, 0.4))),
                    [(0.22, "gD"), (2, "gd")])
        clean(t, 1)
        for n in range(700):  # blades: 2 px strokes, most dark, some with a lit tip
            x, y = rnd.randrange(N), rnd.randrange(N)
            lit = n % 4 == 0
            t.set(x, y, "G" if lit else "gD", keep=True)
            t.set(x + (n % 3 == 0), y + 1, "gd" if lit else "gD", keep=True)
        for n in range(14):  # a few dim flowers
            t.set(rnd.randrange(N), rnd.randrange(N), "u" if n % 3 else "Z", keep=True)
        # the path: winds top to bottom (seamless: the curve repeats every 128 px)
        path = set()
        for y in range(N):
            xc = 44 + 16 * math.sin(y * math.tau / N) + 5 * math.sin(y * 2 * math.tau / N + 1.3)
            w = 4.2 + 0.9 * math.sin(y * 3 * math.tau / N)
            for x in range(int(xc - w - 1), int(xc + w + 2)):
                if abs(x + 0.5 - xc) <= w:
                    path.add((x % N, y))
        for x, y in path:
            t.set(x, y, "3")
        rows = {}
        for x, y in path:
            rows.setdefault(y, set()).add(x)
        for x, y in path:  # dark edges (more on the right, away from the light), grass tufts creeping in
            if (x + 1) % N not in rows[y] or ((x + 2) % N not in rows[y] and y % 3):
                t.set(x, y, "2")
            elif (x - 1) % N not in rows[y]:
                t.set(x, y, "gd" if y % 4 == 0 else "2" if y % 4 == 2 else "3")
        for n in range(26):  # pebbles on the path
            x, y = rnd.choice(sorted(path))
            t.set(x, y, "ws", keep=True)
        path_pts = [(px, py) for px, py in path if py % 8 == 0]
        # trees: big crowns, away from the path
        trees = scatter(rnd, 7, 30, [(x, y) for x, y in path_pts])
        for cx, cy in trees:
            r = rnd.uniform(9, 13)
            crown(t, blob_cells(cx, cy, r, rnd, 5), cx, cy, r)
        # bushes, smaller, may touch the path edge
        taken = [(x, y) for x, y in trees] + [(x, y) for x, y in path_pts]
        for cx, cy in scatter(rnd, 16, 11, taken):
            r = rnd.uniform(3.5, 5.5)
            crown(t, blob_cells(cx, cy, r, rnd, 3), cx, cy, r)
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
    only = set(sys.argv[1:])
    for name, make in STYLES.items():
        if only and name not in only:
            continue
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
