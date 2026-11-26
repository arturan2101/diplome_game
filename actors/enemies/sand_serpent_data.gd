class_name SandSerpentData
extends EnemyData
## Numbers of the sand serpent (stage 49, SandSerpent): it lies hidden under the sand,
## creeps up on the player, bursts out with a bite, stands for a moment and sinks again.

@export_group("Under the sand")
## Speed while hidden (pixels per second); it stops creeping at hold_distance.
@export var hidden_speed: float = 35.0
@export var hold_distance: float = 18.0
## It bursts out when the player is this close (pixels) and in sight.
@export var emerge_range: float = 30.0
## Seconds after sinking before it may burst out again.
@export var resurface_delay: float = 1.5
## Seconds of sinking back (the sink strip lasts this long).
@export var sink_time: float = 0.33
## The ring of sand drawn under it while hidden (a looping strip of square frames).
@export var ripple: Texture2D
@export var ripple_frames: int = 4
@export var ripple_fps: float = 8.0
