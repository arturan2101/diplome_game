class_name WhirlwindData
extends SpellData
## Whirlwind: a ring of wind around the caster for a few seconds. Every tick it hurts
## the enemies inside it (not behind walls) and pushes them out. The sandstorm (a fused
## spell) is a whirlwind too that slows instead of pushing.

## Rounding guard for duration / tick_interval (2.0 / 0.25 must give 8 ticks, not 9).
const TICK_EPSILON: float = 0.001

## Damage per tick at levels 1, 2, 3.
@export var damage: PackedInt32Array = PackedInt32Array([4, 5, 6])
## Radius in pixels at levels 1, 2, 3.
@export var radius: PackedFloat32Array = PackedFloat32Array([32.0, 38.0, 44.0])
## Seconds the whirlwind lasts at levels 1, 2, 3.
@export var duration: PackedFloat32Array = PackedFloat32Array([2.0, 2.5, 3.0])
## Seconds between ticks.
@export var tick_interval: float = 0.25
## Push away from the caster, pixels per second.
@export var knockback: float = 120.0
## Seconds an enemy hit by a tick stays frozen at levels 1, 2, 3; empty = the wind
## does not freeze. Bosses do not freeze.
@export var freeze_time: PackedFloat32Array = PackedFloat32Array()
## An enemy hit by a tick walks at slow_multiplier for slow_time seconds (the
## sandstorm); 0 = no slowing.
@export var slow_multiplier: float = 1.0
@export var slow_time: float = 0.0


## True if the ticks do more than hurt (freeze or slow).
func has_status() -> bool:
	return not freeze_time.is_empty() or slow_time > 0.0


## Ticks of one cast: the first comes at once, then one every tick_interval.
func ticks_at(level: int) -> int:
	if tick_interval <= 0.0:
		return 1
	return maxi(1, ceili(float_at(duration, level) / tick_interval - TICK_EPSILON))


func power_at(level: int) -> float:
	return float(int_at(damage, level) * ticks_at(level))
