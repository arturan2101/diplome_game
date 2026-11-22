"""Builds assets/art/fx/boss_fx_frames.tres (stage 45): the SpriteFrames of the elemental
Wardens' floor effects from the batch 15 strips, for their ZoneData (SpellZone plays
them). Animations:
  tide_puddle  - tide_puddle.png, 32x32 x 4, loop 6 fps (the water orb's puddle)
  lava_crack   - lava_crack_pool.png frames 0-3, 32x32, loop 6 fps (slam and boulder)
  geyser_warn  - geyser_warn.png, 16x16 x 4, loop 8 fps (ripples before a geyser)
  geyser       - geyser.png, 16x32 x 6, once 12 fps (the water column)
Usage: python tools/art/make_boss_fx_frames.py
"""

OUT = "assets/art/fx/boss_fx_frames.tres"
# name, file, frame width, height, first frame, count, fps, loop
ANIMS = [
    ("tide_puddle", "tide_puddle.png", 32, 32, 0, 4, 6.0, True),
    ("lava_crack", "lava_crack_pool.png", 32, 32, 0, 4, 6.0, True),
    ("geyser_warn", "geyser_warn.png", 16, 16, 0, 4, 8.0, True),
    ("geyser", "geyser.png", 16, 32, 0, 6, 12.0, False),
]

ext = []
subs = []
anims = []
for name, file, w, h, first, count, fps, loop in ANIMS:
    ext.append(f'[ext_resource type="Texture2D" path="res://assets/art/fx/{file}" id="{name}"]')
    frames = []
    for i in range(count):
        sid = f"{name}_{i}"
        subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{name}")\nregion = Rect2({(first + i) * w}, 0, {w}, {h})\n')
        frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
    anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (", ".join(frames), "true" if loop else "false", name, fps))

steps = len(ext) + len(subs) + 1
text = f'[gd_resource type="SpriteFrames" load_steps={steps} format=3]\n\n' + "\n".join(ext) + "\n\n" + "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n"
open(OUT, "w", encoding="utf-8", newline="\n").write(text)
print("wrote", OUT)
