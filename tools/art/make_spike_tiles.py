"""Spike sprites (16x16, palette of docs/art-style.md).
Sharp cones that sit inside the floor tile: a slab in the floor's own colours (no
frame), four small spikes with a margin from the tile edges, muted steel (lit left
face, shaded right face, pale tip) and no outline, like every other tile.
Static spikes: slot 1 of assets/art/tiles/ruins_hazards.png (always raised).
Retractable spikes: strips assets/art/tiles/spikes_timed_<state>.png for the states
hidden, warn, rise, up, retract, and assets/art/tiles/spikes_timed_frames.tres with
animations of the same names (loop: hidden, warn, up).
Run from the project root: python tools/art/make_spike_tiles.py
"""
from PIL import Image

T = 16
COL = {
    "o": "#08070b", "k": "#17161f", "s": "#2a2935", "f": "#343442", "F": "#3f4050",
    "e": "#4c4e5f", "t": "#5d6072", "g": "#9aa2ad", "G": "#d8d4c4", "W": "#f4f0e0",
}
# Base centre (x, y) of each spike; the back row first, so the front row covers it.
SLOTS = [(4, 5), (11, 5), (7, 9), (4, 13), (11, 13)]
FULL = 3
# Half-width of a spike at its base: 1 = three pixels wide, a slim blade.


def rgb(key):
    h = COL[key]
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def plate(dx=0):
    """A stone slab a bit lighter than the floor, with a dark slit under every spike."""
    img = Image.new("RGBA", (T, T))
    for y in range(T):
        for x in range(T):
            # The floor's base with a faint seam around the slab, nothing brighter.
            seam = x in (1, T - 2) or y in (1, T - 2)
            key = "s" if seam else "f"
            img.putpixel((x, y), rgb(key))
    px = img.load()
    for cx, by in SLOTS:
        for x in range(cx - 1 + dx, cx + 2 + dx):
            if 1 <= x < T - 1 and 1 <= by < T - 1:
                px[x, by] = rgb("k")
    return img


def cone(img, cx, by, height):
    """A squat pyramid growing up from (cx, by), seen from above at 3/4: a lit left
    face, a dark right face and a grey ridge up the middle to the point. Its base is
    2 * height - 1 pixels wide, so the whole field stays inside the tile."""
    if height <= 0:
        return
    px = img.load()
    for h in range(height):
        y = by - h
        half = height - 1 - h
        for x in range(cx - half, cx + half + 1):
            if 0 <= x < T and 0 <= y < T:
                px[x, y] = rgb("g" if x == cx else ("t" if x < cx else "e"))
    if 0 <= by - height < T:
        px[cx, by - height] = rgb("g")
    # A small shadow at the base on the right (light from the top-left).
    if 0 <= cx + height < T and 0 <= by < T:
        px[cx + height, by] = rgb("k")


def raised(height):
    img = plate()
    for cx, by in SLOTS:
        cone(img, cx, by, height)
    return img


def warn(frame):
    """The plate trembles; steel points glint in the slits."""
    img = plate(dx=frame % 2)
    px = img.load()
    for i, (cx, by) in enumerate(SLOTS):
        if (i + frame) % 2 == 0:
            px[cx + frame % 2, by] = rgb("g")
            px[cx - 1 + frame % 2, by] = rgb("t")
    return img


STATES = {
    "hidden": ([plate()], 2.0, True),
    "warn": ([warn(i) for i in range(4)], 12.0, True),
    "rise": ([raised(1), raised(2)], 20.0, False),
    "up": ([raised(FULL), raised(FULL)], 4.0, True),
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
atlas.paste(raised(FULL), (T, 0))
atlas.save("assets/art/tiles/ruins_hazards.png")
print("spikes written")
