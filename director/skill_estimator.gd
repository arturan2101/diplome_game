class_name SkillEstimator
extends RefCounted
## Estimates how well the player is doing (design.md, "Оценка навыка").
## After each section the result p (0-1) is computed and the skill S is smoothed:
##   p = w_d * (1 - D / D_max) + w_t * min(1, T_ref / T) + w_k * K,   death gives p = 0
##   S = (1 - alpha) * S + alpha * p
## D: damage taken, D_max: damage norm, T: time, T_ref: reference time, K: share of
## enemies killed. Used in every director mode, so the log always has the estimate.

var settings: DirectorSettings = null
## Current skill estimate S, 0-1.
var skill: float = 0.4


func _init(director_settings: DirectorSettings) -> void:
	settings = director_settings
	reset()


## Back to the starting estimate (new run).
func reset() -> void:
	skill = settings.start_skill


## Result p of one section.
func section_result(damage_taken: int, max_hp: int, time: float, reference_time: float,
		kills_ratio: float, died: bool) -> float:
	if died:
		return 0.0
	var damage_norm: float = maxf(1.0, max_hp * settings.damage_norm_fraction)
	var damage_part: float = clampf(1.0 - damage_taken / damage_norm, 0.0, 1.0)
	var time_part: float = 1.0 if time <= 0.0 else minf(1.0, reference_time / time)
	return settings.damage_weight * damage_part + settings.time_weight * time_part \
			+ settings.kills_weight * clampf(kills_ratio, 0.0, 1.0)


## Folds a section result into the skill estimate and returns the new estimate.
func update(result: float) -> float:
	skill = (1.0 - settings.alpha) * skill + settings.alpha * result
	return skill
