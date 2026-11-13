"""Analysis of the game logs (one JSON line per section, see docs/design.md).

Reads every *.jsonl under a folder (by default the bot experiment folder written by
tools/simulate.tscn with --log-dir), groups the sections by director mode and bot
profile, and writes:
  - summary.md: a table per mode and bot (runs, sections cleared, depth reached,
    death section, HP on exit, damage per section and its spread, final skill S),
    the HP-on-exit spread between bots for every mode, and the share of damage
    by source (enemy type or hazard) with what hurt the bot most in its death section;
  - figures: depth reached, HP on exit, damage per section, skill S and budget by
    section index, for every mode and bot.

Usage (from the project root):
    python training/analyze.py                         # all bot experiment logs
    python training/analyze.py --logs <folder> --out docs/figures
Requires pandas and matplotlib.
"""
import argparse
import glob
import json
import os

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import pandas as pd  # noqa: E402

DEFAULT_LOGS = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Ruins", "sim_logs", "experiment")
BOT_ORDER = ["weak", "mid", "strong"]
MODE_ORDER = ["RANDOM", "RULES", "LEARNED"]
BOT_COLORS = {"weak": "#d1495b", "mid": "#edae49", "strong": "#00798c", "": "#555555"}
# Curves by section index stop where fewer runs than this are still alive.
MIN_RUNS_FOR_CURVE = 5
# "Hard but passable": HP on exit inside this corridor (design.md, learned director reward).
HP_CORRIDOR = (30, 70)
# Window of sections every bot usually reaches; deaths inside it count as HP 0.
EARLY_SECTIONS = 6


def load(folder):
    rows = []
    for path in glob.glob(os.path.join(folder, "**", "*.jsonl"), recursive=True):
        with open(path, encoding="utf-8") as file:
            rows.extend(json.loads(line) for line in file if line.strip())
    if not rows:
        raise SystemExit(f"No log lines under {folder}")
    frame = pd.DataFrame(rows)
    frame["bot"] = frame.get("bot", "").fillna("")
    frame["run_id"] = frame["session"] + "#" + frame["run"].astype(str)
    return frame


def order(values, preferred):
    return [v for v in preferred if v in values] + sorted(v for v in values if v not in preferred)


def runs_table(frame):
    """One row per run: how far it went and how it ended."""
    grouped = frame.groupby(["mode", "bot", "run_id"])
    runs = grouped.agg(sections=("section", "count"), depth=("depth", "max"), died=("died", "any"),
                       last_section=("section", "max"), skill_mean=("skill", "mean")).reset_index()
    runs["death_section"] = runs["last_section"].where(runs["died"]) + 1
    damage_spread = grouped["damage_total"].std(ddof=0).rename("damage_std").reset_index()
    return runs.merge(damage_spread, on=["mode", "bot", "run_id"])


