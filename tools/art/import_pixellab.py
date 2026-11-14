"""Imports a PixelLab character (the ZIP from get_character's download link) into the
game's art layout: idle and walk strips per direction, trimmed onto a square canvas
with the feet on the second-to-last row, snapped to the 32-colour palette of
docs/art-style.md, plus attack, hurt and death made like the player's
(make_action_frames.py) and a <name>_frames.tres.
Usage (from the project root):
    python tools/art/import_pixellab.py <zip> <name> <folder> <canvas> [idle anim] [walk anim]
e.g. python tools/art/import_pixellab.py archer.zip archer assets/art/enemies 24
"""
import io
import json
import os
import sys
import zipfile

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_action_frames as actions  # noqa: E402

PALETTE = """#08070b #0f0e14 #17161f #1f1e29 #2a2935 #343442 #3f4050 #4c4e5f #5d6072 #767a8c
#263a32 #3b5a45 #9aa2ad #d8d4c4 #f4f0e0 #4a2f22 #7a4a2c #b07040 #e0a070 #5a1820 #a82a30 #e85a3a
#8a4a10 #e09a20 #ffd860 #1e3f6a #3a7ac0 #7ac0f0 #4a2a78 #9a5ae0 #2aa8a0 #9af0e0""".split()
COLORS = [tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) for h in PALETTE]
DIRS = {"south": "down", "north": "up", "east": "right", "west": "left"}


def snap(img):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            r, g, b, a = px[x, y]
            if a < 128:
                px[x, y] = (0, 0, 0, 0)
                continue
            best = min(COLORS, key=lambda c: (c[0] - r) ** 2 + (c[1] - g) ** 2 + (c[2] - b) ** 2)
            px[x, y] = best + (255,)
    return out


def load(zip_path):
    z = zipfile.ZipFile(zip_path)
    names = z.namelist()
    frames = {}
    for n in names:
        parts = n.split("/")
        if "animations" in parts and n.endswith(".png"):
            i = parts.index("animations")
            anim, direction = parts[i + 1], parts[i + 2]
            frames.setdefault((anim, direction), []).append((n, Image.open(io.BytesIO(z.read(n))).convert("RGBA")))
        elif "rotations" in parts and n.endswith(".png"):
            direction = parts[-1][:-4]
            frames.setdefault(("rotation", direction), []).append((n, Image.open(io.BytesIO(z.read(n))).convert("RGBA")))
    return {k: [img for _, img in sorted(v)] for k, v in frames.items()}


def fit(frames, canvas):
    """One shared box for the strip (no jitter), centred, feet on row canvas - 2."""
    box = None
    for f in frames:
        b = f.getbbox()
        if b:
            box = b if box is None else (min(box[0], b[0]), min(box[1], b[1]), max(box[2], b[2]), max(box[3], b[3]))
    out = []
    for f in frames:
        part = f.crop(box)
        if part.width > canvas or part.height > canvas - 1:
            scale = min(canvas / part.width, (canvas - 1) / part.height)
            part = part.resize((max(1, int(part.width * scale)), max(1, int(part.height * scale))), Image.NEAREST)
        cell = Image.new("RGBA", (canvas, canvas))
        cell.paste(part, ((canvas - part.width) // 2, canvas - 1 - part.height))
        out.append(snap(cell))
    return out


def match(frames, key):
    for (anim, direction), imgs in frames.items():
        if key in anim:
            yield anim, direction, imgs


def main():
    zip_path, name, folder, canvas = sys.argv[1], sys.argv[2], sys.argv[3], int(sys.argv[4])
    idle_key = sys.argv[5] if len(sys.argv) > 5 else "idle"
    walk_key = sys.argv[6] if len(sys.argv) > 6 else "walk"
    frames = load(zip_path)
    actions.F = canvas
    made = []
    for kind, key in (("idle", idle_key), ("walk", walk_key)):
        for anim, direction, imgs in match(frames, key):
            if direction not in DIRS:
                continue
            strip = fit(imgs, canvas)
            path = os.path.join(folder, f"{name}_{kind}_{DIRS[direction]}.png")
            actions.strip(strip, path)
            made.append(path)
    # Directions without an idle animation fall back to the rotation picture.
    for direction, short in DIRS.items():
        path = os.path.join(folder, f"{name}_idle_{short}.png")
        if not os.path.exists(path) and ("rotation", direction) in frames:
            actions.strip(fit(frames[("rotation", direction)], canvas), path)
    for short in DIRS.values():
        idle = actions.frame(os.path.join(folder, f"{name}_idle_{short}.png"))
        actions.strip(actions.attack(idle, short), os.path.join(folder, f"{name}_attack_{short}.png"))
        actions.strip(actions.hurt(idle, short), os.path.join(folder, f"{name}_hurt_{short}.png"))
    down = actions.frame(os.path.join(folder, f"{name}_idle_down.png"))
    actions.strip([actions.recolor(down, actions.WHITE), actions.squash(down, 0.7), actions.squash(down, 0.4),
                   actions.squash(down, 0.2)], os.path.join(folder, f"{name}_death.png"))
    actions.write_frames(folder, name, os.path.join(folder, f"{name}_frames.tres"))
    print(json.dumps({"name": name, "strips": len(made)}))


if __name__ == "__main__":
    main()
