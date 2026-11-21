"""Title screen art (batch 13, part 6), 32-colour palette plus the nature theme's greens
and warm stones (the camp's colours, tools/art/make_camp.py).
- assets/art/ui/title_logo.png, 160x48: "RUINS" in blocky carved stone letters (5x7
  units of 5 px), lit from the top-left with a front face below each letter, cracks
  and moss, purple runes cut into the faces and a purple glow around the letters.
- assets/art/ui/menu_background.png (640x360) and menu_fire.png (3 frames of 32x32):
  tools/art/make_menu_background.py, called from here.
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


def main():
    logo().save("assets/art/ui/title_logo.png")
    import make_menu_background as mb       # imports this module's palette and Canvas
    mb.background().save("assets/art/ui/menu_background.png")
    mb.fire_strip().save("assets/art/ui/menu_fire.png")
    print("title art written")


if __name__ == "__main__":
    main()
