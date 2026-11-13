"""Offline training of the learned director: a contextual bandit (LinUCB) trained on the
logs of the exploring director (--mode=explore). See docs/design.md.

Every logged section gives (x, a, r):
  x  the context features the game computed (director/bandit_context.gd), logged as
     "context", so training uses exactly the numbers the game will use;
  a  the action the exploring director picked uniformly at random (logged as "action";
     director/bandit_actions.gd: section type x budget level x dominant enemy);
  r  the reward of the section, as in docs/design.md:
       -1    the player died in the section
       -0.5  the player took no damage at all (too easy)
       +1    HP on exit within 30-70 and the section took at most 2 * T_ref
        0    otherwise
For every action a ridge regression - the model of LinUCB - is fitted:
    A_a = lambda * I + sum(x x^T),  b_a = sum(r x),  theta_a = A_a^-1 b_a
The game picks argmax_a theta_a . x; alpha = 0, so it does not explore on players.

Seeds: every VALIDATION_EVERY-th exploration seed is kept for validation (reward
prediction error; value of the learned policy by inverse propensity weighting, possible
because the exploring policy picked each action with probability 1/K). The final
parameters are refit on all exploration seeds. The test seeds of the comparison
(TEST_SEEDS) must not be in the training data; the script refuses them.

Usage (from the project root):
    python training/train_bandit.py --logs <sim_logs>/explore19 --out director/learned_params.json \
        --report docs/figures/bandit.md
Requires pandas and numpy.
"""
import argparse
import glob
import json
import os
import sys
from datetime import date

import numpy as np
import pandas as pd

# Must match director/bandit_context.gd FEATURE_NAMES (the game checks the names).
FEATURES = ["bias", "skill", "hp", "depth", "last_result", "hurt_by_skeleton", "hurt_by_archer", "hurt_by_beetle"]
# Must match director/bandit_actions.gd: index = (type * levels + level) * enemies + enemy.
TYPES = ["build", "peak", "rest"]
LEVELS = ["low", "mid", "high"]
ENEMIES = ["skeleton", "archer", "beetle"]
ACTIONS = [f"{t}/{lv}/{e}" for t in TYPES for lv in LEVELS for e in ENEMIES]
TEST_SEEDS = range(5000, 5100)
LAMBDA = 1.0
VALIDATION_EVERY = 5
HP_CORRIDOR = (30, 70)
TIME_FACTOR = 2.0
BOOTSTRAP_SAMPLES = 2000
RNG_SEED = 20261113
BOT_NAMES = {"weak": "слабый", "mid": "средний", "strong": "сильный"}


def load(folders):
    rows = []
    for folder in folders:
        for path in glob.glob(os.path.join(folder, "**", "*.jsonl"), recursive=True):
            with open(path, encoding="utf-8") as file:
                rows.extend(json.loads(line) for line in file if line.strip())
    frame = pd.DataFrame(rows)
    if frame.empty or "action" not in frame:
        raise SystemExit(f"No exploration logs with actions under {folders}")
    frame = frame[(frame["mode"] == "EXPLORE") & (frame["action"] >= 0)]
    bad = frame[frame["context"].apply(len) != len(FEATURES)]
    if not bad.empty:
        raise SystemExit(f"{len(bad)} sections have a context of another length than {len(FEATURES)}")
    return frame.reset_index(drop=True)


def rewards(frame):
    corridor = frame["hp_exit"].between(*HP_CORRIDOR) & (frame["time"] <= TIME_FACTOR * frame["t_ref"])
    reward = np.where(corridor, 1.0, 0.0)
    reward = np.where(frame["damage_total"] == 0, -0.5, reward)
    return np.where(frame["died"], -1.0, reward)


def fit(x, actions, reward, k, lam):
    d = x.shape[1]
    theta = np.zeros((k, d))
    a_inverse = np.zeros((k, d, d))
    for a in range(k):
        xa = x[actions == a]
        matrix = lam * np.eye(d) + xa.T @ xa
        a_inverse[a] = np.linalg.inv(matrix)
        theta[a] = a_inverse[a] @ (xa.T @ reward[actions == a])
    return theta, a_inverse


def greedy(theta, x):
    return np.argmax(x @ theta.T, axis=1)


def ips(chosen, actions, reward, k):
    """Per-sample IPS terms; their mean estimates the policy's expected reward."""
    return (chosen == actions) * reward * k


def bootstrap_mean_ci(values, rng):
    resamples = values[rng.integers(0, len(values), size=(BOOTSTRAP_SAMPLES, len(values)))]
    return np.percentile(resamples.mean(axis=1), [2.5, 97.5])


