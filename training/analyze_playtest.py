"""Analysis of playtest sessions with people (see docs/playtest.md).

Reads the exported logs (*.jsonl) of the playtest phones: the section lines and the
survey lines (type "survey") of sessions started from the hidden menu panel (player
id > 0). Every player played each director mode once (one block per mode), so every
comparison is paired by player.

Writes playtest_summary.md (in Russian) and playtest_survey.png into --out:
  - every survey question: mean with a 95% bootstrap interval per mode; the Friedman
    test over the three modes (players who answered all three); paired Wilcoxon tests
    between modes with Holm correction and the rank-biserial effect size;
  - per player and mode, from the section lines: sections played, deaths, share of
    finished sections with HP 30-70, share of sharp jumps of damage, mean section time;
  - the order effect: mean answers by block position (first, second, third).
The statistics helpers come from analyze.py.

Usage (from the project root):
    python training/analyze_playtest.py --logs <folder with the exported logs> --out docs/figures
Requires pandas, numpy and matplotlib.
"""
import argparse
import glob
import json
import math
import os
import sys

import numpy as np
import pandas as pd

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import analyze  # noqa: E402

QUESTION_NAMES = {
    "interest": "Интерес",
    "difficulty": "Ощущаемая сложность (3 — в самый раз)",
    "fairness": "Честность",
    "smoothness": "Плавность сложности",
    "replay": "Желание сыграть ещё",
    "fatigue": "Усталость",
}
GAMEPLAY = [
    ("sections", "Участков сыграно"),
    ("deaths", "Гибелей"),
    ("corridor", "Доля участков с HP 30–70"),
    ("jump_rate", "Доля резких скачков урона"),
    ("time_mean", "Время участка, с"),
]


def load(folders):
    rows = []
    for folder in folders:
        for path in glob.glob(os.path.join(folder, "**", "*.jsonl"), recursive=True):
            with open(path, encoding="utf-8") as file:
                rows.extend(json.loads(line) for line in file if line.strip())
    for row in rows:
        if "damage" in row:
            row["damage"] = analyze.normalize_sources(row["damage"])
    surveys = [r for r in rows if r.get("type") == "survey" and r.get("player", -1) > 0]
    sections = [r for r in rows if r.get("type", "section") == "section" and r.get("player", -1) > 0]
    if not surveys:
        raise SystemExit(f"No playtest surveys under {folders}")
    survey_frame = pd.DataFrame(surveys)
    answers = pd.json_normalize(survey_frame["answers"])
    survey_frame = pd.concat([survey_frame.drop(columns=["answers"]), answers], axis=1)
    # The same line from two exports of one phone counts once; a player who repeated a
    # block keeps the last survey of it.
    survey_frame = survey_frame.drop_duplicates(["session", "player", "block", "mode"])
    survey_frame = survey_frame.drop_duplicates(["player", "mode"], keep="last").reset_index(drop=True)
    section_frame = pd.DataFrame(sections)
    if not section_frame.empty:
        section_frame = section_frame.drop_duplicates(["session", "run", "section"])
    return survey_frame, section_frame


def friedman(table):
    """Friedman test for k = 3 related samples (rows: players, columns: modes).
    Chi-square with 2 degrees of freedom has the exact survival function exp(-x/2)."""
    table = table.dropna()
    n, k = table.shape
    if n < 2 or k != 3:
        return {"n": n, "chi2": float("nan"), "p": float("nan")}
    ranks = table.rank(axis=1, method="average")
    rank_sums = ranks.sum(axis=0)
    chi2 = 12.0 / (n * k * (k + 1)) * (rank_sums ** 2).sum() - 3.0 * n * (k + 1)
    ties = 0.0
    for _, row in table.iterrows():
        _, counts = np.unique(row.to_numpy(), return_counts=True)
        ties += (counts ** 3 - counts).sum()
    correction = 1.0 - ties / (n * (k ** 3 - k))
    if correction <= 0:
        return {"n": n, "chi2": 0.0, "p": 1.0}
    chi2 /= correction
    return {"n": n, "chi2": chi2, "p": math.exp(-chi2 / 2.0)}


