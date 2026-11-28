class_name RaysPattern
extends BossPattern
## Lashes from the boss in several directions at once (stage 50), evenly spaced: the
## safe floor is the wedges between them, wider the farther from the boss. Each lash
## stops at the first wall (it lashes over pillars).
## With several volleys, each comes when the one before strikes, turned by volley_turn
## of the gap: half a gap puts the next lashes into the wedges that were safe.
## With spread_degrees under 360 the lashes are a fan centred on the aim (the Sun
## Pharaoh's beams): the safe floor is outside the fan and between its lashes far out.

## How many lashes and how far they reach at most (pixels); half the band's width.
@export var count: int = 6
@export var length: float = 220.0
@export var half_width: float = 7.0
## One lash points at the player (else the whole fan starts at a random angle).
@export var aim_at_target: bool = false
## Angle the lashes cover: 360 = all round, less = a fan centred on the aim.
@export_range(0.0, 360.0) var spread_degrees: float = 360.0
@export var volleys: int = 1
## Share of the gap between two lashes the next volley turns by.
@export_range(0.0, 1.0) var volley_turn: float = 0.5
@export_group("Lash timing")
## Seconds the vine takes to shoot out, lies there hurting, and pulls back.
@export var extend_time: float = 0.12
@export var hold_time: float = 0.35
@export var retract_time: float = 0.2


func cast(host: Node, origin: Vector2, target: Vector2, caster: Node, source_id: StringName,
		damage_scale: float, target_mask: int, rng: RandomNumberGenerator) -> Array[BossHazard]:
	var made: Array[BossHazard] = []
	var lashes: int = maxi(count, 1)
	var gap: float = TAU / lashes
	var start: float = origin.angle_to_point(target) if aim_at_target else rng.randf() * TAU
	if is_fan():
		var spread: float = deg_to_rad(spread_degrees)
		gap = spread / (lashes - 1)
		start -= spread * 0.5
	var hit: int = scaled_damage(damage_scale)
	Sound.play_at(warn_sound, origin)
	for volley in maxi(volleys, 1):
		var turn: float = start + gap * volley_turn * volley
		for i in lashes:
			var line: LineHazard = LineHazard.make(self, host, origin, turn + gap * i, length, half_width,
					hit, caster, source_id, target_mask, warn_time * volley)
			line.extend_time = extend_time
			line.hold_time = hold_time
			line.retract_time = retract_time
			made.append(line)
	return made


## True when the lashes are a fan, not all round.
func is_fan() -> bool:
	return spread_degrees < 360.0 and count > 1


func get_duration() -> float:
	return warn_time * maxi(volleys, 1) + extend_time + hold_time
