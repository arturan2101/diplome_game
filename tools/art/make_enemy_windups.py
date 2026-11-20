"""Enemy attacks with a readable wind-up (batch 10, group 5). They replace the attack
strips that were the idle frame shifted with a slash drawn over it, and the red /
orange warning tint: the wind-up pose itself has to say "an attack is coming".

PixelLab, for the humanoid enemies. The game's own idle frames (4 directions) were
padded, enlarged 2x with nearest neighbour and imported as a v3 character, so the
animation starts from the sprite the game shows; then a skeleton-v3 clip written pose by
pose. The 2x frames are brought back to game size here (every second pixel), snapped to
the colours of the actor's own idle and walk strips (this keeps the golem's grass and the
ghost's single teal body), and each frame is put down with its lowest body pixel on the idle's feet
row (PixelLab keeps the hips in place, so a crouch would sink) and the idle's shadow.
    skeleton  27ba5699-fe99-4ccb-a253-9862aec4207a  "attack_windup"  6 frames:
              sword raised high behind the head 0-1 (hold 1), slash down 2-3, recover 4-5
    archer    1b5bae75-a812-48bf-bf7a-f3d439691239  "attack_draw"    6 frames:
              bow up 0, draw to the cheek 1-2 (hold 2), release 3, recoil 4, lower 5
    ghost     e7152b47-c05e-4158-a3dc-a418cd4b0287  "attack_reach"   6 frames:
              pulls back, arms raised 0-1 (hold 1), reaches out 2-3 (touch), back 4-5
    golem     8ea0e44b-b497-4bdb-a549-8df612a3ed38  "attack_slam"    8 frames:
              fists rise 0, held over the head 1-3, slam 4-5, recover 6-7
Elites are recoloured from the new strips like before: the shield skeleton with
make_elite_frames.py's elite_frame (red armour, gold eyes, shield), the triple-shot
archer with make_archer_elite.py's elite_frame (purple cloth, gold eyes).
The beetle (16x16, not a humanoid) is drawn here: it crouches and pulls back 0-1
(hold 1), then lunges 3 px with its mandibles open 2-3.

Usage, from the project root, with the character ZIPs (get_character download links):
    python tools/art/make_enemy_windups.py skeleton=<zip> archer=<zip> ghost=<zip> golem=<zip>
Any actor left out keeps its strips; the beetle is always redrawn. Rewrites the
<actor>_frames.tres of every actor it touches.
"""
import io
import os
import sys
import zipfile

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import make_action_frames as actions  # noqa: E402
from import_pixellab import snap  # noqa: E402
from finish_golem import overgrow  # noqa: E402
from make_archer_elite import elite_frame as archer_elite_frame  # noqa: E402

SRC = "assets/art/enemies"
SHADOW = (15, 14, 20, 255)
DIRS = {"south": "down", "east": "right", "north": "up", "west": "left"}
STEP = {"down": (0, 1), "up": (0, -1), "left": (-1, 0), "right": (1, 0)}
ACTORS = {  # actor: (frame size, PixelLab animation name)
    "skeleton": (24, "attack_windup"),
    "archer": (24, "attack_draw"),
    "ghost": (32, "attack_reach"),
    "golem": (48, "attack_slam"),
}


def elite_namespace():
    """The definitions of make_elite_frames.py without running that script (it rebuilds
    every elite strip when imported)."""
    path = os.path.join(os.path.dirname(__file__), "make_elite_frames.py")
    src = open(path, encoding="utf-8").read()
    head = src[:src.index("\nfor path in sorted")]
    ns = {"__file__": path}
    exec(compile(head, path, "exec"), ns)
    return ns


def skeleton_elite(strip, idle, short):
    """Red armour and gold eyes on every frame; the shield where the idle has it (placed
    from the frame's own box it would follow the sword)."""
    ns = elite_namespace()
    box = idle.getbbox()
    side = short if short != "up" else None
    out = []
    for f in strip:
        e = ns["elite_frame"](f, None)
        if side:
            sx = box[0] - 2 if side == "left" else (box[2] - 6 if side == "right" else box[0] - 1)
            sy = box[1] + 7
            px = e.load()
            for dy, row in enumerate(ns["SHIELD"]):
                for dx, key in enumerate(row):
                    x, y = sx + dx, sy + dy
                    if key != "." and 0 <= x < e.width and 0 <= y < e.height - 1:
                        px[x, y] = ns["SHIELD_COL"][key] + (255,)
        out.append(e)
    return out


def load(zip_path, anim):
    z = zipfile.ZipFile(zip_path)
    out = {}
    for n in sorted(z.namelist()):
        parts = n.split("/")
        if "animations" in parts and n.endswith(".png") and parts[parts.index("animations") + 1] == anim:
            direction = parts[parts.index("animations") + 2]
            out.setdefault(direction, []).append(Image.open(io.BytesIO(z.read(n))).convert("RGBA"))
    return out


def body_rows(img):
    """(lowest row, centre x of the lowest 3 rows) of the non-shadow pixels."""
    px = img.load()
    rows = [y for y in range(img.height) if any(px[x, y][3] and px[x, y] != SHADOW for x in range(img.width))]
    bottom = max(rows)
    xs = [x for y in range(bottom - 2, bottom + 1) for x in range(img.width) if px[x, y][3] and px[x, y] != SHADOW]
    return bottom, (min(xs) + max(xs)) / 2.0


