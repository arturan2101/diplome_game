"""Comparison of the directors on bot logs (one JSON line per section, see docs/design.md).

Reads every *.jsonl under the given folders and compares the director modes run by run.
The unit of analysis is one run (one bot, one seed, one mode, one experiment series).
Runs of different modes with the same seed, bot and series form a pair, so every
comparison is paired. Writes docs/figures/summary.md (in Russian, for the thesis) and
the figures next to it.

Per run:
  cleared     sections finished before death (a run that hit the section cap counts the cap)
  depth       deepest depth reached (shown from 1)
  hp_mean     mean HP on exit of the finished sections
  corridor    share of finished sections with HP on exit in 30-70 ("hard but passable")
  jump_rate   share of neighbouring sections whose damage differs by more than the
              jump threshold (sharp jumps of difficulty), death section included
  time_mean   mean time of the finished sections, seconds
  early_hp    mean HP on exit over sections 1-6, where the death section and the
              sections after it count as 0: the same sections for every bot
Per seed (all three bots played it): spread_early and spread_hp, the max - min of the
bots' early_hp and hp_mean: how far apart players of different skill end up.

Statistics: mean and median with a 95% percentile bootstrap interval; paired Wilcoxon
signed-rank test (zeros dropped, average ranks for ties, normal approximation with tie
and continuity corrections); Holm correction within each family of tests of one series
(primary: the hypothesis "hard but passable, stable, close for every skill" - spread
between bots, HP corridor share, jump rate; secondary: everything else); effect size as
the matched-pairs rank-biserial correlation r = (W+ - W-) / (W+ + W-).

Usage (from the project root):
    python training/analyze.py --logs <sim_logs>/experiment18 --out docs/figures
Requires pandas, numpy and matplotlib.
"""
import argparse
import glob
import json
import math
import os
import sys

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt  # noqa: E402
import numpy as np  # noqa: E402
import pandas as pd  # noqa: E402

DEFAULT_LOGS = os.path.join(os.environ.get("APPDATA", ""), "Godot", "app_userdata", "Ruins", "sim_logs", "experiment")
SERIES_ORDER = ["clean", "full"]
SERIES_NAMES = {"clean": "чистая серия (без босса, заклинаний и редкости)", "full": "полная игра"}
MODE_ORDER = ["RANDOM", "RULES", "LEARNED"]
BOT_ORDER = ["weak", "mid", "strong"]
BOT_NAMES = {"weak": "слабый", "mid": "средний", "strong": "сильный"}
# Pairs compared, (A, B): the table reports A - B.
COMPARISONS = [("RULES", "RANDOM"), ("LEARNED", "RANDOM"), ("LEARNED", "RULES")]
# Validated categorical palette (dataviz reference slots 1-3), fixed order by mode.
MODE_COLORS = {"RANDOM": "#2a78d6", "RULES": "#eb6834", "LEARNED": "#1baf7a"}
INK = "#0b0b0b"
INK_SECONDARY = "#52514e"
GRID = "#e4e3df"
SURFACE = "#fcfcfb"
HP_CORRIDOR = (30, 70)
EARLY_SECTIONS = 6
JUMP_THRESHOLD = 30
BOOTSTRAP_SAMPLES = 5000
BOOTSTRAP_SEED = 20261113
ALPHA = 0.05
# Curves by section index stop where fewer runs than this are still alive.
MIN_RUNS_FOR_CURVE = 10

