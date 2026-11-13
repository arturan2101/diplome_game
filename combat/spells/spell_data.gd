class_name SpellData
extends Resource
## Data shared by every spell. A concrete spell is a .tres file of a subclass
## (FireballData, IceWallData, WhirlwindData) plus a small effect script.
## Numbers that grow with the spell level are arrays: index 0 is level 1.

const MAX_LEVEL: int = 3

## Stable id used in logs and telemetry, e.g. &"fireball".
@export var id: StringName = &""
@export var display_name: String = ""
## One line for the choice screen.
@export var description: String = ""
## Picture for the HUD, the choice screen and the scroll on the floor.
@export var icon: Texture2D
## Colour of the effect's placeholder drawing.
@export var color: Color = Color.WHITE
## Seconds between casts at levels 1, 2, 3.
@export var cooldown: PackedFloat32Array = PackedFloat32Array([6.0, 5.0, 4.0])
## The spell aims at the nearest visible enemy within this distance, in pixels;
## 0 = where the player faces.
@export var auto_aim_radius: float = 0.0
## Scene with the spell behaviour (root node is a Spell), created when it is learned.
@export var spell_scene: PackedScene


func cooldown_at(level: int) -> float:
	return float_at(cooldown, level)


## The value for this level (1-based); levels past the end use the last value.
static func float_at(values: PackedFloat32Array, level: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(level, 1, values.size()) - 1]


static func int_at(values: PackedInt32Array, level: int) -> int:
	if values.is_empty():
		return 0
	return values[clampi(level, 1, values.size()) - 1]
