class_name ZoneData
extends SpellData
## A patch on the floor (stage 40): the lava pool, the vines and the meteor. It lands on
## the nearest visible enemy within auto_aim_radius, or cast_distance ahead, and stays
## for a while: every tick it hurts the enemies on it and may root or slow them. The
## meteor first falls (impact_delay) and hits hard where it lands, then leaves lava.
## The behaviour lives in ZoneSpell and SpellZone.

## Rounding guard for duration / tick_interval (as in WhirlwindData).
const TICK_EPSILON: float = 0.001

## Damage per tick at levels 1, 2, 3; seconds between ticks; seconds the patch lasts.
@export var tick_damage: PackedInt32Array = PackedInt32Array([6, 7, 8])
@export var tick_interval: float = 0.5
@export var duration: PackedFloat32Array = PackedFloat32Array([4.0, 4.5, 5.0])
## Radius of the patch, pixels, at levels 1, 2, 3.
@export var radius: PackedFloat32Array = PackedFloat32Array([28.0, 32.0, 36.0])
## Where it lands without an enemy to aim at, pixels ahead (closer if a wall is nearer).
@export var cast_distance: float = 64.0
## An enemy on the patch is rooted for this many seconds at every tick (the vines);
## 0 = no rooting.
@export var root_time: float = 0.0
## An enemy on the patch walks at slow_multiplier for slow_time seconds; 0 = no slowing.
@export var slow_multiplier: float = 1.0
@export var slow_time: float = 0.0
@export_group("Impact")
## The meteor: seconds of falling before the impact (its shadow grows on the floor),
## the impact's damage at levels 1, 2, 3, its radius and push. 0 damage = no impact.
@export var impact_delay: float = 0.0
@export var impact_damage: PackedInt32Array = PackedInt32Array()
@export var impact_radius: float = 0.0
@export var impact_knockback: float = 0.0
@export_group("Look")
## Radius of the patch in the art at levels 1, 2, 3 (the art is scaled to the patch).
@export var look_radius: PackedFloat32Array = PackedFloat32Array()
## The meteor: the falling rock (loops while it falls from fall_height above the spot),
## its shadow on the floor (stretched over impact_delay) and the impact (once). The
## centre of the rock and of the impact in their frames, for the pivot.
@export var fall_animation: StringName = &""
@export var shadow_animation: StringName = &""
@export var impact_animation: StringName = &""
@export var fall_height: float = 80.0
@export var fall_pivot: Vector2 = Vector2(16.0, 21.0)
@export var impact_pivot: Vector2 = Vector2(32.0, 36.0)


func ticks_at(level: int) -> int:
	if tick_interval <= 0.0 or float_at(duration, level) <= 0.0:
		return 0
	return maxi(1, ceili(float_at(duration, level) / tick_interval - TICK_EPSILON))


func power_at(level: int) -> float:
	return float(int_at(impact_damage, level) + int_at(tick_damage, level) * ticks_at(level))