METRICS = [
    # (column, name in the report, unit / note, True if larger is the "hard but fair" direction, None if neutral)
    ("corridor", "Доля участков с HP 30–70", "доля", True),
    ("hp_mean", "HP на выходе, среднее по пройденным участкам", "HP", None),
    ("early_hp", "HP на выходе, участки 1–6 (гибель = 0)", "HP", None),
    ("jump_rate", "Доля резких скачков урона между соседними участками", "доля", False),
    ("cleared", "Пройдено участков (глубина гибели)", "участков", None),
    ("depth", "Достигнутая глубина", "глубина", None),
    ("time_mean", "Время участка, среднее", "с", None),
]
SPREAD_METRICS = [
    ("spread_early", "Разброс HP между ботами, участки 1–6 (max − min)", "HP"),
    ("spread_hp", "Разброс HP между ботами, пройденные участки (max − min)", "HP"),
]
# Metrics of the main hypothesis; Holm corrects them as one family, the rest as another.
PRIMARY_METRICS = {"spread_early", "corridor", "jump_rate"}


# --- loading ---------------------------------------------------------------

def load(folders):
    rows = []
    for folder in folders:
        for path in glob.glob(os.path.join(folder, "**", "*.jsonl"), recursive=True):
            with open(path, encoding="utf-8") as file:
                rows.extend(json.loads(line) for line in file if line.strip())
    if not rows:
        raise SystemExit(f"No log lines under {folders}")
    frame = pd.DataFrame(rows)
    frame["bot"] = frame["bot"].fillna("") if "bot" in frame else ""
    frame["series"] = frame["series"].fillna("full") if "series" in frame else "full"
    frame["run_id"] = frame["session"] + "#" + frame["run"].astype(str)
    return frame


def order(values, preferred):
    values = list(values)
    return [v for v in preferred if v in values] + sorted(v for v in values if v not in preferred)


# --- per-run and per-seed metrics ---------------------------------------------

def run_metrics(frame):
    """One row per run with the metrics described in the module docstring."""
    records = []
    for (series, mode, bot, run_id), part in frame.groupby(["series", "mode", "bot", "run_id"]):
        part = part.sort_values("section")
        died = bool(part["died"].any())
        finished = part[~part["died"]]
        damage = part["damage_total"].to_numpy(dtype=float)
        jumps = np.abs(np.diff(damage)) > JUMP_THRESHOLD if len(damage) > 1 else np.array([])
        early = np.zeros(EARLY_SECTIONS)
        for row in finished.itertuples():
            if row.section < EARLY_SECTIONS:
                early[int(row.section)] = row.hp_exit
        records.append({
            "series": series, "mode": mode, "bot": bot, "run_id": run_id, "seed": int(part["seed"].iloc[0]),
            "died": died,
            "cleared": len(finished),
            "depth": int(part["depth"].max()) + 1,
            "hp_mean": finished["hp_exit"].mean() if len(finished) else np.nan,
            "corridor": finished["hp_exit"].between(*HP_CORRIDOR).mean() if len(finished) else np.nan,
            "jump_rate": jumps.mean() if len(jumps) else np.nan,
            "time_mean": finished["time"].mean() if len(finished) else np.nan,
            "early_hp": early.mean(),
        })
    runs = pd.DataFrame(records)
    # A seed played twice by the same bot in the same mode (a rerun) keeps its first run only.
    return runs.drop_duplicates(["series", "mode", "bot", "seed"])


def spreads_by_seed(runs):
    """One row per series, mode and seed that all bots played: max - min between the bots."""
    records = []
    bots = order(runs["bot"].unique(), BOT_ORDER)
    for (series, mode, seed), part in runs.groupby(["series", "mode", "seed"]):
        if set(part["bot"]) != set(bots) or len(bots) < 2:
            continue
        records.append({
            "series": series, "mode": mode, "seed": seed,
            "spread_early": part["early_hp"].max() - part["early_hp"].min(),
            "spread_hp": part["hp_mean"].max() - part["hp_mean"].min(),
        })
    return pd.DataFrame(records)


# --- statistics --------------------------------------------------------------------

def bootstrap_ci(values, statistic, rng):
    values = np.asarray(values, dtype=float)
    values = values[~np.isnan(values)]
    if len(values) < 2:
        return (np.nan, np.nan)
    resamples = values[rng.integers(0, len(values), size=(BOOTSTRAP_SAMPLES, len(values)))]
    return tuple(np.percentile(statistic(resamples, axis=1), [2.5, 97.5]))


