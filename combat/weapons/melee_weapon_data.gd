class_name MeleeWeaponData
extends WeaponData
## Parameters of a melee weapon such as the sword: a combo of attack steps.
## The behaviour lives in MeleeWeapon.

## Steps of the combo in order. A single step makes a weapon without a combo.
@export var combo: Array[MeleeAttackStep] = []
## After a step is over, a press within this many seconds continues the combo;
## a later press starts again from the first step.
@export var combo_window: float = 0.4
## Extra pause after the last step of the combo, in seconds.
@export var combo_end_cooldown: float = 0.3
## A press while the weapon is busy is remembered (only one) if it comes within
## this many seconds before the next step can start. Earlier presses are ignored.
@export var buffer_window: float = 0.2


func get_card_stats() -> Array[Dictionary]:
	var stats: Array[Dictionary] = []
	if combo.is_empty():
		return stats
	var total_damage: float = 0.0
	var total_time: float = combo_end_cooldown
	var reach: float = 0.0
	for step: MeleeAttackStep in combo:
		total_damage += step.damage
		total_time += step.duration + step.recovery
		reach = maxf(reach, step.reach)
	var damage: float = total_damage / combo.size() * get_damage_multiplier()
	var speed: float = combo.size() * get_attack_speed_multiplier() / maxf(total_time, 0.01)
	stats.append(card_line("Damage", damage, _short(damage)))
	stats.append(card_line("Hits/s", speed, _short(speed)))
	stats.append(card_line("Reach", reach, str(roundi(reach))))
	stats.append_array(super())
	return stats
