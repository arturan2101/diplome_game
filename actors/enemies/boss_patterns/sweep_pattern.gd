class_name SweepPattern
extends BossPattern
## Arms sweeping round the boss (stage 50, the "turntable"): evenly spaced, they start
## with the player in the middle of a gap and turn one way (random) for spin_time. The
## player walks round with the gap; nearer the boss the walk is shorter, but the gap
## narrower.

@export var arms: int = 2
## Degrees per second.
@export var turn_speed_degrees: float = 40.0
@export var spin_time: float = 4.0
@export var length: float = 220.0
@export var half_width: float = 6.0


func cast(host: Node, origin: Vector2, target: Vector2, caster: Node, source_id: StringName,
		damage_scale: float, target_mask: int, rng: RandomNumberGenerator) -> Array[BossHazard]:
	var sweep: SweepHazard = SweepHazard.new()
	sweep.setup(self, scaled_damage(damage_scale), caster, source_id, target_mask)
	sweep.arms = maxi(arms, 1)
	# The player starts in the middle of a gap.
	sweep.start_angle = origin.angle_to_point(target) + PI / sweep.arms
	sweep.turn_speed = deg_to_rad(turn_speed_degrees) * (1.0 if rng.randf() < 0.5 else -1.0)
	sweep.spin_time = spin_time
	sweep.max_length = length
	sweep.half_width = half_width
	Sound.play_at(warn_sound, origin)
	BossHazard.place(sweep, host, origin)
	return [sweep]


func get_duration() -> float:
	return warn_time + spin_time
