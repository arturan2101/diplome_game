"""Nature theme: "ruins that nature broke into" (secret rooms, the merchant's glade).
Same layout as the ruins atlas, so a TileTheme can use it as is:
  0-2 floor (slabs with grass in the seams, moss, small flowers), 3 wall front (bricks
  with roots and moss), 4 wall top (stone grown over with grass), 5 cover (a mossy
  stump), 6 floor in light from above (a sunlit patch, lighter and warmer).
Warmer, greener palette (docs/art-style.md, "Nature theme"); same pixel style.
Run from the project root: python tools/art/make_nature_tiles.py
"""
from PIL import Image

PAL = {
    "S": "#3f4050", "s": "#343442", "d": "#2a2935",            # old stone
    "g": "#3b5a45", "G": "#5a8a4a", "L": "#8ac060", "m": "#263a32",  # grass and moss
    "r": "#4a2f22", "R": "#7a4a2c",                            # roots, bark
    "f": "#e0a070", "F": "#ffd860", "p": "#e85a3a",            # flowers
    "W": "#8a8466", "w": "#6a6656", "k": "#17161f", "o": "#08070b",  # warm lit stone, mortar
    "l": "#9a9470", "y": "#c8c088",                            # sunlit stone
}
TILES = [
    """
SSSSSSSdSSSSSSSS
SSSSSSSdSSSSSSSS
SSSSSSgdgSSSSSSS
SSSSSSSdSSSSSSSS
SSSSSSSGSSSSSSSS
ddgddddddddGdddd
ssssssssssssgsss
sssssssssssssssS
ssssfsssssssssss
sssgFgssssssssss
ssssgsssssssssss
dddddddddddgdddd
SSSSSSSSSSgLgSSS
SSSSSSSSSSSdSSSS
SSSSSSSSSSSdSSSS
SSSSSSSSSSSdSSSS""",
    """
mmgSSSSSSSSSSSSS
mgSSSSSSSSdSSSSS
gSSSSSSSSSdSSSSS
SSSSSSSSSSgSSSSS
SSSSSSSSSgGgSSSS
ddddddddddddddGd
sssssssssssssgLg
ssssssssssssssss
sssssssssssssss
ssssssssssspssss
sssssssssgpgssss
dddddddddddgdddd
SSSSSSSSSSSSSSSS
SSSSSSSSSSSSSmgS
SSSSSSSSSSSSmggm
SSSSSSSSSSSSSmmS""",
    """
gGgSSSSSSSdSSSSS
SgSSSSSSSSdSSSSS
SSSSSSSSSSdSSSSS
SSSSSSSSSSdSSSSS
SSSSSSSSSSdSSSSS
dddddddGddddddds
ssssssgLgsssssss
ssssssssssssssss
ssssssssssssssss
sssssssssssssfss
ssssssssssssgFgs
dddddddddddddgdd
SSSSSdSSSSSSSSSS
SSSSSdSSSSSSSSSS
SSSSGdGSSSSSSSSS
SSSSSgSSSSSSSSSS""",
    """
GLGGLGGGLGGGGLGG
GGgGGGgGGGgGGGGg
WWWWWWWWWWWWWWWW
wwwwwwwwwwwwwwww
kkkkkkkkkkkkkkkk
dddddddkddrddddk
dddddddkdrdddddk
sssssssksRssssk
kkkkkkkkkrkkkkkk
dddkdddddrdkmmdd
dddkddddddRkgmdd
sssksssssssRgms
kkkkkkkkkkkrkkkk
dddkdmmdddddrddd
dddkdgmddddddRdd
oooooooooooooooo""",
    """
GGGGGGLGGGGGGGGG
GGgGGGGGGGGgGGGG
GGGGGGGGGGGGGGGG
GGGGGWWGGGGGGLGG
GGLGWWwWGGGGGGGG
GGGGGWWGGGGgGGGG
GGGGGGGGGGGGGGGG
GgGGGGGGGGGGGGGG
GGGGGGGGGWWGGGGG
GGGGGGGGWWWWGGGG
GGGGLGGGGwWGGGgG
GGGGGGGGGGGGGGGG
GGGGGGGGGGGGGGGG
GGgGGGGGGGGGLGGG
GGGGGGGGGGGGGGGG
ggggggggggggggggg""",
    """
................
................
................
................
.....oooooo.....
....oGLGGLGo....
...oRRgGGgRRo...
...oRrRRRRrRo...
...oRrRRrRRRo...
...oRRRRRrRRo...
...oRrRRRRRro...
...oRRRrRRRRo...
..ogRRRRRRRRgo..
..oommmmmmmmoo..
...oooooooooo...
................""",
    """
llllllldllllllll
llllllldllllllll
lllllllyllllllll
llllllldllllllll
lllllllGllllllll
ddGddddddddddddd
yyyyyyyyyyyGyyyy
yyyyyyyyyyyyyyyy
yyyyfyyyyyyyyyyy
yyyGFGyyyyyyyyyy
yyyyGyyyyyyyyyyy
ddddddddddGddddd
llllllllllGLGlll
llllllllllldllll
llllllllllldllll
llllllllllldllll""",
]


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


def draw(rows):
    lines = rows.strip("\n").splitlines()
    img = Image.new("RGBA", (16, 16))
    for y, line in enumerate(lines[:16]):
        for x, key in enumerate(line.ljust(16, line[-1] if line else ".")[:16]):
            if key != ".":
                img.putpixel((x, y), rgb(PAL[key]))
    return img


atlas = Image.new("RGBA", (16 * len(TILES), 16))
for i, rows in enumerate(TILES):
    atlas.paste(draw(rows), (i * 16, 0))
atlas.save("assets/art/tiles/nature_tiles_atlas.png")
print("nature atlas written")