def gameplay_by_player(sections):
    """One row per player and mode."""
    if sections.empty:
        return pd.DataFrame()
    records = []
    for (player, mode), part in sections.groupby(["player", "mode"]):
        finished = part[~part["died"]]
        jumps = []
        for _, run in part.groupby(["session", "run"]):
            damage = run.sort_values("section")["damage_total"].to_numpy(dtype=float)
            jumps.extend(np.abs(np.diff(damage)) > analyze.JUMP_THRESHOLD)
        records.append({
            "player": player, "mode": mode,
            "sections": len(part),
            "deaths": int(part["died"].sum()),
            "corridor": finished["hp_exit"].between(*analyze.HP_CORRIDOR).mean() if len(finished) else np.nan,
            "jump_rate": float(np.mean(jumps)) if jumps else np.nan,
            "time_mean": finished["time"].mean() if len(finished) else np.nan,
        })
    return pd.DataFrame(records)


def paired_rows(table, column, title, modes, rng):
    results = []
    for a, b in analyze.COMPARISONS:
        if a in modes and b in modes:
            result = analyze.compare(table, ["player"], column, a, b, rng)
            if result:
                results.append({"metric": column, "title": title, "bot": "", **result})
    return results


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--logs", nargs="+", required=True)
    parser.add_argument("--out", default=os.path.join("docs", "figures"))
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
    os.makedirs(args.out, exist_ok=True)
    rng = np.random.default_rng(analyze.BOOTSTRAP_SEED)

    surveys, sections = load(args.logs)
    modes = analyze.order(surveys["mode"].unique(), analyze.MODE_ORDER)
    questions = [q for q in QUESTION_NAMES if q in surveys.columns]
    players = sorted(surveys["player"].unique())
    complete = surveys.groupby("player")["mode"].nunique()
    lines = ["# Плейтест: анкеты и игра по режимам", "",
             f"Игроков: {len(players)}, из них прошли все {len(modes)} режима: {(complete == len(modes)).sum()}. "
             f"Анкет: {len(surveys)}. Каждый игрок играл в каждом режиме, поэтому сравнения парные по игроку.", "",
             "Тест Фридмана проверяет, отличаются ли три режима вообще; парные сравнения (Уилкоксон) — какие "
             "именно, с поправкой Холма. r — размер эффекта (ранговая бисериальная корреляция, r > 0 — у A больше). "
             "При 15–30 игроках заметить можно только крупные различия: незначимый результат не значит, что режимы "
             "одинаковы.", "",
             "## Анкета: средние по режимам [95% ДИ]", "",
             "| Вопрос | " + " | ".join(modes) + " | Фридман: χ², p (игроков) |",
             "| --- | " + " | ".join("---" for _ in modes) + " | --- |"]
    survey_results = []
    for q in questions:
        cells = []
        for mode in modes:
            values = surveys[surveys["mode"] == mode][q].dropna()
            low, high = analyze.bootstrap_ci(values, np.mean, rng)
            cells.append(f"{analyze.fmt(values.mean())} {analyze.fmt_ci((low, high))}")
        wide = surveys.pivot_table(index="player", columns="mode", values=q)
        test = friedman(wide[[m for m in modes if m in wide.columns]]) if len(modes) == 3 else {"n": 0, "chi2": float("nan"), "p": float("nan")}
        p_text = analyze.fmt_p(test["p"]) if not math.isnan(test["p"]) else "–"
        lines.append(f"| {QUESTION_NAMES[q]} | " + " | ".join(cells) + f" | {analyze.fmt(test['chi2'])}, {p_text} ({test['n']}) |")
        survey_results += paired_rows(surveys.rename(columns={q: f"q_{q}"}), f"q_{q}", QUESTION_NAMES[q], modes, rng)
    if survey_results:
        for result, p_holm in zip(survey_results, analyze.holm([r["p"] for r in survey_results])):
            result["p_holm"] = p_holm
            result["primary"] = True
        lines += ["", "### Парные сравнения ответов", ""]
        lines += analyze.result_rows(survey_results, {})

    gameplay = gameplay_by_player(sections)
    if not gameplay.empty:
        lines += ["", "## Игра по режимам (по игрокам)", "",
                  "| Метрика | " + " | ".join(modes) + " |", "| --- | " + " | ".join("---" for _ in modes) + " |"]
        game_results = []
        for column, title in GAMEPLAY:
            cells = []
            for mode in modes:
                values = gameplay[gameplay["mode"] == mode][column].dropna()
                low, high = analyze.bootstrap_ci(values, np.mean, rng)
                cells.append(f"{analyze.fmt(values.mean())} {analyze.fmt_ci((low, high))}")
            lines.append(f"| {title} | " + " | ".join(cells) + " |")
            game_results += paired_rows(gameplay, column, title, modes, rng)
        if game_results:
            for result, p_holm in zip(game_results, analyze.holm([r["p"] for r in game_results])):
                result["p_holm"] = p_holm
                result["primary"] = False
            lines += ["", "### Парные сравнения игры", ""]
            lines += analyze.result_rows(game_results, {})

    lines += ["", "## Порядок блоков", "",
              "Средние ответы по номеру блока (независимо от режима): если они заметно меняются от первого блока к "
              "третьему, на ответы влияют усталость или привыкание; план порядка режимов это уравновешивает.", "",
              "| Вопрос | Блок 1 | Блок 2 | Блок 3 |", "| --- | --- | --- | --- |"]
    for q in questions:
        by_block = surveys.groupby("block")[q].mean()
        lines.append(f"| {QUESTION_NAMES[q]} | " + " | ".join(analyze.fmt(by_block.get(b, float("nan"))) for b in range(3)) + " |")

    figure_path = plot_survey(surveys, questions, modes, args.out, rng)
    lines += ["", "## График", "", f"![Анкета по режимам]({os.path.basename(figure_path)})"]
    text = "\n".join(lines) + "\n"
    with open(os.path.join(args.out, "playtest_summary.md"), "w", encoding="utf-8", newline="\n") as file:
        file.write(text)
    print(text)


