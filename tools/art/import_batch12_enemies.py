"""Batch 12 enemies from PixelLab: the drowned (flooded ruins) and the ember imp (fire
ruins), 24x24 frames, 4 directions, like batch 10 group 5 (tools/art/make_enemy_windups.py).

Characters (standard, 4 directions, high top-down, size 24 on a 36 canvas):
  drowned    73b1a2b4-02b8-432f-9f47-a993de1b3e2e  "idle" = template breathing-idle,
             "walk" = template walking-6-frames
  ember imp  9384ef34-8dd2-4572-b6aa-52b68b13c442  "idle" = template breathing-idle,
             "walk" = template walking-4-frames
Attacks: the rotations fitted to 24x24, padded to 32, enlarged 2x and imported as v3
characters, then skeleton-v3 clips written pose by pose:
  drowned    8ea973c0-58ec-48fb-bc6a-6cbe7e14411e  "attack_grab"   6 frames: arms reach
             back and up 0-1 (hold 1), lunge and grab 2-3 (strike 2), back 4-5
  ember imp  60107900-e01b-4496-9631-2b05f059dfdf  "attack_throw"  6 frames: hands up,
             a fireball grows between them 0-2 (hold 2), throw 3 (strike, spawn
             imp_fireball.png here), follow-through 4-5; the fireball is drawn here
Every strip: palette snap, one scale per direction (the 24x24 rotation's height), each
frame's lowest body pixel on row 22 and centred on the rotation's feet, a #0f0e14 shadow
on row 23. The imp floats: its body is lifted 2 px over the shadow in every strip, the
idle bobs 1 px and its cracks flicker. Hurt (2) like the other enemies (make_action_frames
hurt); death drawn here: the drowned collapses into a puddle (5), the imp bursts into
embers (5).
Usage (from the project root), with the four ZIPs (get_character download links) and the
folder of fitted rotations (<name>_rot_<dir>.png, made from the characters' rotations with
import_pixellab.fit):
    python tools/art/import_batch12_enemies.py <rot dir> drowned=<zip> drowned2x=<zip> imp=<zip> imp2x=<zip>
"""
import io
import math
import os
import random
import sys
import zipfile

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_action_frames as actions  # noqa: E402
from import_pixellab import snap  # noqa: E402

SRC = "assets/art/enemies"
F = 24
FEET = 22
SHADOW = (15, 14, 20, 255)
DIRS = {"south": "down", "east": "right", "north": "up", "west": "left"}
STEP = {"down": (0, 1), "up": (0, -1), "left": (-1, 0), "right": (1, 0)}
ACTORS = {
    # name: (key in argv, key of the 2x zip, idle anim, walk anim, attack anim, lift)
    "drowned": ("drowned", "drowned2x", "idle", "walk", "attack_grab", 0),
    "ember_imp": ("imp", "imp2x", "idle", "walk", "attack_throw", 2),
}
ROT = {"drowned": "drowned", "ember_imp": "imp"}


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def load(zip_path):
    z = zipfile.ZipFile(zip_path)
    out = {}
    for n in sorted(z.namelist()):
        parts = n.split("/")
        if "animations" in parts and n.endswith(".png"):
            i = parts.index("animations")
            out.setdefault((parts[i + 1], parts[i + 2]), []).append(Image.open(io.BytesIO(z.read(n))).convert("RGBA"))
    return out


def find(anims, name, direction):
    for (anim, d), frames in anims.items():
        if d == direction and (anim == name or name in anim):
            return frames
    raise KeyError((name, direction, sorted(set(a for a, _ in anims))))


def body_box(img):
    px = img.load()
    pts = [(x, y) for y in range(img.height) for x in range(img.width) if px[x, y][3] and px[x, y] != SHADOW]
    xs, ys = [p[0] for p in pts], [p[1] for p in pts]
    bottom = max(ys)
    low = [x for x, y in pts if y >= bottom - 2]
    return min(xs), min(ys), max(xs), bottom, (min(low) + max(low)) / 2.0


