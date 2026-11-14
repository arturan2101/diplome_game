"""Fused elements (two spells merged into one), 3 visual levels each, plus the short
merge effect. A fused element is bigger and denser than the plain ones even on level 1
(two colour families, a dark core and a bright rim). Pairs follow docs/design.md:
  firestorm  = fire + wind  (a burning whirlwind)
  blizzard   = ice + wind   (a ring of snow and ice shards)
  steam      = fire + ice   (a boiling cloud with hot drops)
Output (assets/art/fx/): <name>_l<1-3>.png (4 frames of 48x48), merge.png (8 frames of
32x32: two coloured sparks spiral in, flash, one new colour bursts out, drawn in white
and gold so it suits every pair), fusion_icons.png (16x16: firestorm, blizzard, steam)
and fusion_frames.tres (animations <name>_l1..3 and merge).
Run from the project root: python tools/art/make_fusion_frames.py
"""
import math
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_element_frames as el  # noqa: E402

OUT = el.OUT
PAIRS = {
    "firestorm": (["r", "R", "q", "Y"], ["Y", "Z", "W"], "q"),
    "blizzard": (["b", "B", "L"], ["L", "w", "W"], "T"),
    "steam": (["R", "q", "w"], ["w", "W", "L"], "S"),
}


def fused(name, level, frame):
    size = 48
    img = Image.new("RGBA", (size, size))
    outer, inner, spark = PAIRS[name]
    c = size / 2
    rings = 2 + level           # level 1 already has 3 rings (plain wind level 1 has 2)
    for ring in range(rings):
        radius = 7 + ring * 3 + level
        arcs = 4 + level
        ramp = outer if ring >= rings // 2 else inner
        for a in range(arcs):
            start = (a / arcs) * math.tau - frame * 0.5 + ring * 0.9
            for k in range(12 + level * 3):
                ang = start + k * 0.055
                x = c + math.cos(ang) * radius
                y = c + math.sin(ang) * radius * 0.65
                el.put(img, x, y, ramp[min(len(ramp) - 1, k * len(ramp) // (12 + level * 3))])
    # the core: a dense centre the plain elements do not have
    el.disc(img, c, c, 3 + level, outer[:2] + inner[-2:])
    # particles: more each level; level 3 adds a second, faster swarm
    for i in range(4 + level * 3):
        ang = frame * 0.7 + i * math.tau / (4 + level * 3)
        r = 12 + (i * 5 + frame) % (6 + level * 2)
        el.put(img, c + math.cos(ang) * r, c + math.sin(ang) * r * 0.65, spark)
    if level == 3:
        for i in range(8):
            ang = -frame * 1.1 + i * math.tau / 8
            el.put(img, c + math.cos(ang) * 21, c + math.sin(ang) * 21 * 0.65, inner[-1])
            el.put(img, c + math.cos(ang) * 20, c + math.sin(ang) * 20 * 0.65, outer[-1])
    return img


def merge(frame):
    """Two sparks spiral in (frames 0-3), flash (4), the new element bursts out (5-7)."""
    size = 32
    img = Image.new("RGBA", (size, size))
    c = size / 2
    if frame < 4:
        r = 12 - frame * 3
        for side, key in ((0, "q"), (math.pi, "L")):
            ang = side + frame * 1.2
            for k in range(4):
                a = ang - k * 0.3
                el.put(img, c + math.cos(a) * (r + k), c + math.sin(a) * (r + k), key)
            el.disc(img, c + math.cos(ang) * r, c + math.sin(ang) * r, 2, [key, "W"])
    elif frame == 4:
        el.disc(img, c, c, 7, ["Y", "Z", "W", "W"])
    else:
        r = 4 + (frame - 4) * 4
        for i in range(12):
            a = i * math.tau / 12
            for k in range(2):
                el.put(img, c + math.cos(a) * (r + k), c + math.sin(a) * (r + k), "Z" if k else "W")
        el.disc(img, c, c, max(1, 4 - (frame - 5)), ["Y", "Z"])
    return img


def icons():
    strip = Image.new("RGBA", (48, 16))
    for i, name in enumerate(PAIRS):
        big = fused(name, 2, 0)
        icon = big.crop((6, 10, 42, 38)).resize((16, 12), Image.NEAREST)
        cell = Image.new("RGBA", (16, 16))
        cell.paste(icon, (0, 2))
        strip.paste(cell, (i * 16, 0))
    return strip


def main():
    entries = []
    for name in PAIRS:
        for level in (1, 2, 3):
            w, h, n = el.save_strip([fused(name, level, f) for f in range(4)], f"{OUT}/{name}_l{level}.png")
            entries.append((f"{name}_l{level}", f"{name}_l{level}.png", (w, h), n, 12.0))
    w, h, n = el.save_strip([merge(f) for f in range(8)], f"{OUT}/merge.png")
    entries.append(("merge", "merge.png", (w, h), n, 16.0))
    icons().save(f"{OUT}/fusion_icons.png")
    el.frames_tres(entries, f"{OUT}/fusion_frames.tres")
    # The merge plays once.
    path = f"{OUT}/fusion_frames.tres"
    with open(path, encoding="utf-8") as file:
        text = file.read().replace('"loop": true,\n"name": &"merge"', '"loop": false,\n"name": &"merge"')
    with open(path, "w", encoding="utf-8", newline="\n") as file:
        file.write(text)
    print("fusion art written")


if __name__ == "__main__":
    main()
