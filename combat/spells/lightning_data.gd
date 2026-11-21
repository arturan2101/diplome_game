class_name LightningData
extends SpellData
## Lightning (stage 40, water + air): strikes the nearest visible enemy within
## auto_aim_radius and jumps on to the nearest enemies it has not struck yet, each
## within jump_range of the last. Wet enemies take wet_multiplier times the damage.
## The volcanic lightning (third tier) also leaves a small lava pool under every enemy
## it strikes (zone_on_hit).

## Damage to every struck enemy at levels 1, 2, 3.
@export var damage: PackedInt32Array = PackedInt32Array([72, 84, 96])
## How many enemies one cast strikes at most, at levels 1, 2, 3.
@export var chain_count: PackedInt32Array = PackedInt32Array([3, 3, 4])
## Longest jump from one struck enemy to the next, pixels.
@export var jump_range: float = 56.0
## Damage multiplier against wet enemies.
@export var wet_multiplier: float = 1.5
## A patch left under every struck enemy (the volcanic lightning's lava), or null.
@export var zone_on_hit: ZoneData
## Without an enemy in reach the bolt hits the floor this far ahead.
@export var miss_distance: float = 64.0
## Seconds a bolt stays drawn.
@export var bolt_time: float = 0.2
@export_group("Look")
## Animations of the bolt (stretched between two points) and of the flash where it lands.
@export var bolt_animation: StringName = &""
@export var hit_animation: StringName = &""


func power_at(level: int) -> float:
	return float(int_at(damage, level))
