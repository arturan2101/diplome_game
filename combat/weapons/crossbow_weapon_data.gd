class_name CrossbowWeaponData
extends WeaponData
## Parameters of a crossbow (stage 39): a press shoots a heavy bolt at once, then it
## reloads; holding the button shoots again as soon as it is loaded. No draw, no slowdown.
## The bolt flies through pierce targets and hits the next one too.
## The behaviour lives in CrossbowWeapon, the projectile is an Arrow.

## Damage of every bolt.
@export var damage: int = 22
## Seconds from a shot until the crossbow is loaded again.
@export var reload_time: float = 1.1
## Bolt speed in pixels per second, and the distance after which it disappears.
@export var bolt_speed: float = 420.0
@export var bolt_range: float = 260.0
## How many targets a bolt flies through (it hits each of them).
@export var pierce: int = 1
## Scene of the projectile (root node is an Arrow).
@export var bolt_scene: PackedScene


func get_card_stats() -> Array[Dictionary]:
	var reload: float = reload_time / get_attack_speed_multiplier()
	var hit: int = roundi(damage * get_damage_multiplier())
	var stats: Array[Dictionary] = [
		card_line("Damage", hit, str(hit)),
		card_line("Reload", -reload, "%s s" % _short(reload)),
		card_line("Range", bolt_range, str(roundi(bolt_range))),
	]
	if pierce > 0:
		stats.append(card_line("Pierce", pierce, "+%d" % pierce))
	stats.append_array(super())
	return stats