def plot_survey(surveys, questions, modes, out, rng):
    import matplotlib.pyplot as plt
    figure, axis = plt.subplots(figsize=(11, 4.4))
    width = 0.8 / len(modes)
    for k, mode in enumerate(modes):
        means, low_err, high_err = [], [], []
        for q in questions:
            values = surveys[surveys["mode"] == mode][q].dropna()
            low, high = analyze.bootstrap_ci(values, np.mean, rng)
            means.append(values.mean())
            low_err.append(values.mean() - low if not np.isnan(low) else 0.0)
            high_err.append(high - values.mean() if not np.isnan(high) else 0.0)
        positions = np.arange(len(questions)) + (k - (len(modes) - 1) / 2) * width
        axis.bar(positions, means, width=width * 0.92, color=analyze.MODE_COLORS.get(mode, analyze.INK), alpha=0.85,
                 yerr=[low_err, high_err], ecolor=analyze.INK_SECONDARY, capsize=3, label=mode)
    axis.set_xticks(range(len(questions)), [QUESTION_NAMES[q].split(" (")[0] for q in questions])
    axis.set_ylim(1, 5)
    analyze.style_axis(axis, "Ответы игроков по режимам (1–5, 95% ДИ)", "Средний ответ")
    analyze.legend_for(figure, modes)
    figure.tight_layout(rect=(0, 0, 1, 0.92))
    return analyze.save(figure, out, "playtest_survey.png")


if __name__ == "__main__":
    main()
