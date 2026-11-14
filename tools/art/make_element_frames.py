"""Element visuals by level (1-3): bigger, brighter, more particles, and a new detail
on level 3. Palette: docs/art-style.md (fire = red-orange-gold, ice = blues and
bone white, wind = teal). Run from the project root:
    python tools/art/make_element_frames.py
Output (assets/art/fx/):
  fire_l<1-3>.png      fireball in flight, 4 frames of 16x16 (level 3: 24x24 with a flame tail)
  fire_trail.png       level 3 only: burning ground left behind, 4 frames of 16x16
  ice_l<1-3>.png       one ice block of the ice wall, 16x16 (level 3: with a frost rim on the floor)
  wind_l<1-3>.png      the whirlwind ring around the player, 4 frames of 48x48
                       (level 3: stones and leaves carried in the wind)
  element_icons.png    HUD icons 16x16: fire, ice, wind
  level_pips.png       3 small marks (16x4 each) to draw under an icon: level 1, 2, 3
  element_frames.tres  SpriteFrames: fire_l1..3, fire_trail, wind_l1..3
"""
import math
import os

from PIL import Image

OUT = "assets/art/fx"
C = {
    "o": "#08070b", "r": "#5a1820", "R": "#a82a30", "q": "#e85a3a", "Y": "#e09a20", "Z": "#ffd860",
    "W": "#f4f0e0", "b": "#1e3f6a", "B": "#3a7ac0", "L": "#7ac0f0", "w": "#d8d4c4",
    "t": "#2aa8a0", "T": "#9af0e0", "s": "#5d6072", "S": "#9aa2ad", "g": "#3b5a45", "G": "#5a8a4a",
}


def rgb(k):
    h = C[k]
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def put(img, x, y, k):
    if 0 <= x < img.width and 0 <= y < img.height:
        img.putpixel((int(x), int(y)), rgb(k))


def disc(img, cx, cy, r, ramp):
    """A ball shaded from the outside in: ramp = outer ... inner colors."""
    for y in range(img.height):
        for x in range(img.width):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r:
                # light from the top-left: shift the core up and left
                d2 = math.hypot(x + 0.5 - (cx - r * 0.25), y + 0.5 - (cy - r * 0.25))
                i = min(len(ramp) - 1, int((1 - d2 / (r * 1.3)) * len(ramp)))
                put(img, x, y, ramp[max(i, 0)])


# --- fire -------------------------------------------------------------------

