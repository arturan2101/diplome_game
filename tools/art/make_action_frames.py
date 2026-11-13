"""Builds attack, hurt and death strips for the player and the skeleton from their
idle frames, then rewrites their SpriteFrames .tres from every strip in the folder.
Strip files: <actor>_<anim>_<dir>.png or <actor>_<anim>.png, 24x24 frames side by side.
Only palette colors of docs/art-style.md are used. Run from the project root:
    python tools/art/make_action_frames.py
"""
import glob
import os
import re

from PIL import Image

F = 24
DIRS = ["down", "up", "left", "right"]
STEP = {"down": (0, 1), "up": (0, -1), "left": (-1, 0), "right": (1, 0)}
OUTLINE = (8, 7, 11, 255)
SHADOW = (15, 14, 20, 255)
WHITE = (244, 240, 224, 255)
BONE = (216, 212, 196, 255)
BONE_SH = (154, 162, 173, 255)
STEEL = (154, 162, 173, 255)
RED = (168, 42, 48, 255)
# Frames per second of each new animation; loop only idle and walk.
FPS = {"attack": 12, "hurt": 12, "death": 10}


def frame(path, index=0):
    img = Image.open(path).convert("RGBA")
    return img.crop((index * F, 0, index * F + F, F))


def body_only(img):
    """The frame without its drop shadow row (it stays on the ground)."""
    out = img.copy()
    px = out.load()
    for y in range(F):
        for x in range(F):
            if px[x, y] == SHADOW:
                px[x, y] = (0, 0, 0, 0)
    return out


def shadow_of(img):
    out = Image.new("RGBA", (F, F))
    px, src = out.load(), img.load()
    for y in range(F):
        for x in range(F):
            if src[x, y] == SHADOW:
                px[x, y] = SHADOW
    return out


def move(img, dx, dy):
    body = body_only(img).transform((F, F), Image.AFFINE, (1, 0, -dx, 0, 1, -dy))
    out = shadow_of(img)
    out.alpha_composite(body)
    return out


def recolor(img, color):
    """Solid silhouette (keeps the outline): the hit frame."""
    out = img.copy()
    px = out.load()
    for y in range(F):
        for x in range(F):
            if px[x, y][3] and px[x, y] not in (OUTLINE, SHADOW):
                px[x, y] = color
    return out


def slash(img, direction, reach):
    """A short steel streak in front of the body: the swing."""
    out = img.copy()
    px = out.load()
    sx, sy = STEP[direction]
    cx, cy = 12 + sx * 6, 15 + sy * 5
    for i in range(-reach, reach + 1):
        x, y = (cx + i, cy) if sy else (cx, cy + i)
        x += sx * (reach - abs(i)) // 2
        y += sy * (reach - abs(i)) // 2
        if 0 <= x < F and 0 <= y < F - 1:
            px[x, y] = WHITE if abs(i) < reach else STEEL
    return out


def attack(idle, direction):
    sx, sy = STEP[direction]
    wind = move(idle, -sx, -sy)          # lean back: the windup
    hold = move(idle, -sx, -sy - 1 if sy == 0 else -sy)
    hit = slash(move(idle, sx * 2, sy * 2), direction, 3)
    follow = slash(move(idle, sx, sy), direction, 2)
    return [wind, hold, hit, follow]


def hurt(idle, direction):
    sx, sy = STEP[direction]
    return [recolor(move(idle, -sx, -sy), WHITE), move(idle, -sx, -sy)]


def squash(img, factor):
    """Body pressed down towards the feet line (row 22)."""
    body = body_only(img)
    box = body.getbbox()
    if box is None:
        return img
    part = body.crop(box)
    h = max(2, int(part.height * factor))
    part = part.resize((part.width, h), Image.NEAREST)
    out = shadow_of(img)
    out.alpha_composite(part, (box[0], box[3] - h))
    return out


