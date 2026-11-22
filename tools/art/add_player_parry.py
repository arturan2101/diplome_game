"""Adds the parry pose (batch 14, player_parry_<dir>.png: 3 frames of 24x24) to
assets/art/characters/player_frames.tres as parry_<dir> animations (12 fps, once).
Stage 44. Safe to run twice: it does nothing when the animations are already there.
Usage: python tools/art/add_player_parry.py
"""
import re

PATH = "assets/art/characters/player_frames.tres"
DIRS = ["down", "left", "right", "up"]
FRAMES = 3
SIZE = 24
FPS = 12.0

text = open(PATH, encoding="utf-8").read()
if '"name": &"parry_down"' in text:
    print("already there")
    raise SystemExit(0)
ext = "".join(f'[ext_resource type="Texture2D" path="res://assets/art/characters/player_parry_{d}.png" id="parry_{d}"]\n' for d in DIRS)
subs = ""
for d in DIRS:
    for i in range(FRAMES):
        subs += f'[sub_resource type="AtlasTexture" id="parry_{d}_{i}"]\natlas = ExtResource("parry_{d}")\nregion = Rect2({i * SIZE}, 0, {SIZE}, {SIZE})\n\n'
anims = ""
for d in DIRS:
    frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("parry_%s_%d")\n}' % (d, i) for i in range(FRAMES))
    anims += ', {\n"frames": [%s],\n"loop": false,\n"name": &"parry_%s",\n"speed": %s\n}' % (frames, d, FPS)
first_sub = text.index("[sub_resource")
text = text[:first_sub] + ext + "\n" + text[first_sub:]
res = text.index("[resource]")
text = text[:res] + subs + text[res:]
assert text.rstrip().endswith("}]")
text = text.rstrip()[:-1] + anims + "]\n"
steps = int(re.search(r"load_steps=(\d+)", text).group(1))
text = re.sub(r"load_steps=\d+", f"load_steps={steps + len(DIRS) * (FRAMES + 1)}", text, count=1)
open(PATH, "w", encoding="utf-8", newline="\n").write(text)
print("added parry_<dir>")
