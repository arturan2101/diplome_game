class_name ScarabData
extends EnemyData
## Numbers of the scarab of the sand temple (stage 49, Scarab): a small beetle of a pack
## that burrows when the player is far, crawls under the sand to it and comes up beside
## it to bite.

@export_group("Burrowing")
## It burrows when the player is at least this far (pixels) and it may burrow again.
@export var burrow_distance: float = 64.0
## Seconds between coming up and burrowing again.
@export var burrow_cooldown: float = 3.0
## Seconds of going down and of coming up (the burrow and emerge strips last this long).
@export var burrow_time: float = 0.33
@export var emerge_time: float = 0.33
## Speed under the sand (pixels per second).
@export var underground_speed: float = 75.0
## It comes up when this close to the player (pixels), or after max_underground_time.
@export var emerge_distance: float = 16.0
@export var max_underground_time: float = 4.0
## Played as it goes down and as it comes up.
@export var burrow_sound: StringName = &"scarab_burrow"
