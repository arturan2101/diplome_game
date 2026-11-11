class_name DashSkillData
extends SkillData
## Parameters of the dash: a short burst of movement with invulnerability.

## Distance covered by the dash, in pixels.
@export var distance: float = 56.0
## Seconds the dash lasts.
@export var duration: float = 0.16
## Extra seconds of invulnerability after the dash ends.
@export var invulnerability_margin: float = 0.05
