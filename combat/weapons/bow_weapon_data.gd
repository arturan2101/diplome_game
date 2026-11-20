class_name BowWeaponData
extends WeaponData
## Parameters of a bow: hold the attack button to draw, release to shoot.
## The behaviour lives in BowWeapon, the projectile in Arrow.

## Damage of a quick tap shot and of a barely drawn bow.
@export var min_damage: int = 6
## Damage of a fully drawn bow.
@export var max_damage: int = 24
## A release before this many seconds is a quick tap shot: min_damage, no slowdown.
@export var tap_threshold: float = 0.15
## Seconds of drawing after tap_threshold to reach max_damage.
@export var draw_time: float = 0.8
## Wielder speed multiplier at full draw; it goes down smoothly while drawing.
@export_range(0.0, 1.0) var draw_move_speed_multiplier: float = 0.5
## Minimum time between two shots, in seconds. Holding during it does not draw the bow.
@export var cooldown: float = 0.4
## Arrow speed in pixels per second.
@export var arrow_speed: float = 320.0
## Distance in pixels after which an arrow disappears.
@export var arrow_range: float = 240.0
## Scene of the projectile (root node is an Arrow).
@export var arrow_scene: PackedScene
## Arrows per shot, spread evenly over spread_degrees (the elite archer's triple shot).
@export var arrow_count: int = 1
@export var spread_degrees: float = 0.0


func get_card_stats() -> Array[Dictionary]:
	var multiplier: float = get_damage_multiplier()
	var low: int = roundi(min_damage * multiplier)
	var high: int = roundi(max_damage * multiplier)
	var draw: float = draw_time / get_attack_speed_multiplier()
	var stats: Array[Dictionary] = [
		card_line("Damage", high * arrow_count, "%d-%d" % [low, high] + ("" if arrow_count <= 1 else " x%d" % arrow_count)),
		card_line("Draw", -draw, "%s s" % _short(draw)),
		card_line("Range", arrow_range, str(roundi(arrow_range))),
	]
	stats.append_array(super())
	return stats
