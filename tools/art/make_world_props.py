"""World props for the dark ruins (docs/art-style.md, 32-color palette), hand-drawn as
pixel maps like make_merchant.py.
- Chest 16x16, 4 frames (closed, lid lifts, lid half open, open):
  assets/art/pickups/chest.png
- Coin 16x16, 4 frames spin: assets/art/pickups/coin.png
- Health potion 16x16: assets/art/pickups/health_pack.png
- Wall torch 16x16, 4 frames flicker: assets/art/level/torch.png
- Gate with portal 48x32: assets/art/level/gate_closed.png (1 frame),
  gate_open.png (4 frames loop); portal opening burst 32x32, 5 frames:
  assets/art/fx/portal_open.png
- Column 16x32, sarcophagus 32x16, bones 16x16, broken statue 16x24:
  assets/art/level/pillar.png, sarcophagus.png, bones.png, statue.png
- Spell shrine 16x24, 4 frames glow, and the used one (1 frame):
  assets/art/level/shrine.png, shrine_used.png
- Arena door seal (rubble on the floor), 16x16 tile: assets/art/tiles/door_seal.png
- Training dummy 24x24, 3 frames (idle, hit, hit): assets/art/enemies/training_dummy.png
- Generic effects, 16x16 strips: hit spark (3), dust puff for dash and landing (4),
  death poof (4), falling into a pit (3): assets/art/fx/hit_spark.png, dust_puff.png,
  death_poof.png, pit_fall.png
- Sword slash, pointing right (0 rad), centred on the wielder: normal 48x48 (reach 24,
  arc 120 deg) and heavy 64x64 (reach 28, arc 160 deg, gold), 3 frames each (wind-up,
  full arc, fading): assets/art/fx/slash.png, slash_heavy.png. Flip vertically for the
  swing back.
- Arrows 16x16 pointing right, tip at (14, 8): player (blue fletching) and enemy (red
  fletching): assets/art/weapons/arrow.png, enemy_arrow.png
- Floor decals 16x16 in one strip, scattered over floor tiles (no outline, floor-range
  colours so actors still pop): pebbles, rubble, long crack, branching crack, puddle,
  moss, old bones, broken slab: assets/art/tiles/floor_decals.png
- Light textures, white (the light's colour and energy come from the code): banded
  128x128 (the hero) and 64x64 (torches, shrine), and a smooth 128x128 to compare:
  assets/art/fx/light_banded.png, light_torch.png, light_smooth.png. The only art with
  partial alpha, which lights need.
Run from the project root: python tools/art/make_world_props.py
"""
import os

from PIL import Image

P = {
    "o": "#08070b", "d": "#0f0e14", "k": "#17161f", "s": "#2a2935", "f": "#343442",
    "F": "#3f4050", "e": "#4c4e5f", "S": "#5d6072", "T": "#767a8c",
    "m": "#9aa2ad", "W": "#d8d4c4", "U": "#f4f0e0",
    "b": "#4a2f22", "B": "#7a4a2c", "c": "#b07040", "u": "#e0a070",
    "r": "#5a1820", "R": "#a82a30", "q": "#e85a3a",
    "y": "#8a4a10", "Y": "#e09a20", "Z": "#ffd860",
    "h": "#4a2a78", "H": "#9a5ae0",
    "n": "#263a32", "N": "#3b5a45",
    "j": "#1e3f6a", "l": "#3a7ac0", "L": "#7ac0f0",
    "g": "#1f1e29",
    "a": "#2aa8a0", "A": "#9af0e0",
}


def rgb(k):
    h = P[k]
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def draw(rows, w, h):
    img = Image.new("RGBA", (w, h))
    lines = rows.strip("\n").splitlines()
    assert len(lines) == h, (len(lines), h)
    for y, line in enumerate(lines):
        assert len(line) == w, (y, len(line), line)
        for x, key in enumerate(line):
            if key not in ". ":
                img.putpixel((x, y), rgb(key))
    return img


def strip(frames, w, h):
    img = Image.new("RGBA", (w * len(frames), h))
    for i, rows in enumerate(frames):
        img.paste(draw(rows, w, h), (i * w, 0))
    return img


CHEST_BODY = """\
.oBBBYBZYBYBBbo.
.oBBBYBYkBYBBbo.
.oBBBYBBBBYBBbo.
.obbbybbbbybbbo.
..oooooooooooo..
..dddddddddddd..
................
"""

