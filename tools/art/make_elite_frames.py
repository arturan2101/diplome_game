"""Elite enemy art: the shield skeleton and the triple-shot archer, made from the
ordinary sprites so they read as the same kind, but more dangerous: dark red armour
accents instead of copper, glowing eyes, a big dark red shield on the skeleton.
Also the wave warning ring (assets/art/fx/spawn_warning.png, 8 frames of 32x32).
Run from the project root after make_action_frames.py:
    python tools/art/make_elite_frames.py
"""
import glob
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_action_frames as actions  # noqa: E402

F = 24
SRC = "assets/art/enemies"


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


ARMOUR = {hexc("#b07040"): hexc("#a82a30"), hexc("#8a4a10"): hexc("#5a1820"),
          hexc("#e0a070"): hexc("#e85a3a"), hexc("#4a2f22"): hexc("#5a1820"), hexc("#7a4a2c"): hexc("#5a1820")}
EYE = hexc("#e85a3a")
GLOW = hexc("#ffd860")
OUTLINE = hexc("#08070b")
SHIELD = ["..oooo..", ".oRRRRo.", "oRrggrRo", "oRgWWgRo", "oRgWWgRo", "oRrggrRo", ".oRRRRo.", "..oooo.."]
SHIELD_COL = {"o": hexc("#08070b"), "R": hexc("#a82a30"), "r": hexc("#5a1820"), "g": hexc("#9aa2ad"),
              "W": hexc("#d8d4c4")}


def elite_frame(img, side):
    out = img.copy()
    px = out.load()
    for y in range(F):
        for x in range(F):
            p = px[x, y]
            if not p[3]:
                continue
            if p[:3] in ARMOUR:
                px[x, y] = ARMOUR[p[:3]] + (255,)
            elif p[:3] == EYE:
                px[x, y] = GLOW + (255,)
    box = out.getbbox()
    if side and box:
        # The shield on the leading side, at chest height.
        sx = box[0] - 2 if side == "left" else (box[2] - 6 if side == "right" else box[0] - 1)
        sy = box[1] + 7
        for dy, row in enumerate(SHIELD):
            for dx, key in enumerate(row):
                x, y = sx + dx, sy + dy
                if key != "." and 0 <= x < F and 0 <= y < F - 1:
                    px[x, y] = SHIELD_COL[key] + (255,)
    return out


def elite_strip(path, out_path):
    img = Image.open(path).convert("RGBA")
    name = os.path.basename(path)
    side = None
    for d in ("down", "left", "right"):
        if f"_{d}" in name:
            side = d
    if "death" in name:
        side = None
    out = Image.new("RGBA", img.size)
    for i in range(img.width // F):
        out.paste(elite_frame(img.crop((i * F, 0, i * F + F, F)), side), (i * F, 0))
    out.save(out_path)


def spawn_warning():
    """A ring on the floor that grows and brightens: an elite or a wave appears here."""
    size, frames = 32, 8
    strip = Image.new("RGBA", (size * frames, size))
    for i in range(frames):
        frame = Image.new("RGBA", (size, size))
        px = frame.load()
        radius = 6 + i * 1.2
        color = hexc("#a82a30") if i < 4 else hexc("#e85a3a")
        inner = hexc("#5a1820")
        for y in range(size):
            for x in range(size):
                dx, dy = x - 15.5, (y - 15.5) * 1.6   # flattened: lies on the floor
                d = (dx * dx + dy * dy) ** 0.5
                if abs(d - radius) < 0.8:
                    px[x, y] = color + (255,)
                elif d < radius - 1 and (x + y + i) % 4 == 0:
                    px[x, y] = inner + (255,)
        strip.paste(frame, (i * size, 0))
    os.makedirs("assets/art/fx", exist_ok=True)
    strip.save("assets/art/fx/spawn_warning.png")


def archer_elite():
    """The archer has only a still Kenney picture: its cloth turns dark red, its
    brightest pixels (face, eyes) glow, and three small arrow heads above it say
    "triple shot"."""
    sheet = Image.open("assets/kenney_tiny_dungeon/tilemap_packed.png").convert("RGBA")
    img = sheet.crop((64, 144, 80, 160))
    px = img.load()
    for y in range(16):
        for x in range(16):
            r, g, b, a = px[x, y]
            if not a:
                continue
            value = max(r, g, b)
            if min(r, g, b) > 180 and y < 8:
                px[x, y] = GLOW + (255,)
            elif g >= r and g >= b and value > 40:
                px[x, y] = (hexc("#a82a30") if value > 110 else hexc("#5a1820")) + (255,)
    for x in (4, 8, 12):
        for dx, dy in ((0, 0), (-1, 1), (1, 1)):
            if px[x + dx, dy][3] == 0:
                px[x + dx, dy] = GLOW + (255,) if dy == 0 else hexc("#e85a3a") + (255,)
    img.save(os.path.join(SRC, "archer_elite.png"))


for path in sorted(glob.glob(os.path.join(SRC, "skeleton_*.png"))):
    name = os.path.basename(path)
    if "sample" in name:
        continue
    elite_strip(path, os.path.join(SRC, name.replace("skeleton_", "skeleton_elite_")))
actions.write_frames(SRC, "skeleton_elite", os.path.join(SRC, "skeleton_elite_frames.tres"))
spawn_warning()
archer_elite()
print("elite art written")