def fmt(value, digits=3):
    return f"{value:.{digits}f}".replace(".", ",")


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--logs", nargs="+", required=True)
    parser.add_argument("--out", default=os.path.join("director", "learned_params.json"))
    parser.add_argument("--report", default=os.path.join("docs", "figures", "bandit.md"))
    parser.add_argument("--lam", type=float, default=LAMBDA)
    args = parser.parse_args()
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")

    frame = load(args.logs)
    overlap = sorted(set(frame["seed"]) & set(TEST_SEEDS))
    if overlap:
        raise SystemExit(f"Exploration data uses test seeds {overlap[:5]}...: train and test must not share seeds")
    k = len(ACTIONS)
    x = np.array(frame["context"].tolist(), dtype=float)
    actions = frame["action"].to_numpy(dtype=int)
    reward = rewards(frame)
    seeds = np.array(sorted(frame["seed"].unique()))
    validation_seeds = set(seeds[::VALIDATION_EVERY])
    is_validation = frame["seed"].isin(validation_seeds).to_numpy()
    train, valid = ~is_validation, is_validation
    rng = np.random.default_rng(RNG_SEED)

    # Validation: fit on the training seeds only.
    theta, _ = fit(x[train], actions[train], reward[train], k, args.lam)
    action_means = np.array([reward[train][actions[train] == a].mean() for a in range(k)])
    predicted = np.sum(x[valid] * theta[actions[valid]], axis=1)
    mse_model = np.mean((predicted - reward[valid]) ** 2)
    mse_baseline = np.mean((action_means[actions[valid]] - reward[valid]) ** 2)
    chosen = greedy(theta, x[valid])
    value_terms = ips(chosen, actions[valid], reward[valid], k)
    value_learned = value_terms.mean()
    value_ci = bootstrap_mean_ci(value_terms, rng)
    value_uniform = reward[valid].mean()
    best_fixed = int(np.argmax(action_means))
    fixed_terms = ips(np.full(valid.sum(), best_fixed), actions[valid], reward[valid], k)

    # Final model: all exploration seeds.
    theta_all, a_inverse_all = fit(x, actions, reward, k, args.lam)
    parameters = {
        "version": 1,
        "trained": date.today().isoformat(),
        "features": FEATURES,
        "actions": ACTIONS,
        "alpha": 0.0,
        "lambda": args.lam,
        "reward": "-1 death; -0.5 no damage; +1 HP on exit 30-70 within 2*T_ref; 0 otherwise",
        "samples": int(len(frame)),
        "seeds": [int(seeds[0]), int(seeds[-1])],
        "theta": np.round(theta_all, 6).tolist(),
        "a_inverse": np.round(a_inverse_all, 6).tolist(),
    }
    with open(args.out, "w", encoding="utf-8", newline="\n") as file:
        json.dump(parameters, file, ensure_ascii=False, indent=1)

    counts = np.bincount(actions, minlength=k)
    lines = ["# Обученный директор: обучение бандита", "",
             f"Данные: {len(frame)} участков из {frame['run'].count() and frame.groupby(['session', 'run']).ngroups} "
             f"забегов исследующего директора (действие выбирается случайно и равновероятно), сиды {seeds[0]}–{seeds[-1]}; "
             f"боты: {', '.join(BOT_NAMES.get(b, b) for b in sorted(frame['bot'].unique(), key=list(BOT_NAMES).index))}. "
             f"Каждое из {k} действий встречается от {counts.min()} до {counts.max()} раз.", "",
             f"Награда за участок: −1 гибель, −0,5 без урона, +1 HP на выходе 30–70 и время не больше 2·T_ref, иначе 0. "
             f"Средняя награда в данных: {fmt(reward.mean())}; доля участков с +1: {fmt((reward == 1).mean())}, "
             f"с гибелью: {fmt((reward == -1).mean())}.", "",
             f"Модель: для каждого действия гребневая регрессия награды по контексту (λ = {fmt(args.lam, 1)}), "
             f"{len(FEATURES)} признаков: {', '.join(FEATURES)}.", "",
             f"## Проверка на отложенных сидах (каждый {VALIDATION_EVERY}-й, {int(valid.sum())} участков)", "",
             "| Показатель | Значение |", "| --- | --- |",
             f"| Ошибка предсказания награды (MSE), модель | {fmt(mse_model)} |",
             f"| То же, если предсказывать среднюю награду действия без контекста | {fmt(mse_baseline)} |",
             f"| Ожидаемая награда случайного выбора (как в данных) | {fmt(value_uniform)} |",
             f"| Ожидаемая награда лучшего постоянного действия ({ACTIONS[best_fixed]}), оценка IPS | {fmt(fixed_terms.mean())} |",
             f"| Ожидаемая награда обученной политики, оценка IPS [95% ДИ] | {fmt(value_learned)} [{fmt(value_ci[0])}; {fmt(value_ci[1])}] |",
             "",
             "IPS (inverse propensity scoring): средняя награда тех участков, где случайный выбор совпал с выбором "
             f"политики, умноженная на {k} (вероятность совпадения 1/{k}). Оценка шумная: совпадает лишь каждый "
             f"{k}-й участок. Окончательная проверка — прогоны обученного директора на тестовых сидах.", "",
             "## Что выбирает обученная политика (на отложенных сидах)", "",
             "| Бот | Самые частые действия |", "| --- | --- |"]
    for bot in sorted(frame["bot"].unique(), key=list(BOT_NAMES).index):
        mask = frame.loc[valid, "bot"].to_numpy() == bot
        top = pd.Series(chosen[mask]).value_counts(normalize=True).head(3)
        lines.append(f"| {BOT_NAMES.get(bot, bot)} | " + ", ".join(f"{ACTIONS[a]} ({fmt(share, 2)})" for a, share in top.items()) + " |")
    with open(args.report, "w", encoding="utf-8", newline="\n") as file:
        file.write("\n".join(lines) + "\n")
    print("\n".join(lines))
    print(f"\nParameters written to {args.out}")


if __name__ == "__main__":
    main()