def bone_pile():
    """The last death frame of the skeleton: a heap of bones with the skull on top."""
    out = Image.new("RGBA", (F, F))
    px = out.load()
    rows = {
        17: "......oSSo......",
        18: ".....oWWWBo.....",
        19: "...ooWoBWWoBo...",
        20: "..oBWWBBoWWWBo..",
        21: ".oWWBoWWBBoBWWo.",
        22: ".ooooooooooooooo",
        23: "..ssssssssssss..",
    }
    colors = {"o": OUTLINE, "W": WHITE, "B": BONE, "S": BONE_SH, "s": SHADOW}
    for y, row in rows.items():
        for x, key in enumerate(row):
            if key in colors:
                px[x + 4, y] = colors[key]
    # skull: two eye sockets on the top of the pile
    for x, y, c in [(10, 16, OUTLINE), (11, 16, OUTLINE), (12, 16, OUTLINE), (10, 17, WHITE), (11, 17, OUTLINE),
                    (12, 17, WHITE), (13, 17, OUTLINE), (9, 17, OUTLINE), (13, 16, OUTLINE)]:
        px[x, y] = c
    return out


def skeleton_death(idle):
    return [recolor(idle, WHITE), squash(idle, 0.75), squash(idle, 0.5), squash(idle, 0.3), bone_pile(), bone_pile()]


def player_death(idle):
    """Kneels, then lies on the ground (rotated body), the red scarf on top."""
    lying = body_only(idle).rotate(-90, resample=Image.NEAREST)
    box = lying.getbbox()
    out = shadow_of(idle)
    if box:
        part = lying.crop(box)
        out.alpha_composite(part, ((F - part.width) // 2, 22 - part.height))
    return [recolor(idle, WHITE), squash(idle, 0.8), squash(idle, 0.6), out]


def strip(frames, path):
    img = Image.new("RGBA", (F * len(frames), F))
    for i, f in enumerate(frames):
        img.paste(f, (i * F, 0))
    img.save(path)


def write_frames(folder, actor, res_path):
    """SpriteFrames .tres with every <actor>_*.png strip in the folder."""
    files = sorted(glob.glob(os.path.join(folder, f"{actor}_*.png")))
    entries = []
    for path in files:
        anim = os.path.basename(path)[len(actor) + 1:-4]
        if not re.match(r"^(idle|walk|attack|hurt|death)(_[a-z]+)?$", anim):
            continue
        count = Image.open(path).width // F
        entries.append((anim, os.path.basename(path), count))
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(entries) + sum(c for _, _, c in entries)} format=3]', ""]
    for anim, name, _ in entries:
        lines.append(f'[ext_resource type="Texture2D" path="res://{folder}/{name}" id="{anim}"]')
    lines.append("")
    for anim, _, count in entries:
        for i in range(count):
            lines += [f'[sub_resource type="AtlasTexture" id="{anim}_{i}"]', f'atlas = ExtResource("{anim}")',
                      f"region = Rect2({i * F}, 0, {F}, {F})", ""]
    blocks = []
    for anim, _, count in entries:
        kind = anim.split("_")[0]
        frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (anim, i) for i in range(count))
        loop = "true" if kind in ("idle", "walk") else "false"
        speed = {"idle": 6.0, "walk": 10.0}.get(kind, float(FPS.get(kind, 10)))
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (frames, loop, anim, speed))
    lines += ["[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    with open(res_path, "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines))


def build(folder, actor, death):
    for d in DIRS:
        idle = frame(os.path.join(folder, f"{actor}_idle_{d}.png"))
        strip(attack(idle, d), os.path.join(folder, f"{actor}_attack_{d}.png"))
        strip(hurt(idle, d), os.path.join(folder, f"{actor}_hurt_{d}.png"))
    strip(death(frame(os.path.join(folder, f"{actor}_idle_down.png"))), os.path.join(folder, f"{actor}_death.png"))
    write_frames(folder, actor, os.path.join(folder, f"{actor}_frames.tres"))


if __name__ == "__main__":
    build("assets/art/enemies", "skeleton", skeleton_death)
    build("assets/art/characters", "player", player_death)
    print("action frames written")