CHEST_CLOSED = """
................
................
................
................
..oooooooooooo..
.ouccZccccZccco.
.occcYccccYccbo.
.oBBBYBBBBYBBbo.
.obbbybbbbybbbo.
""" + CHEST_BODY

CHEST_LIFT = """
................
................
................
..oooooooooooo..
.ouccZccccZccco.
.occcYccccYccbo.
.oBBBYBBBBYBBbo.
.obbbybbbbybbbo.
.oYZZZZZZZZZZYo.
""" + CHEST_BODY

CHEST_HALF = """
................
..oooooooooooo..
.ocBBYBBBBYBBco.
.obbbybbbbybbbo.
.oooooooooooooo.
.oYZZZZZZZZZZYo.
.oBYZUZZZUZZYBo.
.oBYZYYZYYZYyBo.
.occcZccccZccco.
""" + CHEST_BODY

CHEST_OPEN = """
..oooooooooooo..
.obbbybbbbybbbo.
.obbbybbbbybbbo.
.oBBBYBBBBYBBbo.
.oooooooooooooo.
.oBkkkkkkkkkkBo.
.oBkZYkYZkYkkBo.
.oBYZYYZYYZYyBo.
.occcZccccZccco.
""" + CHEST_BODY

COIN_FRONT = """
................
................
................
................
................
......oooo......
.....oZZYYo.....
....oZZYYYyo....
....oZYZZYyo....
....oZYZZYyo....
....oYYYYyyo....
.....oyyyyo.....
......oooo......
.....dddddd.....
................
................
"""

COIN_TURN = """
................
................
................
................
................
......oooo......
.....oZYYyo.....
.....oZYYyo.....
.....oZYYyo.....
.....oZYYyo.....
.....oYYyyo.....
.....oyyyyo.....
......oooo......
......dddd......
................
................
"""

COIN_EDGE = """
................
................
................
................
................
.......oo.......
......oZYo......
......oZyo......
......oZyo......
......oZyo......
......oYyo......
......oyyo......
.......oo.......
.......dd.......
................
................
"""

COIN_BACK = """
................
................
................
................
................
......oooo......
.....oyYYZo.....
.....oyYYZo.....
.....oyYYZo.....
.....oyYYZo.....
.....oyyYYo.....
.....oyyyyo.....
......oooo......
......dddd......
................
................
"""

POTION = """
................
................
................
......oooo......
......ouco......
......oBBo......
......oUWo......
.....ooUWoo.....
....oqUqRRRo....
...oqUqRRRRRo...
...oqqRRRRRro...
...oRRRRRRrro...
....oRRRRrro....
.....oooooo.....
....dddddddd....
................
"""

TORCH_BASE = """
.....oBccBo.....
.....ommmmo.....
......oBbo......
......oBbo......
......oBbo......
.......oo.......
................
"""

TORCH_FLAMES = [
    """
................
................
........q.......
.......qq.......
.......qYq......
......qYYq......
......qYZYq.....
.....qYZZYq.....
.....qYZUZq.....
""",
    """
................
................
.......q........
.......qq.......
......qYq.......
......qYYq......
......qYZYq.....
.....qYZZYq.....
.....qYZUZq.....
""",
    """
................
................
................
........q.......
.......qYq......
......qYYYq.....
.....qYZZYq.....
.....qYZZYq.....
.....qYZUZq.....
""",
    """
................
................
.........q......
........qq......
........qYq.....
.......qYYq.....
......qYZYq.....
.....qYZZYq.....
.....qYZUZq.....
""",
]


