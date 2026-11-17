class_name SpellData
extends Resource
## Data shared by every spell. A concrete spell is a .tres file of a subclass
## (FireballData, IceWallData, WhirlwindData) plus a small effect script; a fused spell
## (stage 26) is one more .tres of the same subclasses with its own numbers and look.
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
@export_group("Look by level")
## Art of the effect, one look per level (index 0 = level 1): animations in frames
## (the flying fireball, the ring of wind) or one picture per level (an ice block).
## Empty = the effect draws its placeholder.
@export var frames: SpriteFrames
@export var level_animations: Array[StringName] = []
@export var level_textures: Array[Texture2D] = []


func cooldown_at(level: int) -> float:
	return float_at(cooldown, level)


## Damage one enemy takes from one cast at this level if it stays in the effect. The
## measure of the balance rule of fused spells (docs/design.md); 0 for spells that do
## not hurt (the ice wall).
func power_at(_level: int) -> float:
	return 0.0


## The animation of this level in frames, or &"" when the spell has none.
func animation_at(level: int) -> StringName:
	if frames == null or level_animations.is_empty():
		return &""
	var animation: StringName = level_animations[clampi(level, 1, level_animations.size()) - 1]
	return animation if frames.has_animation(animation) else &""


## The picture of this level, or null.
func texture_at(level: int) -> Texture2D:
	if level_textures.is_empty():
		return null
	return level_textures[clampi(level, 1, level_textures.size()) - 1]


## Size of one frame of an animation, in pixels (zero if it has no frames).
static func frame_size(sprite_frames: SpriteFrames, animation: StringName) -> Vector2:
	if sprite_frames == null or not sprite_frames.has_animation(animation) or sprite_frames.get_frame_count(animation) == 0:
		return Vector2.ZERO
	return sprite_frames.get_frame_texture(animation, 0).get_size()


## The value for this level (1-based); levels past the end use the last value.
static func float_at(values: PackedFloat32Array, level: int) -> float:
	if values.is_empty():
		return 0.0
	return values[clampi(level, 1, values.size()) - 1]


static func int_at(values: PackedInt32Array, level: int) -> int:
	if values.is_empty():
		return 0
	return values[clampi(level, 1, values.size()) - 1]
