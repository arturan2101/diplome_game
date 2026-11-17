"""Elite triple-shot archer, animated: every archer strip (idle, walk, attack, hurt, death)
recoloured so it reads as the same enemy, but more dangerous: the red hood and cloth
turn purple (the colour of magic in the ruins) and the eye sockets glow gold like the
elite skeleton's. Writes assets/art/enemies/archer_elite_<anim>[_<dir>].png and
archer_elite_frames.tres (same animation names and speeds as archer_frames.tres).
Run from the project root after the archer strips exist:
    python tools/art/make_archer_elite.py
"""
import glob
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_action_frames as actions  # noqa: E402

F = 24
SRC = "assets/art/enemies"


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5))


CLOTH = {hexc("#a82a30"): hexc("#9a5ae0"), hexc("#5a1820"): hexc("#4a2a78"), hexc("#e85a3a"): hexc("#9a5ae0")}
BONE = {hexc("#f4f0e0"), hexc("#d8d4c4")}
DARK = {hexc("#08070b"), hexc("#0f0e14"), hexc("#17161f")}
GLOW = hexc("#ffd860")


def elite_frame(img):
    out = img.copy()
    src = img.load()
    px = out.load()
    for y in range(F):
        for x in range(F):
            p = src[x, y]
            if not p[3]:
                continue
            if p[:3] in CLOTH:
                px[x, y] = CLOTH[p[:3]] + (255,)
            elif p[:3] in DARK and 0 < x < F - 1 and 0 < y < F - 1:
                # An eye socket: a dark pixel under bone with bone beside it, in the
                # upper half of the figure (the skull, not the ribs).
                left, right, up = src[x - 1, y], src[x + 1, y], src[x, y - 1]
                bone_side = (left[3] and left[:3] in BONE) or (right[3] and right[:3] in BONE)
                if y < F // 2 and up[3] and up[:3] in BONE and bone_side:
                    px[x, y] = GLOW + (255,)
    return out


def main():
    made = 0
    for path in sorted(glob.glob(os.path.join(SRC, "archer_*.png"))):
        name = os.path.basename(path)
        if name.startswith("archer_elite"):
            continue
        img = Image.open(path).convert("RGBA")
        out = Image.new("RGBA", img.size)
        for i in range(img.width // F):
            out.paste(elite_frame(img.crop((i * F, 0, i * F + F, F))), (i * F, 0))
        out.save(os.path.join(SRC, name.replace("archer_", "archer_elite_", 1)))
        made += 1
    actions.write_frames(SRC, "archer_elite", os.path.join(SRC, "archer_elite_frames.tres"))
    print(f"{made} elite archer strips written")


if __name__ == "__main__":
    main()