class Grid:
    """A w x h canvas of palette keys ('.' = empty) for shapes drawn in code."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.px = [["."] * w for _ in range(h)]

    def set(self, x, y, key):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = key

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return "."

    def rect(self, x0, y0, x1, y1, key):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, key)

    def outline(self, key="o"):
        """1 px outline outside every filled pixel (4 neighbours)."""
        edge = [(x, y) for y in range(self.h) for x in range(self.w) if self.px[y][x] == "."
                and any(self.get(x + dx, y + dy) not in (".", "d") for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))]
        for x, y in edge:
            self.px[y][x] = key

    def image(self):
        return draw("\n".join("".join(row) for row in self.px), self.w, self.h)


GATE_W, GATE_H = 48, 32
# The arch: a half circle on two jambs, centre column GATE_CX, springing at row ARCH_Y.
GATE_CX = 23.5
ARCH_Y = 16
OPEN_R = 10.5   # half width of the portal opening
RING_R = 14.5   # outer half width of the arch stones
GROUND_Y = 29   # last row of the gate (threshold)
ARCH_STONES = 7  # wedge stones in the half circle


def _in_shape(x, y, half):
    dx = x - GATE_CX
    if y > GROUND_Y:
        return False
    if y >= ARCH_Y:
        return abs(dx) <= half
    return dx * dx + (y - ARCH_Y) ** 2 <= half * half


def _in_opening(x, y):
    return _in_shape(x, y, OPEN_R)


def _in_ring(x, y):
    return _in_shape(x, y, RING_R) and not _in_opening(x, y)


def gate(portal_frame):
    """portal_frame: None = closed (dark, dim runes), 0..3 = open loop frame."""
    import math
    g = Grid(GATE_W, GATE_H)
    rune = "h" if portal_frame is None else "H"
    # Side pillars, the right one broken at the top (a ruin).
    for x0, x1, top in ((3, 8, 12), (39, 44, 14)):
        for y in range(top, GROUND_Y + 1):
            for x in range(x0, x1 + 1):
                g.set(x, y, "S")
            g.set(x0, y, "T")
            g.set(x1, y, "e")
        g.rect(x0, top, x1, top, "T")
        for y in range(top + 5, GROUND_Y, 5):
            g.rect(x0, y, x1, y, "k")
        for y in (top + 7, top + 8):
            g.set(x0 + 2, y, rune)
            g.set(x0 + 3, y, rune if y == top + 7 else "S")
    g.set(44, 14, ".")
    g.set(43, 14, ".")
    g.set(44, 15, "T")
    g.set(43, 15, "T")
    # Arch stones: wedges of the half circle, then the jambs in blocks.
    for y in range(GATE_H):
        for x in range(GATE_W):
            if not _in_ring(x, y):
                continue
            key = "S"
            if not _in_shape(x, y - 1, RING_R):
                key = "T"
            elif x < GATE_CX and not _in_shape(x - 1, y, RING_R):
                key = "T"
            elif _in_opening(x, y + 1) or _in_opening(x + 1, y) or _in_opening(x - 1, y):
                key = "e"
            if y < ARCH_Y:
                ang = math.atan2(ARCH_Y - y + 0.5, x - GATE_CX)
                step = math.pi / ARCH_STONES
                if abs((ang / step) - round(ang / step)) * step * 13.0 < 0.55 and 0 < round(ang / step) < ARCH_STONES:
                    key = "k"
                if abs(ang - math.pi / 2) < step / 2:
                    key = "T" if key != "k" else key
            elif y in (ARCH_Y + 4, ARCH_Y + 9):
                key = "k"
            g.set(x, y, key)
    # Keystone rune.
    for x, y in ((23, 3), (24, 3), (23, 4), (24, 5), (23, 5)):
        g.set(x, y, rune)
    if portal_frame is not None:
        g.set(24, 4, "Z")
    # Threshold step.
    g.rect(9, GROUND_Y, 38, GROUND_Y, "e")
    # Portal.
    cy = ARCH_Y + 2.5
    rx, ry = OPEN_R + 0.5, (GROUND_Y - 1 - (ARCH_Y - OPEN_R)) / 2.0 + 0.5
    for y in range(GATE_H):
        for x in range(GATE_W):
            if not _in_opening(x, y) or y >= GROUND_Y:
                continue
            dx, dy = (x - GATE_CX) / rx, (y - cy) / ry
            r = math.sqrt(dx * dx + dy * dy)
            a = math.atan2(dy, dx) / (2.0 * math.pi)
            if portal_frame is None:
                phase = r * 2.0 + a
                g.set(x, y, "h" if (phase % 1.0) < 0.22 and r < 0.9 else "k")
                continue
            phase = r * 2.2 + a - portal_frame / 4.0
            stripe = 1 if (phase % 1.0) < 0.45 else 0
            level = int((1.0 - r) * 2.4 + stripe * 1.0 - 0.2)
            if r < 0.16:
                level = 3
            g.set(x, y, "khHU"[max(0, min(level, 3))])
    g.outline()
    # Dark edge between the arch stones and the portal.
    for y in range(GATE_H):
        for x in range(GATE_W):
            if _in_opening(x, y) and y < GROUND_Y and any(_in_ring(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, -1))):
                g.set(x, y, "o")
    g.rect(3, 31, 44, 31, "d")
    return g.image()


def portal_burst():
    """32x32, 5 frames: a ring of light grows out of the gate and breaks into sparks."""
    import math
    frames = []
    radii = [3, 6, 9, 12, 14]
    for i, radius in enumerate(radii):
        g = Grid(32, 32)
        for y in range(32):
            for x in range(32):
                dx, dy = x - 15.5, (y - 15.5) * 1.25
                r = math.sqrt(dx * dx + dy * dy)
                ang = math.atan2(dy, dx)
                gap = i >= 3 and (int((ang + math.pi) / (2 * math.pi) * 12) % 2 == 1)
                if i == 0 and r < radius:
                    g.set(x, y, "U" if r < 1.6 else "H")
                elif radius - 1.5 <= r < radius and not gap:
                    g.set(x, y, "U" if i < 2 else "H")
                elif radius - 3.0 <= r < radius - 1.5 and not gap and i < 4:
                    g.set(x, y, "H" if i < 2 else "h")
        # Sparks outside the ring.
        for k in range(8):
            ang = k * math.pi / 4 + 0.4
            sr = radius + 2 + (k % 2)
            if i >= 1:
                g.set(int(round(15.5 + math.cos(ang) * sr)), int(round(15.5 + math.sin(ang) * sr / 1.25)), "Z" if i < 4 else "H")
        frames.append(g.image())
    img = Image.new("RGBA", (32 * len(frames), 32))
    for i, f in enumerate(frames):
        img.paste(f, (32 * i, 0))
    return img


PILLAR = """
................
.oooooooooooooo.
.oTTTTTTTTTTTSo.
.oSSSSSSSSSSSeo.
.oeeeeeeeeeeeeo.
..oooooooooooo..
...oTTSSeSSeeo..
...oTTSSeSSeeo..
...oTTSSeSSeeo..
...oTTSSeSSeeo..
...oTTSSeSkeeo..
...oTTSSeSSkeo..
...oTTSSeSSeeo..
...oTTSSeSSeeo..
...oTTSSeSSeeo..
...oTTSSeSSeeo..
...oTTSSeSSeeo..
...oTTSSeSSeeo..
...oTkSSeSSeeo..
...oTTkSeSSeeo..
...oTTSSeSSeeo..
...oTTSSeSSeeo..
...oTTSSeSSeeo..
...oNTSSeSSeeo..
...onNSSeSSeeo..
.oooooooooooooo.
.oTTTTTTTTTTTSo.
.oSSSSSSSSSSSeo.
.oNnSSSSSSSSSeo.
.oeneeeeeeeeeeo.
.oooooooooooooo.
.dddddddddddddd.
"""

SARCOPHAGUS = """
................................
..oooooooooooooooooooooooooooo..
.oTTTTTTTTTTTTTTTTTTTTTTTTTTTSo.
.oTSSSSSSSSSSSSSSSSSSSSSSSSSSeo.
.oTSSSSSeSSSSSSSSSSSSSSSSSSSSeo.
.oTSSSSeeeeeeeeeeeeeeeeeeSSSSeo.
.oTSSSSSeSSSSSSSSSSSSSSSSSSSSeo.
.oTSSSSSSSSSSSSSSSSSSSSSSSSNnSo.
.oeeeeeeeeeeeeeeeeeeeeeeeeeeeeo.
.ooooooooooooooooooooooooooooooo
.oSSSkSSSSSSSSSSSSSSSSSSSkSSSeo.
.oSSSkSSSSSSSSSSSSSSSSSSSkSSSeo.
.oeeekeeeeeeeeeeeeeeeeeeekeeeeo.
.oooooooooooooooooooooooooooooo.
.dddddddddddddddddddddddddddddd.
................................
""".replace(".ooooooooooooooooooooooooooooooo", ".oooooooooooooooooooooooooooooo.")

BONES = """
................
................
................
................
................
.........oooo...
........oUUWWo..
.oooo...oUooWo..
oUWWmo..oWWWmo..
.oooo....omomo..
..........ooo...
.oo.......oo....
oUWoooooooWUo...
oWWWWWWWWWWmo...
omWoooooooWmo...
.oo.......oo....
"""

STATUE = """
................
................
................
................
......ooo.......
.....oTSSo......
...ooTTSSeoo....
..oTTTSSSSeeo...
..oTSoSSkSoeo...
..oTSoSSSkoeo...
..oTSoSSSeoeo...
...ooTSSSeoo....
.....oTSSeo.....
....oTTSSSeo....
....oTSSSSeo....
...oTTSSSSSeo...
...oTSSSSkSeo...
..oooooooooooo..
..oTTTTTTTTTSo..
..oNSSSSSSSSeo..
..onNSSSSSSSeo..
..oneeeeeeeeeo..
..oooooooooooo..
..dddddddddddd..
"""

SHRINE_ALTAR = """
...oooooooooo...
..oTTTTTTTTTTo..
..oSSSSSSSSSeo..
..oSSSShhSSSeo..
...oSSShSSSeo...
...oSSShhSSeo...
...oSSSSSSSeo...
..oTTTTTTTTTeo..
..oooooooooooo..
..dddddddddddd..
"""

CRYSTAL = [
    ".......oo.......",
    "......oUHo......",
    ".....oUHHho.....",
    ".....oHHHho.....",
    ".....oHHhho.....",
    "......oHho......",
    ".......oo.......",
]


def shrine(frame):
    """frame 0..3: the crystal bobs and sparkles; None = used (cracked, dark)."""
    rows = ["." * 16 for _ in range(14)] + SHRINE_ALTAR.strip("\n").splitlines()
    rows = [list(r) for r in rows]
    if frame is None:
        for y, line in ((12, "......oooo......"), (13, ".....okhkho.....")):
            rows[y] = list(line)
        for y in (17, 19):
            rows[y] = [("k" if c == "h" else c) for c in rows[y]]
        return draw("\n".join("".join(r) for r in rows), 16, 24)
    top = 6 - (1 if frame in (1, 2) else 0)
    for i, line in enumerate(CRYSTAL):
        for x, c in enumerate(line):
            if c != ".":
                rows[top + i][x] = c
    glow = "H" if frame in (1, 2) else "h"
    rows[15][7] = glow
    rows[15][8] = glow
    sparkles = [(3, 8, "H"), (12, 6, "Z"), (4, 4, "Z"), (11, 11, "H")]
    sx, sy, sc = sparkles[frame]
    rows[sy][sx] = sc
    return draw("\n".join("".join(r) for r in rows), 16, 24)


def door_seal():
    """Rubble filling a door cell: rocks lit from the top-left, dark gaps, floor between."""
    rocks = [(4.0, 4.0, 4.2, 3.6), (11.5, 3.5, 4.0, 3.4), (8.0, 8.5, 4.6, 3.8),
             (2.5, 11.5, 3.2, 3.0), (13.0, 11.0, 3.4, 3.4), (7.5, 13.5, 3.0, 2.2)]
    g = Grid(16, 16)
    g.rect(0, 0, 15, 15, "f")
    for x, y in ((1, 8), (14, 7), (10, 15), (0, 15), (15, 1)):
        g.set(x, y, "s")
    for cx, cy, rx, ry in rocks:
        inside = set()
        for y in range(16):
            for x in range(16):
                dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
                if dx * dx + dy * dy <= 1.0:
                    inside.add((x, y))
        for x, y in inside:
            dx, dy = (x + 0.5 - cx) / rx, (y + 0.5 - cy) / ry
            g.set(x, y, "T" if dx + dy < -0.55 else "e" if dx + dy > 0.5 else "S")
        for x, y in inside:
            for nx, ny in ((x + 1, y), (x, y + 1), (x - 1, y), (x, y - 1)):
                if (nx, ny) not in inside and g.get(nx, ny) in ("f", "s"):
                    g.set(nx, ny, "k")
    return g.image()


DUMMY = """
........................
........................
........................
..........oooo..........
.........ouuuco.........
.........oububo.........
.........ouuuco.........
.........occcBo.........
..........oBbo..........
.......oooooooooo.......
...ooooouuuuuuccoooo....
..oBBBBouuuRRcccoBBBbo..
...ooooouuRUURccoooo....
.......ouuRUURcBo.......
.......ouuuRRccBo.......
.......ouuucccBBo.......
.......occcccBBBo.......
.......oooooooooo.......
..........oBbo..........
..........oBbo..........
..........oBbo..........
.......ooooBbooooo......
......oBBBBBBBBBBbo.....
......dddddddddddd......
"""


def dummy_frames():
    """Idle, then two hit frames: the top leans back and straw flies off."""
    rows = DUMMY.strip("\n").splitlines()
    out = [draw(DUMMY, 24, 24)]
    for lean, top_rows, specks in ((1, 18, [(5, 8, "u"), (19, 6, "Y"), (4, 14, "c")]),
                                   (1, 10, [(3, 5, "Y"), (20, 10, "u"), (18, 15, "c")])):
        shifted = []
        for y, line in enumerate(rows):
            line = "." * lean + line[:-lean] if y < top_rows else line
            shifted.append(list(line))
        for x, y, c in specks:
            if shifted[y][x] == ".":
                shifted[y][x] = c
        out.append(draw("\n".join("".join(r) for r in shifted), 24, 24))
    img = Image.new("RGBA", (24 * len(out), 24))
    for i, f in enumerate(out):
        img.paste(f, (24 * i, 0))
    return img


def _ring_frames(specs):
    """16x16 frames of round puffs. specs: per frame a list of (cx, cy, r, key, hollow)."""
    import math
    img = Image.new("RGBA", (16 * len(specs), 16))
    for i, blobs in enumerate(specs):
        g = Grid(16, 16)
        for cx, cy, r, key, hollow in blobs:
            for y in range(16):
                for x in range(16):
                    d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
                    if d <= r and not (hollow and d < r - 1.2):
                        g.set(x, y, key)
        img.paste(g.image(), (16 * i, 0))
    return img


def hit_spark():
    """A star of light where a hit lands: small flash, eight rays, scattered sparks."""
    frames = []
    rays = [(1, 0), (-1, 0), (0, 1), (0, -1), (1, 1), (-1, -1), (1, -1), (-1, 1)]
    for i in range(3):
        g = Grid(16, 16)
        if i == 0:
            for dx, dy in rays[:4]:
                g.set(8 + dx, 8 + dy, "Z")
            g.set(8, 8, "U")
        elif i == 1:
            for dx, dy in rays:
                for k in range(1, 5 if dx == 0 or dy == 0 else 4):
                    g.set(8 + dx * k, 8 + dy * k, "U" if k == 1 else "Z" if k < 3 else "Y")
            g.set(8, 8, "U")
        else:
            for dx, dy in rays:
                k = 5 if dx == 0 or dy == 0 else 4
                g.set(8 + dx * k, 8 + dy * k, "Y")
                g.set(8 + dx * (k - 1), 8 + dy * (k - 1), "q" if (dx + dy) % 2 else "Y")
        frames.append(g.image())
    img = Image.new("RGBA", (48, 16))
    for i, f in enumerate(frames):
        img.paste(f, (16 * i, 0))
    return img


def dust_puff():
    """Stone dust kicked up by a dash or a landing: puffs that spread and thin out."""
    return _ring_frames([
        [(8, 12, 2.6, "W", False), (5, 13, 1.8, "m", False), (11, 13, 1.8, "m", False)],
        [(7, 11, 3.2, "W", False), (4, 12, 2.4, "m", False), (12, 12, 2.4, "m", False), (8, 13, 1.6, "T", False)],
        [(7, 10, 2.4, "m", False), (3, 11, 2.0, "T", False), (13, 11, 2.0, "T", False), (9, 8, 1.4, "W", False)],
        [(4, 9, 1.5, "T", False), (12, 9, 1.5, "T", False), (8, 7, 1.0, "m", False)],
    ])


def death_poof():
    """A puff of pale smoke with a violet core where an enemy vanishes."""
    return _ring_frames([
        [(8, 9, 3.0, "U", False), (8, 9, 1.4, "H", False)],
        [(8, 9, 5.0, "W", False), (8, 9, 3.2, "U", False), (8, 9, 1.4, "H", False)],
        [(8, 8, 6.2, "W", True), (2, 2, 1.6, "U", False), (14, 3, 1.6, "U", False), (3, 14, 1.6, "U", False),
         (13, 13, 1.6, "U", False)],
        [(3, 4, 1.4, "m", False), (13, 5, 1.4, "m", False), (8, 2, 1.0, "W", False), (7, 13, 1.2, "m", False)],
    ])


def pit_fall():
    """Dust swirling down into a pit: a ring that shrinks into the dark."""
    return _ring_frames([
        [(8, 8, 6.0, "W", True), (8, 8, 4.6, "k", False)],
        [(8, 8, 4.2, "m", True), (8, 8, 3.0, "o", False)],
        [(8, 8, 2.2, "T", True), (8, 8, 1.0, "o", False)],
    ])


def slash(size, reach, arc_deg, max_thick, keys):
    """3 frames of a crescent swung clockwise around the canvas centre, facing right.
    keys: (edge, middle, inner) colours."""
    import math
    edge, middle, inner = keys
    half = math.radians(arc_deg) / 2.0
    spans = [(0.0, 0.45, 1.0), (0.0, 1.0, 1.0), (0.55, 1.0, 0.6)]
    img = Image.new("RGBA", (size * 3, size))
    c = size / 2.0
    for i, (tail, head, strength) in enumerate(spans):
        g = Grid(size, size)
        a0, a1 = -half + 2 * half * tail, -half + 2 * half * head
        for y in range(size):
            for x in range(size):
                dx, dy = x + 0.5 - c, y + 0.5 - c
                r = math.hypot(dx, dy)
                ang = math.atan2(dy, dx)
                if not (a0 <= ang <= a1) or r > reach:
                    continue
                u = (ang - a0) / max(a1 - a0, 1e-6)
                thick = max_thick * strength * (0.35 + 0.65 * (u if i < 2 else 1.0 - u))
                if r < reach - thick:
                    continue
                if i == 2:
                    g.set(x, y, middle if r > reach - 1.2 else inner)
                else:
                    g.set(x, y, edge if r > reach - 1.3 else middle if r > reach - thick * 0.6 else inner)
        img.paste(g.image(), (size * i, 0))
    return img


PLAYER_ARROW = """
................
................
................
................
................
................
.lL.........m...
.LlBBBBBBBBBmU..
.lL.........m...
................
................
................
................
................
................
................
"""

ENEMY_ARROW = """
................
................
................
................
................
................
.Rq.........m...
.qRbbbbbbbbbmU..
.Rq.........m...
................
................
................
................
................
................
................
"""


def arrow(rows):
    """An arrow with a 1 px outline around it."""
    g = Grid(16, 16)
    for y, line in enumerate(rows.strip("\n").splitlines()):
        for x, key in enumerate(line):
            if key != ".":
                g.set(x, y, key)
    g.outline()
    return g.image()


FLOOR_DECALS = [
    # pebbles
    """
