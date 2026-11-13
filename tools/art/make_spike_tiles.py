"""Spike sprites (16x16, palette of docs/art-style.md).
Static spikes: slot 1 of assets/art/tiles/ruins_hazards.png (always raised).
Retractable spikes: strips assets/art/tiles/spikes_timed_<state>.png for the states
hidden, warn, rise, up, retract, and assets/art/tiles/spikes_timed_frames.tres with
animations of the same names (loop: hidden, warn, up).
Run from the project root: python tools/art/make_spike_tiles.py
"""
from PIL import Image

T = 16
COL = {
    ".": None, "o": "#08070b", "k": "#17161f", "s": "#2a2935", "f": "#343442", "F": "#3f4050",
    "e": "#4c4e5f", "g": "#9aa2ad", "G": "#d8d4c4", "W": "#f4f0e0", "r": "#5a1820",
}
# The plate: a square stone slab with four slots, a bit lighter than the floor.
PLATE = [
    "ssssssssssssssss",
    "seeeeeeeeeeeeees",
    "seFFFFFFFFFFFFfs",
    "seFkkFFFFFkkFFfs",
    "seFFFFFFFFFFFFfs",
    "seFFFFFFFFFFFFfs",
    "seFFFkkFFkkFFFfs",
    "seFFFFFFFFFFFFfs",
    "seFFFFFFFFFFFFfs",
    "seFkkFFFFFkkFFfs",
    "seFFFFFFFFFFFFfs",
    "seFFFFFFFFFFFFfs",
    "seFFFkkFFkkFFFfs",
    "seFFFFFFFFFFFFfs",
    "sfffffffffffffss",
    "ssssssssssssssss",
]
SLOTS = [(3, 3), (10, 3), (5, 6), (9, 6), (3, 9), (10, 9), (5, 12), (9, 12)]


def plate(dx=0, dy=0):
    img = Image.new("RGBA", (T, T))
    for y, row in enumerate(PLATE):
        for x, key in enumerate(row):
            sx, sy = x - dx, y - dy
            src = PLATE[sy][sx] if 0 <= sx < T and 0 <= sy < T else "s"
            if COL[src]:
                img.putpixel((x, y), rgb(COL[src]))
    return img


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def spike(img, x, y, height, tip="W"):
    """A steel spike growing up from a slot at (x, y): tip, shaft and outline."""
    for h in range(height):
        yy = y - h
        if yy < 0:
            break
        top = h == height - 1
        img.putpixel((x, yy), rgb(COL[tip] if top else COL["g"]))
        img.putpixel((x + 1, yy), rgb(COL["G"] if top else COL["e"]))
    if y - height >= 0:
        img.putpixel((x, y - height), rgb(COL["o"]))
        img.putpixel((x + 1, y - height), rgb(COL["o"]))


def raised(height):
    img = plate()
    for x, y in SLOTS:
        spike(img, x, y, height)
    return img


def glint(frame):
    """Warning: the plate trembles and steel glints in the slots."""
    img = plate(dx=frame % 2, dy=0)
    for i, (x, y) in enumerate(SLOTS):
        if (i + frame) % 2 == 0:
            img.putpixel((x, y), rgb(COL["W"]))
            img.putpixel((x + 1, y), rgb(COL["g"]))
    return img


STATES = {
    "hidden": ([plate()], 2.0, True),
    "warn": ([glint(i) for i in range(4)], 12.0, True),
    "rise": ([raised(1), raised(2)], 20.0, False),
    "up": ([raised(3), raised(3)], 4.0, True),
    "retract": ([raised(2), raised(1), plate()], 15.0, False),
}


def strip(frames, path):
    img = Image.new("RGBA", (T * len(frames), T))
    for i, f in enumerate(frames):
        img.paste(f, (i * T, 0))
    img.save(path)


def write_frames(path):
    names = list(STATES)
    total = sum(len(STATES[n][0]) for n in names)
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(names) + total} format=3]', ""]
    for n in names:
        lines.append(f'[ext_resource type="Texture2D" path="res://assets/art/tiles/spikes_timed_{n}.png" id="{n}"]')
    lines.append("")
    for n in names:
        for i in range(len(STATES[n][0])):
            lines += [f'[sub_resource type="AtlasTexture" id="{n}_{i}"]', f'atlas = ExtResource("{n}")',
                      f"region = Rect2({i * T}, 0, {T}, {T})", ""]
    blocks = []
    for n in names:
        frames, speed, loop = STATES[n]
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (n, i) for i in range(len(frames)))
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}' % (fr, "true" if loop else "false", n, speed))
    lines += ["[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines))


for name, (frames, _, _) in STATES.items():
    strip(frames, f"assets/art/tiles/spikes_timed_{name}.png")
write_frames("assets/art/tiles/spikes_timed_frames.tres")
atlas = Image.open("assets/art/tiles/ruins_hazards.png").convert("RGBA")
atlas.paste(raised(3), (T, 0))
atlas.save("assets/art/tiles/ruins_hazards.png")
print("spikes written")