FLOOR = {hexc(h)[:3] for h in ("#1f1e29", "#2a2935", "#343442", "#3f4050", "#4c4e5f", "#5d6072")}


def clean(img):
    """Palette snap; the shadow pixels and PixelLab's own grey shadow (floor colours in
    the lowest rows) are dropped, the game draws its own."""
    out = snap(img)
    px = out.load()
    rows = [y for y in range(out.height) if any(px[x, y][3] for x in range(out.width))]
    low = max(rows) - 2 if rows else 0
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p == SHADOW or (y >= low and p[3] and p[:3] in FLOOR):
                px[x, y] = (0, 0, 0, 0)
    return out


def place(frames, rot, scale, lift):
    """Scale, then each frame's lowest body pixel on FEET - lift, the strip centred on
    the rotation's feet by its first frame; a shadow under the rotation's feet."""
    _, _, _, _, rot_cx = body_box(rot)
    small = []
    for f in frames:
        w, h = max(1, round(f.width * scale)), max(1, round(f.height * scale))
        small.append(clean(f.resize((w, h), Image.NEAREST)))
    cx0 = body_box(small[0])[4]
    dx = int(round(rot_cx - cx0))
    rx = max(3, (body_box(rot)[2] - body_box(rot)[0]) // 2)
    out = []
    for f in small:
        cell = Image.new("RGBA", (F, F))
        for x in range(F):
            if abs(x + 0.5 - (rot_cx + 0.5)) <= rx:
                cell.putpixel((x, F - 1), SHADOW)
        bottom = body_box(f)[3]
        layer = Image.new("RGBA", (F, F))
        layer.paste(f, (dx, FEET - lift - bottom), f)
        cell.alpha_composite(layer)
        out.append(cell)
    return out


def source_height(frames):
    b = body_box(frames[0])
    return b[3] - b[1] + 1


# --- the imp's own touches -----------------------------------------------------------

GLOW = {hexc("#e85a3a")[:3]: hexc("#ffd860"), hexc("#a82a30")[:3]: hexc("#e85a3a")}


def flicker(img, on):
    if not on:
        return img
    out = img.copy()
    px = out.load()
    for y in range(F):
        for x in range(F):
            p = px[x, y]
            if p[3] and p[:3] in GLOW and (x + y) % 2 == 0:
                px[x, y] = GLOW[p[:3]]
    return out


def bob(img, dy):
    """Body moved up by dy, the shadow row stays."""
    if not dy:
        return img
    body = img.copy()
    for x in range(F):
        body.putpixel((x, F - 1), (0, 0, 0, 0))
    out = Image.new("RGBA", (F, F))
    for x in range(F):
        if img.getpixel((x, F - 1)) == SHADOW:
            out.putpixel((x, F - 1), SHADOW)
    out.alpha_composite(body.transform((F, F), Image.AFFINE, (1, 0, 0, 0, 1, dy)))
    return out


def fireball_in_hands(img, radius):
    """A fireball at the top of the figure, between the raised hands."""
    out = img.copy()
    x0, y0, x1, _, _ = body_box(img)
    cx, cy = (x0 + x1) / 2.0, y0 - radius + 1
    px = out.load()
    for y in range(F):
        for x in range(F):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= radius:
                px[x, y] = hexc("#ffd860") if d < radius * 0.45 else (hexc("#e09a20") if d < radius * 0.8 else hexc("#e85a3a"))
    return out


# --- deaths ----------------------------------------------------------------------------

def drowned_death(idle):
    """Slumps, sinks and melts into a puddle with seaweed."""
    frames = []
    box = body_box(idle)
    cx = box[4]
    for i, (squash, r) in enumerate(((0.8, 0), (0.55, 3), (0.32, 5), (0.15, 6), (0.0, 7))):
        f = Image.new("RGBA", (F, F))
        for y in range(F):
            for x in range(F):
                d = ((x + 0.5 - cx) / max(r, 0.1)) ** 2 + ((y + 0.5 - FEET) / max(r * 0.4, 0.1)) ** 2
                if r and d <= 1:
                    f.putpixel((x, y), hexc("#1e3f6a") if d > 0.5 else hexc("#3a7ac0"))
        if squash:
            f.alpha_composite(actions.squash(idle, squash))
        if i >= 3:
            for x, y in ((int(cx) - 3, FEET - 1), (int(cx) + 2, FEET), (int(cx) - 1, FEET + 1)):
                f.putpixel((x, y), hexc("#3b5a45"))
            f.putpixel((int(cx) + 1, FEET - 1), hexc("#7ac0f0"))
        frames.append(f)
    return frames


def imp_death(idle):
    """A flash, then the body breaks into embers that rise and go out."""
    body = actions.body_only(idle)
    pts = [(x, y) for y in range(F) for x in range(F) if body.getpixel((x, y))[3]]
    rnd = random.Random(3)
    sparks = rnd.sample(pts, min(28, len(pts)))
    frames = [actions.recolor(idle, hexc("#ffd860"))]
    for step in range(1, 5):
        f = Image.new("RGBA", (F, F))
        keep = 1.0 - step * 0.22
        for i, (x, y) in enumerate(sparks):
            if i / len(sparks) > keep:
                continue
            nx = x + rnd.choice((-1, 0, 1)) * step // 2
            ny = y - step * (1 + i % 3)
            if 0 <= nx < F and 0 <= ny < F - 1:
                f.putpixel((nx, ny), hexc(("#ffd860", "#e09a20", "#e85a3a", "#a82a30")[min(3, step - 1 + i % 2)]))
        if step == 1:
            f.alpha_composite(actions.squash(actions.recolor(idle, hexc("#a82a30")), 0.5))
        frames.append(f)
    return frames


def main():
    rot_dir = sys.argv[1]
    zips = dict(a.split("=", 1) for a in sys.argv[2:])
    actions.F = F
    for name, (key, key2, idle_a, walk_a, attack_a, lift) in ACTORS.items():
        std, big = load(zips[key]), load(zips[key2])
        for direction, short in DIRS.items():
            rot = Image.open(os.path.join(rot_dir, f"{ROT[name]}_rot_{short}.png")).convert("RGBA")
            target = body_box(rot)[3] - body_box(rot)[1] + 1
            idle_src = find(std, idle_a, direction)
            scale = target / source_height(idle_src)
            idle = place(idle_src, rot, scale, lift)
            walk = place(find(std, walk_a, direction), rot, scale, lift)
            big_frames = find(big, attack_a, direction)
            attack = place(big_frames, rot, 0.5, lift)       # 2x art: every second pixel
            if name == "ember_imp":
                idle = [flicker(bob(f, d), i % 2) for i, (f, d) in enumerate(zip(idle, (0, 1, 1, 0)))]
                walk = [flicker(f, i % 2) for i, f in enumerate(walk)]
                attack = [fireball_in_hands(f, r) if r else f for f, r in zip(attack, (1.5, 2.2, 2.8, 0, 0, 0))]
            actions.strip(idle, os.path.join(SRC, f"{name}_idle_{short}.png"))
            actions.strip(walk, os.path.join(SRC, f"{name}_walk_{short}.png"))
            actions.strip(attack, os.path.join(SRC, f"{name}_attack_{short}.png"))
            actions.strip(actions.hurt(idle[0], short), os.path.join(SRC, f"{name}_hurt_{short}.png"))
        down = actions.frame(os.path.join(SRC, f"{name}_idle_down.png"))
        death = drowned_death(down) if name == "drowned" else imp_death(down)
        actions.strip(death, os.path.join(SRC, f"{name}_death.png"))
        actions.write_frames(SRC, name, os.path.join(SRC, f"{name}_frames.tres"))
        print(name, "imported")


if __name__ == "__main__":
    main()
