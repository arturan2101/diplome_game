class_name SkillData
extends Resource
## Data shared by every basic skill. A concrete skill is a .tres file of a subclass.

## Stable id used in logs and telemetry, e.g. &"dash".
@export var id: StringName = &""
@export var display_name: String = ""
## Small picture for the HUD and the menu.
@export var icon: Texture2D
## Seconds after the skill ends before it can be used again.
@export var cooldown: float = 1.0
## Scene with the skill behaviour (root node is a Skill), created when the run starts.
@export var skill_scene: PackedScene
## Sound ids (stage 46): assets/audio/sfx/<id>.ogg or its variants <id>_1, _2...; &"" = silent.
## The skill is used; a hit it turns aside (the shield, the parry).
@export var use_sound: StringName = &""
@export var block_sound: StringName = &""
