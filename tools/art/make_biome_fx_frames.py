"""Builds assets/art/fx/biome_fx_frames.tres (stage 48): the SpriteFrames of the floor
effects of the batch 15 floor styles (parts 3-5), for their ZoneData (SpellZone plays
them) and the fungal puffball (SporePuff). Animations:
  spore_cloud        - fx/spore_cloud.png, 32x32 x 6, loop 8 fps (centre 16, 16)
  spore_puff_breathe - level/spore_puff.png frames 0-3, 16x16, loop 4 fps
  spore_puff_burst   - level/spore_puff.png frames 4-9, 16x16, once 12 fps
                       (release on its frame 1 = strip frame 5)
  root_warn          - fx/root_warn.png, 16x16 x 4, loop 8 fps (centre 8, 9)
  root_spike         - fx/root_spike.png, 16x24 x 6, once 12 fps (bottom row 23)
Usage: python tools/art/make_biome_fx_frames.py
"""

OUT = "assets/art/fx/biome_fx_frames.tres"
# name, file (under assets/art), frame width, height, first frame, count, fps, loop
ANIMS = [
    ("spore_cloud", "fx/spore_cloud.png", 32, 32, 0, 6, 8.0, True),
    ("spore_puff_breathe", "level/spore_puff.png", 16, 16, 0, 4, 4.0, True),
    ("spore_puff_burst", "level/spore_puff.png", 16, 16, 4, 6, 12.0, False),
    ("root_warn", "fx/root_warn.png", 16, 16, 0, 4, 8.0, True),
    ("root_spike", "fx/root_spike.png", 16, 24, 0, 6, 12.0, False),
]

ext = {}
subs = []
anims = []
for name, file, w, h, first, count, fps, loop in ANIMS:
    if file not in ext:
        ext[file] = f"tex{len(ext)}"
    frames = []
    for i in range(count):
        sid = f"{name}_{i}"
        subs.append(f'[sub_resource type="AtlasTexture" id="{sid}"]\natlas = ExtResource("{ext[file]}")\nregion = Rect2({(first + i) * w}, 0, {w}, {h})\n')
        frames.append('{\n"duration": 1.0,\n"texture": SubResource("%s")\n}' % sid)
    anims.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (", ".join(frames), "true" if loop else "false", name, fps))

ext_lines = [f'[ext_resource type="Texture2D" path="res://assets/art/{file}" id="{rid}"]' for file, rid in ext.items()]
steps = len(ext_lines) + len(subs) + 1
text = f'[gd_resource type="SpriteFrames" load_steps={steps} format=3]\n\n' + "\n".join(ext_lines) + "\n\n" + "\n".join(subs) + "\n[resource]\nanimations = [" + ", ".join(anims) + "]\n"
open(OUT, "w", encoding="utf-8", newline="\n").write(text)
print("wrote", OUT)
