"""Ruins hazard atlas: the placeholder atlas with new pit tiles.
Slot 0 (pit top edge): broken stone rim, then a sheer wall going down into the dark.
Slot 7 (pit inside): almost black with a few faint deep specks.
Run from the project root: python tools/art/make_pit_tiles.py
"""
from PIL import Image

SRC = "assets/placeholder/placeholder_tiles.png"
OUT = "assets/art/tiles/ruins_hazards.png"
C = {
    "v": "#08070b", "d": "#0f0e14", "k": "#17161f", "w": "#1f1e29", "s": "#2a2935",
    "t": "#5d6072", "T": "#767a8c", "f": "#343442",
}
PIT_TOP = """
fTTfTTTffTTTTfTf
TTtTTtTTTTtTTTTt
ttsttttsttttsstt
ssssksssssksssss
swwswwkwwswwwkww
wwkwwwwkwwwwkwww
kwwwkwwwwkwwwwkk
kkkkkkkkkkkkkkkk
dkdkddkddkdkdddk
dddddddddddddddd
dddvdddddddvdddd
vdddvvddvdddvvdd
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
"""
PIT_INNER = """
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
vvvvvvvvvvvdvvvv
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
vvvdvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvdvvv
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
vvvvvvdvvvvvvvvv
vvvvvvvvvvvvvvvv
vvvvvvvvvvvvvvvv
"""


def draw(rows):
    lines = rows.strip().splitlines()
    img = Image.new("RGBA", (16, 16))
    for y, line in enumerate(lines):
        for x, key in enumerate(line):
            h = C[key]
            img.putpixel((x, y), tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,))
    return img


atlas = Image.open(SRC).convert("RGBA")
atlas.paste(draw(PIT_TOP), (0, 0))
atlas.paste(draw(PIT_INNER), (7 * 16, 0))
atlas.save(OUT)
print("written", OUT)
