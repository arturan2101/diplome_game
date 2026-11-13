class_name SkillEstimator
extends RefCounted
## Estimates how well the player is doing (design.md, "Оценка навыка").
## After each section the result p (0-1) is computed and the skill S is smoothed:
##   p = w_d * (1 - D / D_norm) + w_t * min(1, T_ref / T) + w_k * K,   death gives p = 0
##   D_norm = clamp(k * B * m(d), min share * max HP, max share * max HP)
##   S = (1 - alpha) * S + alpha * p
## D: damage taken, B: danger budget of the section, m(d): how much stronger enemies are
## at depth d (their HP multiplier times their damage multiplier), T: time, T_ref:
## reference time, K: share of enemies killed. The damage norm follows the danger the
## player actually faced, so taking 20 damage in a quiet section counts against the
## player more than in a crowded one, and deeper sections do not look like lost skill.
## Used in every director mode, so the log always has the estimate.

var settings: DirectorSettings = null
## Current skill estimate S, 0-1.
var skill: float = 0.55


func _init(director_settings: DirectorSettings) -> void:
	settings = director_settings
	reset()


## Back to the starting estimate (new run).
func reset() -> void:
	skill = settings.start_skill


## Result p of one section.
func section_result(damage_taken: int, max_hp: int, time: float, reference_time: float,
		kills_ratio: float, died: bool, budget: int, depth_multiplier: float = 1.0) -> float:
	if died:
		return 0.0
	var damage_norm: float = maxf(1.0, damage_norm_for(budget, max_hp, depth_multiplier))
	var damage_part: float = clampf(1.0 - damage_taken / damage_norm, 0.0, 1.0)
	var time_part: float = 1.0 if time <= 0.0 else minf(1.0, reference_time / time)
	return settings.damage_weight * damage_part + settings.time_weight * time_part \
			+ settings.kills_weight * clampf(kills_ratio, 0.0, 1.0)


## Damage a section with this budget is "allowed" to cost before the damage part of p is 0.
func damage_norm_for(budget: int, max_hp: int, depth_multiplier: float = 1.0) -> float:
	return clampf(settings.damage_norm_per_budget * budget * depth_multiplier,
			settings.damage_norm_min_fraction * max_hp, settings.damage_norm_fraction * max_hp)


## Folds a section result into the skill estimate and returns the new estimate.
func update(result: float) -> float:
	skill = (1.0 - settings.alpha) * skill + settings.alpha * result
	return skill