# Colours of the source that must not come back as they are: the ghost's left idle has a
# few skin pixels, which the animation grew into hands; they become teal.
REMAP = {"ghost": {(224, 160, 112): (42, 168, 160)}}


def actor_colours(actor):
    """Every colour of the actor's idle and walk strips: the attack keeps its look (the
    golem's grass greens of the nature theme, no skin tones on the ghost)."""
    colours = set()
    for anim in ("idle", "walk"):
        for short in DIRS.values():
            img = Image.open(os.path.join(SRC, f"{actor}_{anim}_{short}.png")).convert("RGBA")
            colours |= {p[:3] for p in img.getdata() if p[3] and p != SHADOW}
    return sorted(colours - set(REMAP.get(actor, {})))


def half(img, colours, remap):
    """2x art back to 1x: every second pixel, then the actor's own colours. The shadow
    is dropped."""
    small = snap(img.resize((img.width // 2, img.height // 2), Image.NEAREST))
    px = small.load()
    for y in range(small.height):
        for x in range(small.width):
            p = px[x, y]
            if not p[3] or p == SHADOW:
                px[x, y] = (0, 0, 0, 0)
                continue
            if p[:3] in remap:
                px[x, y] = remap[p[:3]] + (255,)
                continue
            best = min(colours, key=lambda c: (c[0] - p[0]) ** 2 + (c[1] - p[1]) ** 2 + (c[2] - p[2]) ** 2)
            px[x, y] = best + (255,)
    return small


def import_strip(frames, idle, F, colours, remap):
    bottom_i, cx_i = body_rows(idle)
    small = [half(f, colours, remap) for f in frames]
    _, cx0 = body_rows(small[0])
    dx = int(round(cx_i - cx0))
    shadow = actions.shadow_of(idle)
    out = []
    for f in small:
        b, _ = body_rows(f)
        cell = shadow.copy()
        layer = Image.new("RGBA", (F, F))
        layer.paste(f, (dx, bottom_i - b), f)
        cell.alpha_composite(layer)
        out.append(cell)
    return out


def beetle(idle, short):
    """Crouch (pressed flat, pulled back), then a lunge with open mandibles."""
    sx, sy = STEP[short]
    crouch1 = actions.squash(actions.move(idle, -sx, -sy), 0.85)
    crouch2 = actions.squash(actions.move(idle, -sx, -sy), 0.75)
    lunge = mandibles(actions.move(idle, sx * 3, sy * 3), short)
    bite = mandibles(actions.move(idle, sx * 2, sy * 2), short, closed=True)
    return [crouch1, crouch2, lunge, bite]


def mandibles(img, short, closed=False):
    """Two bone pincers sticking out of the front of the head."""
    body = actions.body_only(img)
    box = body.getbbox()
    out = img.copy()
    px = out.load()
    bone, dark = (244, 240, 224, 255), (8, 7, 11, 255)
    cx, cy = (box[0] + box[2] - 1) // 2, (box[1] + box[3] - 1) // 2
    gap = 1 if closed else 2
    if short in ("down", "up"):
        fy = box[3] if short == "down" else box[1] - 1
        tip = fy + (1 if short == "down" else -1)
        pts = [(cx - gap, fy), (cx + gap + 1, fy), (cx - gap + 1, tip), (cx + gap, tip)]
    else:
        fx = box[2] if short == "right" else box[0] - 1
        tip = fx + (1 if short == "right" else -1)
        cy = cy + 1
        pts = [(fx, cy - gap), (fx, cy + gap), (tip, cy - gap + 1), (tip, cy + gap - 1)]
    for i, (x, y) in enumerate(pts):
        if 0 <= x < img.width and 0 <= y < img.height:
            px[x, y] = bone if i < 2 else dark
    return out


def write(actor, F):
    actions.F = F
    actions.write_frames(SRC, actor, os.path.join(SRC, f"{actor}_frames.tres"))


def main():
    zips = dict(a.split("=", 1) for a in sys.argv[1:])
    for actor, (F, anim) in ACTORS.items():
        if actor not in zips:
            continue
        frames = load(zips[actor], anim)
        colours = actor_colours(actor)
        actions.F = F
        for direction, short in DIRS.items():
            idle = actions.frame(os.path.join(SRC, f"{actor}_idle_{short}.png"))
            strip = import_strip(frames[direction], idle, F, colours, REMAP.get(actor, {}))
            if actor == "golem":
                strip = [overgrow(f) for f in strip]  # the grass of finish_golem.py
            actions.strip(strip, os.path.join(SRC, f"{actor}_attack_{short}.png"))
            if actor == "skeleton":
                actions.strip(skeleton_elite(strip, idle, short), os.path.join(SRC, f"skeleton_elite_attack_{short}.png"))
            if actor == "archer":
                actions.strip([archer_elite_frame(f) for f in strip], os.path.join(SRC, f"archer_elite_attack_{short}.png"))
        write(actor, F)
        if actor == "skeleton":
            write("skeleton_elite", F)
        if actor == "archer":
            write("archer_elite", F)
        print(actor, "attack imported")
    actions.F = 16
    for short in DIRS.values():
        idle = actions.frame(os.path.join(SRC, f"beetle_idle_{short}.png"))
        actions.strip(beetle(idle, short), os.path.join(SRC, f"beetle_attack_{short}.png"))
    write("beetle", 16)
    print("beetle attack drawn")


if __name__ == "__main__":
    main()
