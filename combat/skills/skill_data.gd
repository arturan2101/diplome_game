class_name SkillData
extends Resource
## Data shared by every basic skill. A concrete skill is a .tres file of a subclass.

## Stable id used in logs and telemetry, e.g. &"dash".
@export var id: StringName = &""
@export var display_name: String = ""
## Seconds after the skill ends before it can be used again.
@export var cooldown: float = 1.0
## Scene with the skill behaviour (root node is a Skill), created when the run starts.
@export var skill_scene: PackedScene
