"""Draws a readable skull face on every idle and walk frame of the skeleton: from the
front two black 2x2 eye sockets with red glints and a nose hole under a bone
forehead; from the side one socket with a glint near the front and a dark jaw line.
Afterwards run make_action_frames.py and make_elite_frames.py so the attack, hurt,
death and elite frames get the same face.
Run from the project root: python tools/art/fix_skeleton_face.py
"""
from PIL import Image

F = 24
FOLDER = "assets/art/enemies/"
COPPER = {(224, 160, 112), (176, 112, 64), (74, 47, 34), (138, 74, 16)}
OUTLINE = (8, 7, 11, 255)
BONE = (244, 240, 224, 255)
BONE_SHADOW = (216, 212, 196, 255)
GLINT = (232, 90, 58, 255)
# Front face, 6 wide x 4 high, under the helmet band: o socket, q glint, f bone, h shade.
FRONT = ["ffffff", "ooffoo", "oqhhqo", "ffoohf"]
KEYS = {"o": OUTLINE, "q": GLINT, "f": BONE, "h": BONE_SHADOW}


def helmet_row(px):
    for y in range(F):
        if any(px[x, y][3] and px[x, y][:3] in COPPER for x in range(F)):
            return y
    return None


def inner_span(px, y):
    """First and last pixel inside the outline on a row."""
    xs = [x for x in range(F) if px[x, y][3] and px[x, y] != OUTLINE]
    return (min(xs), max(xs)) if xs else None


def face_front(frame):
    px = frame.load()
    top = helmet_row(px)
    if top is None:
        return
    span = inner_span(px, top + 1)
    if span is None:
        return
    centre = (span[0] + span[1] + 1) // 2
    x0 = centre - 3
    for dy, row in enumerate(FRONT):
        for dx, key in enumerate(row):
            x, y = x0 + dx, top + 1 + dy
            if 0 <= x < F and px[x, y][3]:
                px[x, y] = KEYS[key]


def face_side(frame, facing_right):
    px = frame.load()
    top = helmet_row(px)
    if top is None:
        return
    span = inner_span(px, top + 2)
    if span is None:
        return
    front = span[1] - 1 if facing_right else span[0] + 1
    back = front - 1 if facing_right else front + 1
    # the eye socket and its glint, near the front of the skull
    px[front, top + 2] = OUTLINE
    px[back, top + 2] = OUTLINE
    px[front, top + 3] = GLINT
    px[back, top + 3] = OUTLINE
    # the jaw: a dark line along the bottom of the skull, towards the front
    for dx in range(3):
        x = front - dx if facing_right else front + dx
        if px[x, top + 5][3]:
            px[x, top + 5] = OUTLINE


def fix(path, side):
    img = Image.open(path).convert("RGBA")
    for i in range(img.width // F):
        frame = img.crop((i * F, 0, i * F + F, F))
        if side == "down":
            face_front(frame)
        elif side in ("right", "left"):
            face_side(frame, side == "right")
        img.paste(frame, (i * F, 0))
    img.save(path)


for anim in ("idle", "walk"):
    for side in ("down", "right", "left"):
        fix(f"{FOLDER}skeleton_{anim}_{side}.png", side)
print("skeleton faces drawn")