................
................
...eF...........
...FFs......eF..
....ss......Fs..
.............s..
................
.......eFF......
.......FFFs.....
........sss.....
................
..eF............
..Fs.......eF...
...s.......Fs...
............s...
""",
    # rubble
    """
................
................
.....eeF........
....eFFFs.......
....FFFFs..eF...
.....sss...Fs...
............s...
..eF.....eeFF...
..FFs...eFFFFs..
...ss...FFFFFs..
.........sssss..
....eF..........
....Fs.....eF...
.....s.....Fs...
............s...
""",
    # long crack
    """
................
.k..............
..k.............
..sk............
....k...........
....sk..........
......k.........
......skk.......
.........k......
.........sk.....
...........k....
...........sk...
....k........k..
.....kk.......k.
.......k........
""",
    # branching crack
    """
................
................
.......k........
.......k........
......sk........
.......k........
.......kk.......
......k..k......
.....k....kk....
....sk......k...
....k.......sk..
...k..........k.
..k.............
""",
    # puddle
    """
................
................
................
......kkkkk.....
....kkgggggkk...
...kgggjjggggk..
...kggjggggggk..
...kggggggeggk..
....kgggggeegk..
.....kkggggkk...
.......kkkk.....
""",
    # moss
    """
................
................
.....n.N........
....nNNNn.......
...nNNnNNn..n...
...nNnnNNNn.Nn..
....nNNNNn..nn..
.....nnNn.......
..n....n...nN...
..Nn......nNNn..
...n.......nn...
""",
    # old bones
    """
