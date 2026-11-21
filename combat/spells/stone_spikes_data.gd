class_name StoneSpikesData
extends SpellData
## Earth (stage 40): a line of stone spikes breaks out of the floor from the caster in
## the aim direction, up to the first wall. Every enemy on the line is hurt once and
## stunned for a moment (bosses and the golem are not stunned).

## Damage at levels 1, 2, 3.
@export var damage: PackedInt32Array = PackedInt32Array([16, 22, 28])
## Length of the line, pixels, at levels 1, 2, 3.
@export var length: PackedFloat32Array = PackedFloat32Array([56.0, 64.0, 72.0])
## Seconds a hit enemy is stunned at levels 1, 2, 3.
@export var stun_time: PackedFloat32Array = PackedFloat32Array([0.6, 0.8, 1.0])
## A spike every spacing pixels; each one reaches spike_radius around it.
@export var spacing: float = 12.0
@export var spike_radius: float = 10.0
## Seconds between two spikes coming up (only the look; the damage is at once).
@export var spike_delay: float = 0.04
## Seconds one spike stays drawn (the placeholder; the art plays its own animation).
@export var spike_time: float = 0.35
@export_group("Look")
## Shift of a spike's art so its floor row (22 of 24) sits on the spike point.
@export var spike_offset: Vector2 = Vector2(0.0, -10.0)


func power_at(level: int) -> float:
	return float(int_at(damage, level))
