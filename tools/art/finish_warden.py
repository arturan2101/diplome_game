"""New boss "Ruins Warden" (batch 10, group 4): a living marble statue, a hulking
colossus with a gold crown helmet, purple eyes and glowing cracks, a round stone shield
with a purple rune on its left forearm and a torn red sash. No weapon: it fights with
the shield and its fists. It replaces the Guardian of the Ruins.

PixelLab character 601be13f-5f28-4841-99d1-ce60ca3f1344 "ruins_warden_boss_v3" (v3, 96 px,
high top-down). Animations in the ZIP (get_character download link) and what they become:
    idle            template breathing-idle (south/east/north)    -> idle_<dir>     4 frames
    idle_sk         skeleton-v3 move breathe_heavy, west only (the template lost the shield)
    walk            template walking-6-frames (south/east/north)  -> walk_<dir>     6 frames
    walk_v3         v3 walk, west only (the template lost the shield there)
    attack_slam_sk2 skeleton-v3 poses: shield and fist overhead, held, then slammed
                    into the ground                               -> slam_<dir>     8 frames
    attack_throw    skeleton-v3 poses: picks up a boulder, cocks it behind the head,
                    hurls it; frames 0-4 kept                     -> throw_<dir>    5 frames
    attack_wave     skeleton-v3 poses: arms spread wide, knee up, stomp
                                                                  -> wave_<dir>     8 frames
    summon          skeleton-v3 poses: fist raised to the sky, trembling
                                                                  -> summon_<dir>   6 frames
    roar            skeleton-v3 move power_up (phase 2)           -> roar_<dir>     8 frames
    hurt_sk         skeleton-v3 move hit                          -> hurt_<dir>     4 frames
    death           skeleton-v3 move fall_forward, south only     -> death          8 frames

Canvas 96x96 per frame, not 64x64: the body is about 52 px tall (close to the 52x56 of the style
guide, scale 0.6) and the raised shield and the spread arms of the wind-ups need the room above and
beside it; at 64x64 they would be cut off, or the boss would shrink to golem size.
Feet centre at (48, 92) in every frame of every strip (the lowest pixel of each frame
is on row 92); shadow ellipse rows 91-93.

Steps, from the project root:
    python tools/art/finish_warden.py <zip>
This script scales every frame by SCALE (box filter), snaps it to the palette of
docs/art-style.md, gives it back its 1 px #08070b outline, puts a #0f0e14 shadow under
the feet, aligns each strip's feet with the idle of the same direction and writes
assets/art/enemies/warden_<anim>_<dir>.png plus warden_frames.tres.
"""
import glob
import io
import os
import sys
import zipfile

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from import_pixellab import snap  # noqa: E402
from import_player_actions import feet  # noqa: E402

F = 96
SCALE = 0.6
FEET_X, FEET_Y = 48, 92
SRC = "assets/art/enemies"
NAME = "warden"
OUTLINE = (8, 7, 11, 255)
SHADOW = (15, 14, 20, 255)
DARK = {(8, 7, 11), (15, 14, 20), (23, 22, 31)}
DIRS = {"south": "down", "east": "right", "north": "up", "west": "left"}
SHADOW_RX = {"down": 17, "up": 17, "right": 12, "left": 12}

# game animation -> PixelLab animation name (per direction where it differs)
ANIMS = {
    "idle": {"south": "idle", "east": "idle", "north": "idle", "west": "idle_sk"},
    "walk": {"south": "walk", "east": "walk", "north": "walk", "west": "walk_v3"},
    "slam": "attack_slam_sk2",
    "throw": "attack_throw",
    "wave": "attack_wave",
    "summon": "summon",
    "roar": "roar",
    "hurt": "hurt_sk",
}
FPS = {"idle": 6.0, "walk": 10.0, "slam": 10.0, "throw": 10.0, "wave": 10.0, "summon": 8.0,
       "roar": 10.0, "hurt": 12.0, "death": 10.0}
LOOP = {"idle", "walk"}
# Frames kept per animation (the rest dropped): the boulder of the throw lands at the
# boss's feet in the last three frames, so the strip ends at the release.
KEEP = {"throw": slice(0, 5)}


def load(zip_path):
    z = zipfile.ZipFile(zip_path)
    out = {}
    for n in sorted(z.namelist()):
        parts = n.split("/")
        if "animations" in parts and n.endswith(".png"):
            i = parts.index("animations")
            out.setdefault((parts[i + 1], parts[i + 2]), []).append(
                Image.open(io.BytesIO(z.read(n))).convert("RGBA"))
    return out


