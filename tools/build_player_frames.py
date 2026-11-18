"""Rewrites assets/art/characters/player_frames.tres from every player strip in the
folder: idle, walk, attack, hurt, death and the actions of stage 30 (bow draw, shield
block, dash). Strips are 24x24 frames side by side, named player_<anim>_<dir>.png or
player_<anim>.png. Run from the project root after new strips are added:
    python tools/build_player_frames.py
"""
import glob
import os
import re

from PIL import Image

FOLDER = "assets/art/characters"
ACTOR = "player"
F = 24
# Frames per second and looping of each kind of animation.
SPEED = {"idle": 6.0, "walk": 10.0, "attack": 12.0, "hurt": 12.0, "death": 10.0, "bow": 10.0, "block": 8.0, "dash": 16.0}
LOOPING = {"idle", "walk"}
PATTERN = re.compile(r"^(%s)(_[a-z]+)?$" % "|".join(SPEED))


def main():
    entries = []
    for path in sorted(glob.glob(os.path.join(FOLDER, f"{ACTOR}_*.png"))):
        anim = os.path.basename(path)[len(ACTOR) + 1:-4]
        if not PATTERN.match(anim):
            continue
        entries.append((anim, os.path.basename(path), Image.open(path).width // F))
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(entries) + sum(c for _, _, c in entries)} format=3]', ""]
    for anim, name, _ in entries:
        lines.append(f'[ext_resource type="Texture2D" path="res://{FOLDER}/{name}" id="{anim}"]')
    lines.append("")
    for anim, _, count in entries:
        for i in range(count):
            lines += [f'[sub_resource type="AtlasTexture" id="{anim}_{i}"]', f'atlas = ExtResource("{anim}")',
                      f"region = Rect2({i * F}, 0, {F}, {F})", ""]
    blocks = []
    for anim, _, count in entries:
        kind = anim.split("_")[0]
        frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (anim, i) for i in range(count))
        loop = "true" if kind in LOOPING else "false"
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (frames, loop, anim, SPEED[kind]))
    lines += ["[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    with open(os.path.join(FOLDER, f"{ACTOR}_frames.tres"), "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines))
    print(f"{len(entries)} animations")


if __name__ == "__main__":
    main()
