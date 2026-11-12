"""Calibrates the reference times T_ref of rooms and tunnels from bot runs.

Method (docs/design.md, "Калибровка T_ref"): the mid bot plays many runs with
`tools/simulate.tscn -- --bot=mid --calibrate`; for every finished section the game
writes how long the bot spent in each room and in the tunnels
(user://calibration/<session>.json). This script takes, for each room template, the
median time over all sections where the bot entered that room, and for tunnels the
median time per tunnel. With --apply it writes the room medians into the
"; ref_time:" line of rooms/*.txt.

Usage (from the project root):
    python training/calibrate.py               # print the table
    python training/calibrate.py --apply       # also update rooms/*.txt
Options: --data DIR (default: the Godot user folder of the project), --min-time S
(ignore visits shorter than S seconds, default 1.0).
"""
import argparse
import glob
import json
import os
import re
import statistics

DEFAULT_DATA = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Ruins", "calibration")
ROOMS_DIR = "rooms"
REF_LINE = re.compile(r"^; ref_time:.*$", re.M)


def load_sections(data_dir):
    sections = []
    for path in sorted(glob.glob(os.path.join(data_dir, "*.json"))):
        with open(path, encoding="utf-8") as file:
            sections.extend(json.load(file)["sections"])
    return sections


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--data", default=DEFAULT_DATA)
    parser.add_argument("--min-time", type=float, default=1.0)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()

    sections = load_sections(args.data)
    if not sections:
        raise SystemExit(f"No calibration data in {args.data}")
    room_times = {}
    tunnel_times = []
    for section in sections:
        for name, seconds in section["rooms"].items():
            if seconds >= args.min_time:
                room_times.setdefault(name, []).append(seconds)
        if section["tunnels"] > 0:
            tunnel_times.append(section["tunnel"] / section["tunnels"])
    ordinary = [s["time"] for s in sections if not s["arena"]]
    arena = [s["time"] for s in sections if s["arena"]]

    print(f"{len(sections)} finished sections")
    print(f"section time: ordinary median {statistics.median(ordinary):.1f} s, arena median {statistics.median(arena):.1f} s")
    print(f"{'room':<20} {'visits':>6} {'median s':>9} {'p25':>6} {'p75':>6}")
    medians = {}
    for name in sorted(room_times):
        times = sorted(room_times[name])
        quartiles = statistics.quantiles(times, n=4) if len(times) > 1 else [times[0]] * 3
        medians[name] = round(statistics.median(times) * 2) / 2
        print(f"{name:<20} {len(times):>6} {medians[name]:>9.1f} {quartiles[0]:>6.1f} {quartiles[2]:>6.1f}")
    tunnel = round(statistics.median(tunnel_times) * 2) / 2
    print(f"{'tunnel (each)':<20} {len(tunnel_times):>6} {tunnel:>9.1f}")

    if args.apply:
        for name, median in medians.items():
            path = os.path.join(ROOMS_DIR, f"{name}.txt")
            if not os.path.exists(path):
                continue
            with open(path, encoding="utf-8") as file:
                text = file.read()
            text = REF_LINE.sub(f"; ref_time: {median:g}", text, count=1)
            with open(path, "w", encoding="utf-8", newline="\n") as file:
                file.write(text)
        print(f"Updated ref_time in {ROOMS_DIR}/*.txt. Set SectionBuilder.TUNNEL_REF_TIME = {tunnel:g}")


if __name__ == "__main__":
    main()