def shrink(img):
    w, h = round(img.width * SCALE), round(img.height * SCALE)
    small = snap(img.resize((w, h), Image.BOX))
    return outline(small)


def outline(img):
    """1 px outline outside the figure where its edge is not dark already."""
    px = img.load()
    out = img.copy()
    opx = out.load()
    for y in range(img.height):
        for x in range(img.width):
            if px[x, y][3]:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                nx, ny = x + dx, y + dy
                if 0 <= nx < img.width and 0 <= ny < img.height and px[nx, ny][3] and px[nx, ny][:3] not in DARK:
                    opx[x, y] = OUTLINE
                    break
    return out


def shadow_layer(short):
    img = Image.new("RGBA", (F, F))
    rx, ry = SHADOW_RX[short], 1.6
    for y in range(F):
        for x in range(F):
            if ((x + 0.5 - FEET_X) / rx) ** 2 + ((y + 0.5 - FEET_Y) / ry) ** 2 <= 1:
                img.putpixel((x, y), SHADOW)
    return img


def place(frames, short):
    """Shrink; move the strip sideways so frame 0's feet are on FEET_X (a lunge still
    moves), and every frame up or down so its lowest pixel is on FEET_Y: PixelLab keeps
    the hips in place, so in a crouch the feet would sink below the floor."""
    small = [shrink(f) for f in frames]
    cx, _ = feet(small[0])
    dx = int(round(FEET_X - cx))
    # If the widest frame would leave the canvas (arms spread with the shield), shift
    # the whole strip back inside, keeping 1 px for the outline.
    left = min(f.getbbox()[0] for f in small) + dx
    right = max(f.getbbox()[2] for f in small) + dx
    if left < 1:
        dx += 1 - left
    elif right > F - 1:
        dx -= right - (F - 1)
    base = shadow_layer(short)
    out = Image.new("RGBA", (F * len(small), F))
    for i, f in enumerate(small):
        cell = base.copy()
        _paste_any(cell, f, dx, FEET_Y - (f.getbbox()[3] - 1))
        out.paste(cell, (i * F, 0))
    return out


def _paste_any(cell, f, dx, dy):
    """alpha_composite with a negative offset: crop the source first."""
    sx, sy = max(0, -dx), max(0, -dy)
    part = f.crop((sx, sy, f.width, f.height))
    cell.alpha_composite(part, (max(0, dx), max(0, dy)))


def write_frames():
    entries = []
    for path in sorted(glob.glob(os.path.join(SRC, f"{NAME}_*.png"))):
        anim = os.path.basename(path)[len(NAME) + 1:-4]
        kind = anim.split("_")[0]
        if kind not in FPS:
            continue
        entries.append((anim, os.path.basename(path), Image.open(path).width // F))
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(entries) + sum(c for _, _, c in entries)} format=3]', ""]
    for anim, name, _ in entries:
        lines.append(f'[ext_resource type="Texture2D" path="res://{SRC}/{name}" id="{anim}"]')
    lines.append("")
    for anim, _, count in entries:
        for i in range(count):
            lines += [f'[sub_resource type="AtlasTexture" id="{anim}_{i}"]', f'atlas = ExtResource("{anim}")',
                      f"region = Rect2({i * F}, 0, {F}, {F})", ""]
    blocks = []
    for anim, _, count in entries:
        kind = anim.split("_")[0]
        frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (anim, i) for i in range(count))
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                      % (frames, "true" if kind in LOOP else "false", anim, FPS[kind]))
    lines += ["[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    with open(os.path.join(SRC, f"{NAME}_frames.tres"), "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines))


def main():
    anims = load(sys.argv[1])
    for game, source in ANIMS.items():
        for direction, short in DIRS.items():
            name = source[direction] if isinstance(source, dict) else source
            frames = anims.get((name, direction))
            if not frames:
                print("missing", name, direction)
                continue
            place(frames[KEEP.get(game, slice(None))], short).save(os.path.join(SRC, f"{NAME}_{game}_{short}.png"))
    if ("death", "south") in anims:
        place(anims[("death", "south")], "down").save(os.path.join(SRC, f"{NAME}_death.png"))
    else:
        print("missing death")
    write_frames()
    print("warden finished")


if __name__ == "__main__":
    main()