def fireball(level, frame):
    size = 24 if level == 3 else 16
    img = Image.new("RGBA", (size, size))
    r = (3.0, 4.0, 5.0)[level - 1]
    cx, cy = size / 2 + 2, size / 2
    ramp = ["r", "R", "q", "Y", "Z"] + (["W"] if level >= 2 else [])
    # flame tongues behind the ball (it flies to the right), flickering per frame
    tongues = 2 + level
    for i in range(tongues):
        y = cy + (i - (tongues - 1) / 2) * 2
        length = r + 2 + (i + frame) % 3 + level
        for k in range(int(length)):
            put(img, cx - r - k, y + ((k + frame + i) % 3 - 1) * 0.5, "q" if k < length / 2 else "R")
    disc(img, cx, cy, r, ramp)
    # sparks: more with every level
    for i in range(level * 2):
        a = (frame * 1.7 + i * 2.4)
        put(img, cx - r - 2 - (i * 3 + frame * 2) % (size // 2), cy + math.sin(a) * (r + 1), "Z" if i % 2 else "Y")
    return img


def fire_trail(frame):
    img = Image.new("RGBA", (16, 16))
    for i in range(6):
        x = 2 + i * 2 + (frame + i) % 2
        h = 2 + (frame + i * 3) % 4
        for k in range(h):
            put(img, x, 14 - k, "Z" if k == h - 1 else ("Y" if k > 1 else "q"))
    for x in range(1, 15):
        put(img, x, 15, "r")
        if (x + frame) % 3 == 0:
            put(img, x, 14, "R")
    return img


# --- ice --------------------------------------------------------------------

def ice_block(level):
    img = Image.new("RGBA", (16, 16))
    top = (5, 3, 1)[level - 1]
    for y in range(top, 15):
        for x in range(2, 14):
            edge = x in (2, 13) or y in (top, 14)
            put(img, x, y, "o" if edge else ("w" if y < top + 2 else ("L" if x < 6 else "B")))
    # cracks and shine: brighter with the level
    for i in range(level + 1):
        put(img, 4 + i * 2, top + 3 + i, "W")
        put(img, 5 + i * 2, top + 4 + i, "w")
    if level >= 2:
        for x, y in ((3, top + 1), (12, top + 2)):
            put(img, x, y, "W")
    if level == 3:
        # frost rim on the floor around the block
        for x in range(0, 16):
            if x % 2 == 0:
                put(img, x, 15, "T" if x % 4 == 0 else "L")
        for x, y in ((0, 13), (15, 12), (1, 10), (14, 9)):
            put(img, x, y, "W")
    return img


# --- wind -------------------------------------------------------------------

def whirlwind(level, frame):
    size = 48
    img = Image.new("RGBA", (size, size))
    c = size / 2
    rings = level + 1
    for ring in range(rings):
        radius = 10 + ring * 4 + level
        arcs = 3 + level
        for a in range(arcs):
            start = (a / arcs) * math.tau + frame * 0.4 + ring * 0.7
            for k in range(10 + level * 2):
                ang = start + k * 0.06
                x = c + math.cos(ang) * radius
                y = c + math.sin(ang) * radius * 0.6   # flattened: on the ground
                put(img, x, y, "T" if k > 6 + level else "t")
    if level == 3:
        # debris carried around: stones and leaves
        for i in range(6):
            ang = frame * 0.5 + i * math.tau / 6
            x = c + math.cos(ang) * (14 + i % 3 * 3)
            y = c + math.sin(ang) * (14 + i % 3 * 3) * 0.6
            k = "S" if i % 2 else "G"
            put(img, x, y, k)
            put(img, x + 1, y, "s" if i % 2 else "g")
    return img


# --- HUD --------------------------------------------------------------------

def icons():
    strip = Image.new("RGBA", (48, 16))
    fire = Image.new("RGBA", (16, 16))
    disc(fire, 8, 9, 5, ["r", "R", "q", "Y", "Z", "W"])
    for k in range(4):
        put(fire, 7 + k % 2, 3 + k, "q")
    ice = ice_block(2)
    wind = whirlwind(1, 0).crop((8, 12, 40, 36)).resize((16, 12), Image.NEAREST)
    wind_icon = Image.new("RGBA", (16, 16))
    wind_icon.paste(wind, (0, 2))
    for i, icon in enumerate((fire, ice, wind_icon)):
        strip.paste(icon, (i * 16, 0))
    return strip


def pips():
    strip = Image.new("RGBA", (48, 4))
    for level in range(1, 4):
        for i in range(3):
            x = (level - 1) * 16 + 2 + i * 5
            k = "Z" if i < level else "s"
            for dx in range(3):
                put(strip, x + dx, 1, k)
                put(strip, x + dx, 2, k)
            put(strip, x - 1, 1, "o")
            put(strip, x + 3, 2, "o")
    return strip


def save_strip(frames, path):
    w, h = frames[0].size
    img = Image.new("RGBA", (w * len(frames), h))
    for i, f in enumerate(frames):
        img.paste(f, (i * w, 0))
    img.save(path)
    return w, h, len(frames)


def frames_tres(entries, path):
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(entries) + sum(e[3] for e in entries)} format=3]', ""]
    for name, file, _, _, _ in entries:
        lines.append(f'[ext_resource type="Texture2D" path="res://{OUT}/{file}" id="{name}"]')
    lines.append("")
    for name, _, (w, h), count, _ in entries:
        for i in range(count):
            lines += [f'[sub_resource type="AtlasTexture" id="{name}_{i}"]', f'atlas = ExtResource("{name}")',
                      f"region = Rect2({i * w}, 0, {w}, {h})", ""]
    blocks = []
    for name, _, _, count, speed in entries:
        fr = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (name, i) for i in range(count))
        blocks.append('{\n"frames": [%s],\n"loop": true,\n"name": &"%s",\n"speed": %s\n}' % (fr, name, speed))
    lines += ["[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    with open(path, "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines))


def main():
    os.makedirs(OUT, exist_ok=True)
    entries = []
    for level in (1, 2, 3):
        w, h, n = save_strip([fireball(level, f) for f in range(4)], f"{OUT}/fire_l{level}.png")
        entries.append((f"fire_l{level}", f"fire_l{level}.png", (w, h), n, 12.0))
    w, h, n = save_strip([fire_trail(f) for f in range(4)], f"{OUT}/fire_trail.png")
    entries.append(("fire_trail", "fire_trail.png", (w, h), n, 8.0))
    for level in (1, 2, 3):
        ice_block(level).save(f"{OUT}/ice_l{level}.png")
        w, h, n = save_strip([whirlwind(level, f) for f in range(4)], f"{OUT}/wind_l{level}.png")
        entries.append((f"wind_l{level}", f"wind_l{level}.png", (w, h), n, 12.0))
    icons().save(f"{OUT}/element_icons.png")
    pips().save(f"{OUT}/level_pips.png")
    frames_tres(entries, f"{OUT}/element_frames.tres")
    print("element art written")


if __name__ == "__main__":
    main()
