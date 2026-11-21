class_name StormCloudData
extends SpellData
## Storm cloud (stage 40, third tier: lightning + steam): a cloud follows the caster for
## a while and every strike_interval strikes the nearest visible enemy within radius
## with a bolt. Wet enemies take more.

## Rounding guard for duration / strike_interval (as in WhirlwindData).
const TICK_EPSILON: float = 0.001

## Damage of one bolt at levels 1, 2, 3.
@export var strike_damage: PackedInt32Array = PackedInt32Array([12, 14, 16])
@export var strike_interval: float = 0.5
## Seconds the cloud lasts at levels 1, 2, 3.
@export var duration: PackedFloat32Array = PackedFloat32Array([5.0, 5.5, 6.0])
## Bolts reach enemies this far from the caster, pixels.
@export var radius: float = 80.0
@export var wet_multiplier: float = 1.5
## Height of the cloud over the caster, pixels, and seconds a bolt stays drawn.
@export var cloud_height: float = 22.0
@export var bolt_time: float = 0.15
@export_group("Look")
## The cloud (loops over the caster, its centre at cloud_pivot of the frame), the bolt
## and its flash.
@export var cloud_animation: StringName = &""
@export var cloud_pivot: Vector2 = Vector2(24.0, 13.0)
@export var bolt_animation: StringName = &""
@export var hit_animation: StringName = &""


func strikes_at(level: int) -> int:
	if strike_interval <= 0.0:
		return 1
	return maxi(1, ceili(float_at(duration, level) / strike_interval - TICK_EPSILON))


## Damage one enemy takes if it is the one struck every time.
func power_at(level: int) -> float:
	return float(int_at(strike_damage, level) * strikes_at(level))