................
................
................
..TT.......TT...
..eTeeeeeeeTe...
...e.......e....
................
.......T........
......Te....T...
.......eT..Te...
........eTTe....
........eTTe....
.......Te..eT...
.......e....e...
""",
    # broken slab
    """
................
................
................
....ssssssss....
...sFFFFFFFes...
...sFeFFFFFFs...
...sFFFFsFFFs...
...sFFFFFsFFs...
...sFFFFFFsFs...
....sFFFFFFs....
.....ssssss.....
""",
]


def floor_decals():
    img = Image.new("RGBA", (16 * len(FLOOR_DECALS), 16))
    for i, rows in enumerate(FLOOR_DECALS):
        lines = [r.ljust(16, ".")[:16] for r in rows.strip("\n").splitlines()]
        lines += ["." * 16] * (16 - len(lines))
        img.paste(draw("\n".join(lines[:16]), 16, 16), (16 * i, 0))
    return img


LIGHT_BANDS = [(0.25, 255), (0.45, 205), (0.65, 145), (0.85, 85), (1.0, 32)]


def light(size, banded):
    """A round white light: stepped rings (pixel-art look) or a smooth falloff."""
    import math
    img = Image.new("RGBA", (size, size))
    px = img.load()
    c = size / 2.0
    for y in range(size):
        for x in range(size):
            d = math.hypot(x + 0.5 - c, y + 0.5 - c) / c
            if d >= 1.0:
                continue
            if banded:
                alpha = next(a for limit, a in LIGHT_BANDS if d < limit)
            else:
                alpha = int(round(255 * (1.0 - d) ** 2))
            px[x, y] = (255, 255, 255, alpha)
    return img


def main():
    for folder in ("assets/art/pickups", "assets/art/level"):
        os.makedirs(folder, exist_ok=True)
    strip([CHEST_CLOSED, CHEST_LIFT, CHEST_HALF, CHEST_OPEN], 16, 16).save("assets/art/pickups/chest.png")
    strip([COIN_FRONT, COIN_TURN, COIN_EDGE, COIN_BACK], 16, 16).save("assets/art/pickups/coin.png")
    draw(POTION, 16, 16).save("assets/art/pickups/health_pack.png")
    strip([f.strip("\n") + "\n" + TORCH_BASE.strip("\n") for f in TORCH_FLAMES], 16, 16).save("assets/art/level/torch.png")
    gate(None).save("assets/art/level/gate_closed.png")
    opened = Image.new("RGBA", (GATE_W * 4, GATE_H))
    for i in range(4):
        opened.paste(gate(i), (GATE_W * i, 0))
    opened.save("assets/art/level/gate_open.png")
    os.makedirs("assets/art/fx", exist_ok=True)
    portal_burst().save("assets/art/fx/portal_open.png")
    draw(PILLAR, 16, 32).save("assets/art/level/pillar.png")
    draw(SARCOPHAGUS, 32, 16).save("assets/art/level/sarcophagus.png")
    draw(BONES, 16, 16).save("assets/art/level/bones.png")
    draw(STATUE, 16, 24).save("assets/art/level/statue.png")
    shrine_strip = Image.new("RGBA", (64, 24))
    for i in range(4):
        shrine_strip.paste(shrine(i), (16 * i, 0))
    shrine_strip.save("assets/art/level/shrine.png")
    shrine(None).save("assets/art/level/shrine_used.png")
    door_seal().save("assets/art/tiles/door_seal.png")
    dummy_frames().save("assets/art/enemies/training_dummy.png")
    hit_spark().save("assets/art/fx/hit_spark.png")
    dust_puff().save("assets/art/fx/dust_puff.png")
    death_poof().save("assets/art/fx/death_poof.png")
    pit_fall().save("assets/art/fx/pit_fall.png")
    slash(48, 23.5, 120, 6.0, ("U", "L", "l")).save("assets/art/fx/slash.png")
    slash(64, 28.5, 160, 8.0, ("U", "Z", "Y")).save("assets/art/fx/slash_heavy.png")
    os.makedirs("assets/art/weapons", exist_ok=True)
    arrow(PLAYER_ARROW).save("assets/art/weapons/arrow.png")
    arrow(ENEMY_ARROW).save("assets/art/weapons/enemy_arrow.png")
    floor_decals().save("assets/art/tiles/floor_decals.png")
    light(128, True).save("assets/art/fx/light_banded.png")
    light(64, True).save("assets/art/fx/light_torch.png")
    light(128, False).save("assets/art/fx/light_smooth.png")


if __name__ == "__main__":
    main()