def wilcoxon(differences):
    """Paired Wilcoxon signed-rank test on A - B. Returns n, p (two-sided) and the
    rank-biserial effect size r (positive: A tends to be larger)."""
    d = np.asarray(differences, dtype=float)
    d = d[~np.isnan(d)]
    d = d[d != 0.0]
    n = len(d)
    if n == 0:
        return {"n": 0, "p": 1.0, "r": 0.0}
    ranks = pd.Series(np.abs(d)).rank(method="average").to_numpy()
    w_plus = ranks[d > 0].sum()
    w_minus = ranks[d < 0].sum()
    mean = n * (n + 1) / 4.0
    _, ties = np.unique(np.abs(d), return_counts=True)
    variance = n * (n + 1) * (2 * n + 1) / 24.0 - (ties ** 3 - ties).sum() / 48.0
    shift = w_plus - mean
    if variance <= 0:
        return {"n": n, "p": 1.0, "r": 0.0}
    z = (shift - 0.5 * np.sign(shift)) / math.sqrt(variance)
    return {"n": n, "p": math.erfc(abs(z) / math.sqrt(2.0)), "r": (w_plus - w_minus) / (w_plus + w_minus)}


def holm(pvalues):
    p = np.asarray(pvalues, dtype=float)
    adjusted = np.empty_like(p)
    running = 0.0
    for rank, index in enumerate(np.argsort(p)):
        running = max(running, min(1.0, (len(p) - rank) * p[index]))
        adjusted[index] = running
    return adjusted


def compare(table, keys, column, mode_a, mode_b, rng):
    """Paired comparison of one metric: rows of mode A and mode B matched on keys."""
    a = table[table["mode"] == mode_a].set_index(keys)[column]
    b = table[table["mode"] == mode_b].set_index(keys)[column]
    joined = pd.concat([a.rename("a"), b.rename("b")], axis=1, join="inner").dropna()
    if joined.empty:
        return None
    differences = joined["a"] - joined["b"]
    test = wilcoxon(differences)
    return {
        "mode_a": mode_a, "mode_b": mode_b, "pairs": len(joined),
        "mean_a": joined["a"].mean(), "ci_a": bootstrap_ci(joined["a"], np.mean, rng),
        "mean_b": joined["b"].mean(), "ci_b": bootstrap_ci(joined["b"], np.mean, rng),
        "median_a": joined["a"].median(), "median_b": joined["b"].median(),
        "diff_median": differences.median(), "diff_ci": bootstrap_ci(differences, np.median, rng),
        "p": test["p"], "r": test["r"],
    }


def effect_words(r):
    size = abs(r)
    if size < 0.1:
        return "пренебрежимо малый"
    if size < 0.3:
        return "малый"
    if size < 0.5:
        return "средний"
    return "большой"


# --- report -------------------------------------------------------------------------

def fmt(value, digits=2):
    if value is None or (isinstance(value, float) and math.isnan(value)):
        return "–"
    return f"{value:.{digits}f}".replace(".", ",")


def fmt_ci(ci, digits=2):
    return f"[{fmt(ci[0], digits)}; {fmt(ci[1], digits)}]"


def fmt_p(p):
    if p < 0.001:
        return "< 0,001"
    return fmt(p, 3)


def p_phrase(p):
    """"p < 0,001" or "p = 0,012" for running text."""
    return "p < 0,001" if p < 0.001 else f"p = {fmt(p, 3)}"


