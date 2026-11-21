class_name WaveData
extends SpellData
## Water (stage 40): a wave rolls out in an arc in front of the caster, hurting and
## pushing the enemies in it and leaving them wet (lightning hurts wet enemies more).
## From ice_from_level on the water takes its second form, ice: the same arc freezes
## the enemies for a few seconds instead of pushing them (bosses do not freeze).

## Damage at levels 1, 2, 3.
@export var damage: PackedInt32Array = PackedInt32Array([10, 13, 16])
## How far the wave reaches, pixels, at levels 1, 2, 3.
@export var reach: PackedFloat32Array = PackedFloat32Array([40.0, 46.0, 52.0])
## Full width of the arc in degrees.
@export var arc_degrees: float = 100.0
## Push of the water form, pixels per second.
@export var knockback: float = 160.0
## Seconds an enemy stays wet after the water form.
@export var wet_time: float = 4.0
## The level the ice form starts at, and how long it freezes.
@export var ice_from_level: int = 3
@export var freeze_time: float = 2.0
## Colour of the ice form's placeholder drawing (color is the water's).
@export var ice_color: Color = Color(0.85, 0.95, 1.0)
## Seconds the wave stays drawn (the placeholder; the art plays its own animation).
@export var look_time: float = 0.3
@export_group("Look")
## Pixel of the art where the caster stands (left edge, middle row), and the reach the
## art was drawn for (it is scaled to the level's reach).
@export var look_pivot: Vector2 = Vector2(0.0, 16.0)
@export var look_reach: float = 48.0


func is_ice(level: int) -> bool:
	return level >= ice_from_level


func power_at(level: int) -> float:
	return float(int_at(damage, level))
