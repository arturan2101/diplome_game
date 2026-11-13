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
The reward model is linear per action, theta_a . x, as in LinUCB. Two ways to fit it:
  independent  one ridge regression per action (LinUCB's own estimate):
               A_a = lambda * I + sum(x x^T),  b_a = sum(r x),  theta_a = A_a^-1 b_a
  factored     one ridge regression where an action's weights are the sum of the
               weights of its section type, its budget level and its dominant enemy:
               theta_a = w_type + w_level + w_enemy. 72 numbers instead of 216, so
               actions that share a part share their data.
The game picks argmax_a theta_a . x; alpha = 0, so it does not explore on players.

Seeds: every VALIDATION_EVERY-th exploration seed is kept for validation. The model and
lambda are chosen by the value of the greedy policy on validation, estimated doubly
robustly (DR: the reward model's prediction for the chosen action, corrected by the
logged reward wherever the logged action matches; unbiased because the exploring
policy's probabilities 1/K are known). Inverse propensity (IPS) estimates are reported
too. The chosen model is then refit on all exploration seeds. The test seeds of the
comparison (TEST_SEEDS) must not be in the training data; the script refuses them.

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
LAMBDAS = [0.3, 1.0, 3.0, 10.0, 30.0]
# Reward model used inside the DR estimate (any model keeps DR unbiased; a better one
# makes it less noisy).
DR_MODEL = ("factored", 3.0)
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


def factored_design(x, actions):
    """Per sample: x placed in the slots of the action's type, level and enemy."""
    n, d = x.shape
    parts = [actions // (len(LEVELS) * len(ENEMIES)), (actions // len(ENEMIES)) % len(LEVELS), actions % len(ENEMIES)]
    design = np.zeros((n, 3 * 3 * d))
    for group, values in enumerate(parts):
        for i in range(n):
            start = (group * 3 + values[i]) * d
            design[i, start:start + d] = x[i]
    return design


def fit_factored(x, actions, reward, k, lam):
    design = factored_design(x, actions)
    w = np.linalg.solve(lam * np.eye(design.shape[1]) + design.T @ design, design.T @ reward)
    d = x.shape[1]
    theta = np.zeros((k, d))
    for a in range(k):
        t, lv, e = a // (len(LEVELS) * len(ENEMIES)), (a // len(ENEMIES)) % len(LEVELS), a % len(ENEMIES)
        theta[a] = w[(0 * 3 + t) * d:(0 * 3 + t + 1) * d] + w[(1 * 3 + lv) * d:(1 * 3 + lv + 1) * d] \
            + w[(2 * 3 + e) * d:(2 * 3 + e + 1) * d]
    return theta


def fit_model(kind, x, actions, reward, k, lam):
    if kind == "factored":
        return fit_factored(x, actions, reward, k, lam)
    return fit(x, actions, reward, k, lam)[0]


def dr(chosen, x, actions, reward, model_theta, k):
    """Per-sample doubly robust terms; their mean estimates the policy's expected reward."""
    predicted_chosen = np.sum(x * model_theta[chosen], axis=1)
    predicted_logged = np.sum(x * model_theta[actions], axis=1)
    return predicted_chosen + (chosen == actions) * k * (reward - predicted_logged)


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

    # Validation: every candidate is fitted on the training seeds only.
    xv, av, rv = x[valid], actions[valid], reward[valid]
    dr_model = fit_model(DR_MODEL[0], x[train], actions[train], reward[train], k, DR_MODEL[1])
    action_means = np.array([reward[train][actions[train] == a].mean() for a in range(k)])
    mse_baseline = np.mean((action_means[av] - rv) ** 2)
    candidates = []
    for kind in ("independent", "factored"):
        for lam in LAMBDAS:
            theta = fit_model(kind, x[train], actions[train], reward[train], k, lam)
            chosen = greedy(theta, xv)
            candidates.append({
                "kind": kind, "lam": lam, "chosen": chosen,
                "mse": np.mean((np.sum(xv * theta[av], axis=1) - rv) ** 2),
                "dr": dr(chosen, xv, av, rv, dr_model, k),
                "ips": ips(chosen, av, rv, k),
            })
    best = max(candidates, key=lambda c: c["dr"].mean())
    chosen = best["chosen"]
    value_uniform = rv.mean()
    best_fixed = int(np.argmax(action_means))
    fixed_chosen = np.full(len(rv), best_fixed)
    fixed_dr = dr(fixed_chosen, xv, av, rv, dr_model, k)
    fixed_ips = ips(fixed_chosen, av, rv, k)
    learned_ci = bootstrap_mean_ci(best["dr"], rng)

    # Final model: the chosen kind and lambda on all exploration seeds.
    theta_all = fit_model(best["kind"], x, actions, reward, k, best["lam"])
    _, a_inverse_all = fit(x, actions, reward, k, best["lam"])
    parameters = {
        "version": 1,
        "trained": date.today().isoformat(),
        "features": FEATURES,
        "actions": ACTIONS,
        "alpha": 0.0,
        "model": best["kind"],
        "lambda": best["lam"],
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
             f"Признаки контекста ({len(FEATURES)}): {', '.join(FEATURES)}. Модель награды линейная по контексту "
             "для каждого действия; две схемы: независимая гребневая регрессия на каждое действие (как в LinUCB) "
             "и факторизованная (веса действия = веса его типа + уровня бюджета + врага). Схема и λ выбраны по "
             "оценке ценности политики на отложенных сидах.", "",
             f"## Проверка на отложенных сидах (каждый {VALIDATION_EVERY}-й, {int(valid.sum())} участков)", "",
             "| Модель | λ | Ошибка предсказания (MSE) | Ценность политики, DR | Ценность политики, IPS |",
             "| --- | --- | --- | --- | --- |"]
    for c in candidates:
        mark = " **← выбрана**" if c is best else ""
        lines.append(f"| {c['kind']}{mark} | {fmt(c['lam'], 1)} | {fmt(c['mse'])} | {fmt(c['dr'].mean())} | {fmt(c['ips'].mean())} |")
    lines += ["",
             "| Сравнение | Ожидаемая награда за участок |", "| --- | --- |",
             f"| Случайный выбор (как в данных) | {fmt(value_uniform)} |",
             f"| Лучшее постоянное действие ({ACTIONS[best_fixed]}), DR / IPS | {fmt(fixed_dr.mean())} / {fmt(fixed_ips.mean())} |",
             f"| Обученная политика, DR [95% ДИ] | {fmt(best['dr'].mean())} [{fmt(learned_ci[0])}; {fmt(learned_ci[1])}] |",
             f"| Ошибка предсказания, если брать среднюю награду действия без контекста (MSE) | {fmt(mse_baseline)} |",
             "",
             "DR (doubly robust): предсказание модели награды для выбранного политикой действия плюс поправка "
             "по настоящей награде там, где случайный выбор совпал с выбором политики. Вероятность каждого действия "
             f"при сборе данных известна точно (1/{k}), поэтому оценка несмещённая; IPS — только поправочная часть, "
             f"она тоже несмещённая, но шумнее (совпадает лишь каждый {k}-й участок). Окончательная проверка — "
             "прогоны обученного директора на тестовых сидах.", "",
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