def series_results(runs, spreads, series, modes, rng):
    """All comparisons of one series, with Holm-adjusted p over the whole series."""
    results = []
    pairs = [(a, b) for a, b in COMPARISONS if a in modes and b in modes]
    part_spreads = spreads[spreads["series"] == series]
    for column, title, unit in SPREAD_METRICS:
        for a, b in pairs:
            result = compare(part_spreads, ["seed"], column, a, b, rng)
            if result:
                results.append({"metric": column, "title": title, "unit": unit, "bot": "", **result})
    part_runs = runs[runs["series"] == series]
    for column, title, unit, _ in METRICS:
        for bot in order(part_runs["bot"].unique(), BOT_ORDER):
            for a, b in pairs:
                result = compare(part_runs[part_runs["bot"] == bot], ["seed"], column, a, b, rng)
                if result:
                    results.append({"metric": column, "title": title, "unit": unit, "bot": bot, **result})
    for primary in (True, False):
        family = [r for r in results if (r["metric"] in PRIMARY_METRICS) == primary]
        for result, p_holm in zip(family, holm([r["p"] for r in family])):
            result["p_holm"] = p_holm
            result["primary"] = primary
    return results


def result_rows(results, digits):
    lines = ["| Метрика | Бот | Сравнение (A − B) | A: среднее [95% ДИ] | B: среднее [95% ДИ] | Медианы A / B "
             "| Медиана разностей [95% ДИ] | Пар | p | p (Холм) | r | Семейство |",
             "| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |"]
    for r in results:
        d = digits.get(r["metric"], 2)
        lines.append(
            f"| {r['title']} | {BOT_NAMES.get(r['bot'], r['bot']) or 'все'} | {r['mode_a']} − {r['mode_b']} "
            f"| {fmt(r['mean_a'], d)} {fmt_ci(r['ci_a'], d)} | {fmt(r['mean_b'], d)} {fmt_ci(r['ci_b'], d)} "
            f"| {fmt(r['median_a'], d)} / {fmt(r['median_b'], d)} | {fmt(r['diff_median'], d)} {fmt_ci(r['diff_ci'], d)} "
            f"| {r['pairs']} | {fmt_p(r['p'])} | {fmt_p(r['p_holm'])} | {fmt(r['r'])} "
            f"| {'первичная' if r['primary'] else 'вторичная'} |")
    return lines


def findings(results):
    """Careful plain-language notes for the primary metrics."""
    notes = []
    for r in results:
        if not r["primary"]:
            continue
        who = f"{BOT_NAMES[r['bot']]} бот" if r["bot"] else "все боты"
        what = f"{r['title']} ({who}), {r['mode_a']} против {r['mode_b']}"
        if r["p_holm"] < ALPHA:
            direction = "выше" if r["diff_median"] > 0 or (r["diff_median"] == 0 and r["r"] > 0) else "ниже"
            notes.append(f"- {what}: у {r['mode_a']} {direction}, разница значима после поправки Холма "
                         f"({p_phrase(r['p_holm'])}), эффект {effect_words(r['r'])} (r = {fmt(r['r'])}).")
        else:
            notes.append(f"- {what}: значимой разницы нет (с поправкой Холма {p_phrase(r['p_holm'])}, "
                         f"r = {fmt(r['r'])}).")
    return notes


