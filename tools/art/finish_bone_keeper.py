"""Mini-boss "Bone Keeper" (plan group 4): a big skeleton priest, 48x48, 4 directions.
PixelLab character 29e37e35-8eef-42bb-a769-2960e05604ea "ruins_bone_keeper" (standard,
high top-down): idle = breathing-idle, walk = walking-4-frames, and v3 custom
animations per direction, 6 frames each: attack_<dir> (staff raised for two frames,
then the blow) and summon_<dir> (staff and hand raised, the skull glows).
Steps, from the project root, with the character ZIP (get_character download link):
    python tools/art/import_pixellab.py <zip> bone_keeper assets/art/enemies 48 idle walk
    python tools/art/finish_bone_keeper.py <zip>
This script:
- imports attack and summon at the same scale (no shrinking: the raised staff may be
  cut at the frame edge), feet aligned with the idle of the same direction;
- recolours the robe: its main colour had snapped to #4a2a78, inside the floor's value
  range (docs/art-style.md), so it becomes #9a5ae0 with #4a2a78 for the folds;
- writes bone_keeper_frames.tres with idle, walk, attack, summon, hurt and death.
"""
import glob
import io
import os
import sys
import zipfile

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
from import_pixellab import DIRS, snap  # noqa: E402
from import_player_actions import feet  # noqa: E402

F = 48
SRC = "assets/art/enemies"
NAME = "bone_keeper"
FPS = {"idle": 6.0, "walk": 8.0, "attack": 10.0, "summon": 8.0, "hurt": 12.0, "death": 10.0}
LOOP = {"idle", "walk"}


def hexc(h):
    return tuple(int(h[i:i + 2], 16) for i in (1, 3, 5)) + (255,)


ROBE = {hexc("#4a2a78"): hexc("#9a5ae0"), hexc("#343442"): hexc("#4a2a78"), hexc("#2a2935"): hexc("#4a2a78")}


def recolor(img):
    out = img.copy()
    px = out.load()
    for y in range(out.height):
        for x in range(out.width):
            p = px[x, y]
            if p[3] and p in ROBE:
                px[x, y] = ROBE[p]
    return out


def custom_strips(zip_path):
    z = zipfile.ZipFile(zip_path)
    groups = {}
    for n in sorted(z.namelist()):
        parts = n.split("/")
        if "animations" in parts and n.endswith(".png"):
            i = parts.index("animations")
            anim, direction = parts[i + 1], parts[i + 2]
            kind = anim.split("_")[0]
            if kind in ("attack", "summon") and direction in DIRS:
                groups.setdefault((kind, DIRS[direction]), []).append(Image.open(io.BytesIO(z.read(n))).convert("RGBA"))
    for (kind, short), frames in groups.items():
        idle = Image.open(os.path.join(SRC, f"{NAME}_idle_{short}.png")).convert("RGBA").crop((0, 0, F, F))
        idle_cx, idle_bottom = feet(idle)
        cx, bottom = feet(frames[0])
        dx, dy = int(round(idle_cx - cx)), idle_bottom - bottom
        out = Image.new("RGBA", (F * len(frames), F))
        for i, frame in enumerate(frames):
            cell = Image.new("RGBA", (F, F))
            cell.paste(frame, (dx, dy), frame)
            out.paste(snap(cell), (i * F, 0))
        out.save(os.path.join(SRC, f"{NAME}_{kind}_{short}.png"))
        print(kind, short, len(frames), "frames, offset", dx, dy)


def write_frames():
    entries = []
    for path in sorted(glob.glob(os.path.join(SRC, f"{NAME}_*.png"))):
        anim = os.path.basename(path)[len(NAME) + 1:-4]
        kind = anim.split("_")[0]
        if kind not in FPS:
            continue
        entries.append((anim, os.path.basename(path), Image.open(path).width // F))
    lines = [f'[gd_resource type="SpriteFrames" load_steps={1 + len(entries) + sum(c for _, _, c in entries)} format=3]', ""]
    for anim, name, _ in entries:
        lines.append(f'[ext_resource type="Texture2D" path="res://{SRC}/{name}" id="{anim}"]')
    lines.append("")
    for anim, _, count in entries:
        for i in range(count):
            lines += [f'[sub_resource type="AtlasTexture" id="{anim}_{i}"]', f'atlas = ExtResource("{anim}")',
                      f"region = Rect2({i * F}, 0, {F}, {F})", ""]
    blocks = []
    for anim, _, count in entries:
        kind = anim.split("_")[0]
        frames = ", ".join('{\n"duration": 1.0,\n"texture": SubResource("%s_%d")\n}' % (anim, i) for i in range(count))
        blocks.append('{\n"frames": [%s],\n"loop": %s,\n"name": &"%s",\n"speed": %s\n}'
                      % (frames, "true" if kind in LOOP else "false", anim, FPS[kind]))
    lines += ["[resource]", "animations = [" + ", ".join(blocks) + "]", ""]
    with open(os.path.join(SRC, f"{NAME}_frames.tres"), "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines))


def main():
    custom_strips(sys.argv[1])
    for path in sorted(glob.glob(os.path.join(SRC, f"{NAME}_*.png"))):
        recolor(Image.open(path).convert("RGBA")).save(path)
    write_frames()
    print("bone keeper finished")


if __name__ == "__main__":
    main()
