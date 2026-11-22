"""Batch 15 bosses from PixelLab, finished like the Ruins Warden (tools/art/finish_warden.py:
scale 0.6, palette snap, 1 px #08070b outline, #0f0e14 shadow, feet at (48, 92) on a 96x96
canvas in every frame).

  Mycelium Mother  d158c8e5-6c17-4b69-98bc-6ae796bf0111 "mycelium_mother_v3" (v3, 96 px,
                   high top-down). v3 custom animations, 4 directions (death: south):
                   idle 4, walk 6, spores 8, roots 8, summon 6, roar 8, hurt 4, death 8
  Sun Pharaoh      5236c67c-a822-4474-90f5-4429a58f41ac "sun_pharaoh_v3" (same settings):
                   idle 4, walk 6, beam 8, storm 8, sink 6, emerge 6, summon 6, roar 8,
                   hurt 4, death 8; emerge 6 is the sink played backwards (he rises out of
                 the sand elsewhere), so both match frame for frame
The animation names in the ZIP are the game names, except beam = "beam_v2" (the first
beam turned the Pharaoh round and drew huge flashes; v2 is the pose only, the beam itself
is fx/sun_beam.png). After the snap the colours that fall
in the floor range on the bodies are lifted (LIFT below) so the bosses stay readable on
their dark floors.

Usage (from the project root), with the get_character download ZIPs:
    python tools/art/finish_biome_bosses.py mother=<zip> pharaoh=<zip>
"""
import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(__file__))
import finish_warden as fw  # noqa: E402

BOSSES = {
    "mother": ("mycelium_mother", ["idle", "walk", "spores", "roots", "summon", "roar", "hurt"]),
    "pharaoh": ("sun_pharaoh", ["idle", "walk", "beam=beam_v2", "storm", "sink", "summon", "roar", "hurt"]),
}
FPS = {"idle": 6.0, "walk": 10.0, "spores": 10.0, "roots": 10.0, "summon": 8.0, "roar": 10.0,
       "hurt": 12.0, "death": 10.0, "beam": 10.0, "storm": 10.0, "sink": 10.0, "emerge": 10.0}
# Floor-range colours lifted on the bodies (moss and bark of the Mother's gown, the
# Pharaoh's dark wrappings).
LIFT = {
    "mother": {(38, 58, 50): (59, 90, 69), (59, 90, 69): (90, 138, 74), (74, 47, 34): (122, 74, 44),
               (52, 52, 66): (74, 47, 34), (63, 64, 80): (122, 74, 44), (76, 78, 95): (90, 138, 74)},
    "pharaoh": {(52, 52, 66): (138, 112, 72), (63, 64, 80): (176, 144, 92), (76, 78, 95): (176, 144, 92),
                (74, 47, 34): (122, 74, 44), (42, 41, 53): (74, 60, 44)},
}


def lift(strip_img, mapping):
    px = strip_img.load()
    for y in range(strip_img.height):
        for x in range(strip_img.width):
            p = px[x, y]
            if p[3] and p[:3] in mapping:
                px[x, y] = mapping[p[:3]] + (255,)
    return strip_img


def main():
    args = dict(a.split("=", 1) for a in sys.argv[1:])
    fw.FPS = FPS
    for key, zip_path in args.items():
        name, anims = BOSSES[key]
        frames = fw.load(zip_path)
        for entry in anims:
            anim, _, source = entry.partition("=")
            for direction, short in fw.DIRS.items():
                f = frames.get((source or anim, direction))
                if not f:
                    print("missing", name, anim, direction)
                    continue
                img = lift(fw.place(f, short), LIFT[key])
                img.save(os.path.join(fw.SRC, f"{name}_{anim}_{short}.png"))
                if anim == "sink":
                    n = img.width // fw.F
                    back = Image.new("RGBA", img.size)
                    for i in range(n):
                        back.paste(img.crop((i * fw.F, 0, (i + 1) * fw.F, fw.F)), ((n - 1 - i) * fw.F, 0))
                    back.save(os.path.join(fw.SRC, f"{name}_emerge_{short}.png"))
        if ("death", "south") in frames:
            lift(fw.place(frames[("death", "south")], "down"), LIFT[key]).save(os.path.join(fw.SRC, f"{name}_death.png"))
        else:
            print("missing", name, "death")
        fw.NAME = name
        fw.write_frames()
        print(name, "finished")


if __name__ == "__main__":
    main()