def write_summary(frame, runs, spreads, out, figures):
    rng = np.random.default_rng(BOOTSTRAP_SEED)
    modes = order(runs["mode"].unique(), MODE_ORDER)
    seeds = sorted(runs["seed"].unique())
    digits = {"corridor": 3, "jump_rate": 3, "cleared": 1, "depth": 2, "time_mean": 1,
              "hp_mean": 1, "early_hp": 1, "spread_early": 1, "spread_hp": 1}
    lines = ["# Сравнение директоров на ботах", "",
             f"Логи: {len(runs)} забегов, {len(frame)} участков. Режимы: {', '.join(modes)}. "
             f"Сиды: {len(seeds)} ({seeds[0]}–{seeds[-1]}), одинаковые для всех режимов и ботов, "
             "поэтому сравнение парное: забеги разных режимов с одним сидом, ботом и серией сравниваются между собой.", "",
             "**Как читать.** Для каждой метрики — среднее с 95% доверительным интервалом (бутстрэп, "
             f"{BOOTSTRAP_SAMPLES} выборок), медианы, медиана парных разностей A − B. p — двусторонний парный "
             "критерий Уилкоксона; p (Холм) — с поправкой Холма внутри семейства сравнений серии: первичные "
             "метрики (гипотеза «сложно, но проходимо, ровно и близко для разных игроков»: разброс HP между ботами "
             "на участках 1–6, доля участков с HP 30–70, доля резких скачков) и вторичные (остальные, описательные); "
             "значимым считается p (Холм) < 0,05. r — размер эффекта (ранговая бисериальная корреляция, от −1 до 1; r > 0 — у A больше; "
             "|r| около 0,1 — малый, 0,3 — средний, 0,5 — большой). Незначимая разница не доказывает, что режимы "
             "одинаковы: она значит лишь, что данных не хватает, чтобы их различить.", ""]
    for series in order(runs["series"].unique(), SERIES_ORDER):
        results = series_results(runs, spreads, series, modes, rng)
        part = runs[runs["series"] == series]
        lines += [f"## Серия {series}: {SERIES_NAMES.get(series, series)}", "",
                  f"Забегов: {len(part)} ({', '.join(f'{m}: {(part['mode'] == m).sum()}' for m in modes)}).", "",
                  "### Главное", ""]
        lines += findings(results) or ["- Нет данных для сравнения."]
        lines += ["", "### Разброс между ботами (по сидам)", ""]
        lines += result_rows([r for r in results if not r["bot"]], digits)
        lines += ["", "### Метрики по ботам", ""]
        lines += result_rows([r for r in results if r["bot"]], digits)
        lines.append("")
    lines += ["## Определения", "",
              "- **Забег** — единица анализа: один бот, один сид, один режим, одна серия. Участок с гибелью не "
              "считается пройденным.",
              f"- **Доля участков с HP {HP_CORRIDOR[0]}–{HP_CORRIDOR[1]}** — «сложно, но проходимо»: доля пройденных "
              "участков, после которых у бота осталось от 30 до 70 HP из 100.",
              f"- **HP на выходе, участки 1–{EARLY_SECTIONS}** — среднее HP после первых шести участков, где участок "
              "гибели и следующие за ним считаются как 0. Так все боты сравниваются на одних и тех же участках.",
              f"- **Разброс между ботами** — для каждого сида: самое большое минус самое маленькое значение среди "
              "трёх ботов. Меньше — директор держит игроков разного уровня ближе друг к другу.",
              f"- **Резкий скачок** — соседние участки, урон в которых отличается больше чем на {JUMP_THRESHOLD} HP "
              "(30% здоровья); в долю входят все пары соседних участков забега, включая участок гибели.",
              "- **Пройдено участков** — до гибели; забег, дошедший до предела симуляции, считается с этим пределом.",
              "- **Время участка** — среднее время пройденных участков в секундах игрового времени.", "",
              "## Графики", ""]
    lines += [f"![{name}]({os.path.basename(path)})" for name, path in figures]
    with open(os.path.join(out, "summary.md"), "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines) + "\n")
    return "\n".join(lines)


# --- figures ---------------------------------------------------------------------

def style_axis(axis, title, ylabel):
    axis.set_facecolor(SURFACE)
    axis.set_title(title, color=INK, fontsize=11)
    axis.set_ylabel(ylabel, color=INK_SECONDARY)
    axis.tick_params(colors=INK_SECONDARY, labelsize=9)
    axis.grid(axis="y", color=GRID, linewidth=0.8)
    axis.set_axisbelow(True)
    for side in ("top", "right"):
        axis.spines[side].set_visible(False)
    for side in ("left", "bottom"):
        axis.spines[side].set_color(GRID)


def legend_for(figure, modes):
    handles = [plt.Line2D([0], [0], color=MODE_COLORS.get(m, INK), linewidth=6) for m in modes]
    figure.legend(handles, modes, loc="upper center", ncol=len(modes), frameon=False, fontsize=10)


def save(figure, out, name):
    path = os.path.join(out, name)
    figure.savefig(path, dpi=130, facecolor=SURFACE)
    plt.close(figure)
    return path


def plot_spread(spreads, modes, series_list, out):
    figure, axes = plt.subplots(1, len(series_list), figsize=(5.5 * len(series_list), 4.4), squeeze=False)
    rng = np.random.default_rng(1)
    for axis, series in zip(axes[0], series_list):
        part = spreads[spreads["series"] == series]
        data = [part[part["mode"] == m]["spread_early"].dropna() for m in modes]
        boxes = axis.boxplot(data, widths=0.5, patch_artist=True, showfliers=False,
                             medianprops={"color": INK, "linewidth": 2})
        for patch, mode in zip(boxes["boxes"], modes):
            patch.set_facecolor(MODE_COLORS.get(mode, INK))
            patch.set_alpha(0.35)
            patch.set_edgecolor(MODE_COLORS.get(mode, INK))
        for i, (values, mode) in enumerate(zip(data, modes), start=1):
            axis.scatter(i + rng.uniform(-0.15, 0.15, len(values)), values, s=10, color=MODE_COLORS.get(mode, INK),
                         alpha=0.5, linewidths=0)
        axis.set_xticks(range(1, len(modes) + 1), modes)
        style_axis(axis, SERIES_NAMES.get(series, series), "Разброс HP между ботами, участки 1–6")
    legend_for(figure, modes)
    figure.tight_layout(rect=(0, 0, 1, 0.93))
    return save(figure, out, "fig1_spread_between_bots.png")


def plot_corridor(runs, modes, series_list, out):
    figure, axes = plt.subplots(1, len(series_list), figsize=(5.5 * len(series_list), 4.4), squeeze=False, sharey=True)
    rng = np.random.default_rng(2)
    width = 0.8 / len(modes)
    for axis, series in zip(axes[0], series_list):
        part = runs[runs["series"] == series]
        bots = order(part["bot"].unique(), BOT_ORDER)
        for k, mode in enumerate(modes):
            means, errors_low, errors_high = [], [], []
            for bot in bots:
                values = part[(part["mode"] == mode) & (part["bot"] == bot)]["corridor"].dropna()
                low, high = bootstrap_ci(values, np.mean, rng)
                means.append(values.mean())
                errors_low.append(values.mean() - low)
                errors_high.append(high - values.mean())
            positions = np.arange(len(bots)) + (k - (len(modes) - 1) / 2) * width
            axis.bar(positions, means, width=width * 0.92, color=MODE_COLORS.get(mode, INK), alpha=0.85,
                     yerr=[errors_low, errors_high], ecolor=INK_SECONDARY, capsize=3, label=mode)
        axis.set_xticks(range(len(bots)), [BOT_NAMES.get(b, b) for b in bots])
        axis.set_ylim(0, 1)
        style_axis(axis, SERIES_NAMES.get(series, series),
                   "Доля участков с HP 30–70 (95% ДИ)" if axis is axes[0][0] else "")
    legend_for(figure, modes)
    figure.tight_layout(rect=(0, 0, 1, 0.93))
    return save(figure, out, "fig2_hp_corridor.png")


def plot_curves(frame, column, ylabel, file_name, modes, series_list, out):
    bots = order(frame["bot"].unique(), BOT_ORDER)
    figure, axes = plt.subplots(len(series_list), len(bots), figsize=(4.6 * len(bots), 3.6 * len(series_list)),
                                squeeze=False, sharey=True)
    for row, series in enumerate(series_list):
        for col, bot in enumerate(bots):
            axis = axes[row][col]
            part = frame[(frame["series"] == series) & (frame["bot"] == bot)]
            for mode in modes:
                by_section = part[part["mode"] == mode].groupby("section")[column]
                counts = by_section.count()
                mean = by_section.mean()[counts >= MIN_RUNS_FOR_CURVE]
                axis.plot(mean.index + 1, mean.values, color=MODE_COLORS.get(mode, INK), linewidth=2,
                          marker="o", markersize=3, label=mode)
            style_axis(axis, f"{SERIES_NAMES.get(series, series).split(' (')[0]}, {BOT_NAMES.get(bot, bot)} бот",
                       ylabel if col == 0 else "")
            axis.set_xlabel("участок", color=INK_SECONDARY)
    legend_for(figure, modes)
    figure.tight_layout(rect=(0, 0, 1, 0.95))
    return save(figure, out, file_name)


def plot_cleared(runs, modes, series_list, out):
    figure, axes = plt.subplots(1, len(series_list), figsize=(5.5 * len(series_list), 4.4), squeeze=False, sharey=True)
    width = 0.8 / len(modes)
    for axis, series in zip(axes[0], series_list):
        part = runs[runs["series"] == series]
        bots = order(part["bot"].unique(), BOT_ORDER)
        for k, mode in enumerate(modes):
            data = [part[(part["mode"] == mode) & (part["bot"] == bot)]["cleared"] for bot in bots]
            positions = np.arange(len(bots)) + (k - (len(modes) - 1) / 2) * width
            boxes = axis.boxplot(data, positions=positions, widths=width * 0.85, patch_artist=True, showfliers=False,
                                 medianprops={"color": INK, "linewidth": 2})
            for patch in boxes["boxes"]:
                patch.set_facecolor(MODE_COLORS.get(mode, INK))
                patch.set_alpha(0.55)
                patch.set_edgecolor(MODE_COLORS.get(mode, INK))
        axis.set_xticks(range(len(bots)), [BOT_NAMES.get(b, b) for b in bots])
        style_axis(axis, SERIES_NAMES.get(series, series), "Пройдено участков до гибели" if axis is axes[0][0] else "")
    legend_for(figure, modes)
    figure.tight_layout(rect=(0, 0, 1, 0.93))
    return save(figure, out, "fig4_sections_cleared.png")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--logs", nargs="+", default=[DEFAULT_LOGS])
    parser.add_argument("--out", default=os.path.join("docs", "figures"))
    parser.add_argument("--seed-min", type=int, default=None, help="use only runs with seed >= this")
    parser.add_argument("--seed-max", type=int, default=None, help="use only runs with seed <= this")
    args = parser.parse_args()
    os.makedirs(args.out, exist_ok=True)
    # The Windows console is not UTF-8 by default; the report uses Cyrillic and math signs.
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    frame = load(args.logs)
    # Exploration runs are training data for the learned director, not a mode to compare.
    frame = frame[frame["mode"] != "EXPLORE"]
    if args.seed_min is not None:
        frame = frame[frame["seed"] >= args.seed_min]
    if args.seed_max is not None:
        frame = frame[frame["seed"] <= args.seed_max]
    runs = run_metrics(frame)
    spreads = spreads_by_seed(runs)
    modes = order(runs["mode"].unique(), MODE_ORDER)
    series_list = order(runs["series"].unique(), SERIES_ORDER)
    finished = frame[~frame["died"]]
    figures = [
        ("Рис. 1. Разброс HP между ботами по сидам", plot_spread(spreads, modes, series_list, args.out)),
        ("Рис. 2. Доля участков в коридоре HP 30–70", plot_corridor(runs, modes, series_list, args.out)),
        ("Рис. 3. HP на выходе по номеру участка", plot_curves(finished, "hp_exit", "HP на выходе",
                                                               "fig3_hp_by_section.png", modes, series_list, args.out)),
        ("Рис. 4. Пройдено участков до гибели", plot_cleared(runs, modes, series_list, args.out)),
        ("Доп. рисунок. Бюджет опасности по номеру участка", plot_curves(frame, "budget", "бюджет опасности",
                                                                       "fig5_budget_by_section.png", modes,
                                                                       series_list, args.out)),
    ]
    print(write_summary(frame, runs, spreads, args.out, figures))


if __name__ == "__main__":
    main()