def summary(frame, runs):
    lines = ["# Bot experiment", "",
             f"{len(runs)} runs, {len(frame)} sections. Death section counts from 1 (dying in the first section = 1).", "",
             "| Mode | Bot | Runs | Sections cleared (mean) | Depth reached (mean) | Died | Death section: median (25-75%) "
             f"| HP on exit (mean) | HP on exit, sections 1-{EARLY_SECTIONS} | Sections in HP {HP_CORRIDOR[0]}-{HP_CORRIDOR[1]} "
             "| Damage per section (mean) | Damage spread in a run (std) | Skill S (run mean) |",
             "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    spread = []
    for mode in order(frame["mode"].unique(), MODE_ORDER):
        bot_means = []
        bot_early = []
        for bot in order(frame.loc[frame["mode"] == mode, "bot"].unique(), BOT_ORDER):
            part = frame[(frame["mode"] == mode) & (frame["bot"] == bot)]
            part_runs = runs[(runs["mode"] == mode) & (runs["bot"] == bot)]
            cleared = (part_runs["sections"] - part_runs["died"].astype(int)).mean()
            deaths = part_runs["death_section"].dropna()
            death = (f"{deaths.median():.0f} ({deaths.quantile(0.25):.0f}-{deaths.quantile(0.75):.0f})"
                     if len(deaths) else "-")
            finished = part[~part["died"]]
            hp = finished["hp_exit"].mean()
            early = part[part["section"] < EARLY_SECTIONS]
            hp_early = early["hp_exit"].where(~early["died"], 0).mean()
            in_corridor = finished["hp_exit"].between(*HP_CORRIDOR).mean()
            bot_means.append(hp)
            bot_early.append(hp_early)
            lines.append(f"| {mode} | {bot or 'human'} | {len(part_runs)} | {cleared:.1f} | {part_runs['depth'].mean() + 1:.1f} "
                         f"| {part_runs['died'].mean():.0%} | {death} | {hp:.0f} | {hp_early:.0f} | {in_corridor:.0%} "
                         f"| {part['damage_total'].mean():.1f} | {part_runs['damage_std'].mean():.1f} | {part_runs['skill_mean'].mean():.2f} |")
        if len(bot_means) > 1:
            spread.append((mode, max(bot_means) - min(bot_means), pd.Series(bot_means).std(ddof=0),
                           max(bot_early) - min(bot_early), pd.Series(bot_early).std(ddof=0)))
    lines += ["", "HP on exit counts finished sections only (not the one the bot died in); "
              f"the sections 1-{EARLY_SECTIONS} column counts a death there as HP 0, so it compares the same "
              "sections for every bot.", "",
              "## Spread of HP on exit between bots", "",
              "Smaller = the director keeps players of different skill closer to the same state.", "",
              f"| Mode | All finished sections: max - min of bot means | std | Sections 1-{EARLY_SECTIONS}: max - min | std |",
              "| --- | --- | --- | --- | --- |"]
    lines += [f"| {mode} | {gap:.1f} | {std:.1f} | {early_gap:.1f} | {early_std:.1f} |"
              for mode, gap, std, early_gap, early_std in spread]
    return "\n".join(lines) + "\n", spread


def damage_sources(frame):
    """Share of all damage taken by source, and the main source in the death section."""
    records = [(row.mode, row.bot, source, amount) for row in frame.itertuples()
               for source, amount in (row.damage or {}).items()]
    damage = pd.DataFrame(records, columns=["mode", "bot", "source", "amount"])
    totals = damage.groupby(["mode", "bot", "source"])["amount"].sum().unstack(fill_value=0)
    shares = totals.div(totals.sum(axis=1), axis=0)
    dead = frame[frame["died"]]
    killers = dead["damage"].apply(lambda by_source: max(by_source, key=by_source.get) if by_source else "-")
    killed = pd.crosstab([dead["mode"], dead["bot"]], killers)
    sources = list(shares.columns)
    lines = ["", "## Damage by source", "",
             "Share of all damage taken; in brackets: in how many deaths this source dealt the most "
             "damage of the death section.", "",
             "| Mode | Bot | " + " | ".join(sources) + " |",
             "| --- | --- | " + " | ".join("---" for _ in sources) + " |"]
    for mode in order(shares.index.get_level_values(0).unique(), MODE_ORDER):
        for bot in order(shares.loc[mode].index.unique(), BOT_ORDER):
            cells = []
            for source in sources:
                deaths = 0
                if (mode, bot) in killed.index and source in killed.columns:
                    deaths = killed.loc[(mode, bot), source]
                cells.append(f"{shares.loc[(mode, bot), source]:.0%} ({deaths})")
            lines.append(f"| {mode} | {bot or 'human'} | " + " | ".join(cells) + " |")
    return "\n".join(lines) + "\n"


def plot_box(frame, runs, out):
    modes = order(runs["mode"].unique(), MODE_ORDER)
    figure, axes = plt.subplots(1, 3, figsize=(15, 4.5))
    for axis, (column, source, title) in zip(axes, [
            ("depth", runs, "Depth reached (0 = first depth)"),
            ("hp_exit", frame[~frame["died"]], "HP on exit of a finished section"),
            ("damage_total", frame, "Damage taken per section")]):
        data, labels, colors = [], [], []
        for mode in modes:
            for bot in order(source.loc[source["mode"] == mode, "bot"].unique(), BOT_ORDER):
                data.append(source[(source["mode"] == mode) & (source["bot"] == bot)][column])
                labels.append(f"{mode}\n{bot}")
                colors.append(BOT_COLORS.get(bot, "#555555"))
        boxes = axis.boxplot(data, patch_artist=True, showfliers=False)
        for patch, color in zip(boxes["boxes"], colors):
            patch.set_facecolor(color)
            patch.set_alpha(0.7)
        axis.set_xticks(range(1, len(labels) + 1), labels, fontsize=8)
        axis.set_title(title)
        axis.grid(axis="y", alpha=0.3)
    figure.tight_layout()
    path = os.path.join(out, "bots_overview.png")
    figure.savefig(path, dpi=120)
    plt.close(figure)
    return path


def plot_curves(frame, column, title, file_name, out):
    modes = order(frame["mode"].unique(), MODE_ORDER)
    figure, axes = plt.subplots(1, len(modes), figsize=(6 * len(modes), 4.2), sharey=True, squeeze=False)
    for axis, mode in zip(axes[0], modes):
        for bot in order(frame.loc[frame["mode"] == mode, "bot"].unique(), BOT_ORDER):
            part = frame[(frame["mode"] == mode) & (frame["bot"] == bot)]
            by_section = part.groupby("section")[column]
            counts = by_section.count()
            mean = by_section.mean()[counts >= MIN_RUNS_FOR_CURVE]
            axis.plot(mean.index + 1, mean.values, marker="o", markersize=3, label=bot or "human",
                      color=BOT_COLORS.get(bot, "#555555"))
        axis.set_title(f"{title} - {mode}")
        axis.set_xlabel("section")
        axis.grid(alpha=0.3)
        axis.legend()
    figure.tight_layout()
    path = os.path.join(out, file_name)
    figure.savefig(path, dpi=120)
    plt.close(figure)
    return path


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--logs", default=DEFAULT_LOGS)
    parser.add_argument("--out", default=os.path.join("docs", "figures"))
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)

    frame = load(args.logs)
    runs = runs_table(frame)
    text, _spread = summary(frame, runs)
    text += damage_sources(frame)
    figures = [plot_box(frame, runs, args.out),
               plot_curves(frame, "skill", "Skill estimate S", "skill_by_section.png", args.out),
               plot_curves(frame, "budget", "Danger budget", "budget_by_section.png", args.out),
               plot_curves(frame[~frame["died"]], "hp_exit", "HP on exit", "hp_by_section.png", args.out)]
    text += "\n## Figures\n\n" + "\n".join(f"![{os.path.basename(p)}]({os.path.basename(p)})" for p in figures) + "\n"
    with open(os.path.join(args.out, "summary.md"), "w", encoding="utf-8", newline="\n") as file:
        file.write(text)
    print(text)


if __name__ == "__main__":
    main()
