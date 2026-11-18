class_name GhostData
extends EnemyData
## Numbers of the ghost (stage 31). The EnemyData part gives its speed, HP, danger cost,
## reach and windup; its touch is the weapon (a short melee hit).

@export_group("Ghost")
## Alpha of the ghost while it drifts (it shows fully only to strike).
@export_range(0.0, 1.0) var drift_alpha: float = 0.45
## Seconds the ghost takes to fade in at the start of its windup, and out after it.
@export var fade_time: float = 0.25
