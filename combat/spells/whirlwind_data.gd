class_name WhirlwindData
extends SpellData
## Whirlwind: a ring of wind around the caster for a few seconds. Every tick it hurts
## the enemies inside it (not behind walls) and pushes them out.

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
