class_name VineLurkerData
extends EnemyData
## Numbers of the vine lurker (stage 48, VineLurker): a plant rooted to its cell that
## waits closed in the floor and comes out when the player is near or hits it.

@export_group("Lurking")
## The player this close (pixels) makes it come out.
@export var emerge_range: float = 56.0
## Seconds it takes to come out (the emerge animation is stretched to it).
@export var emerge_time: float = 0.35
@export var emerge_sound: StringName = &"vines_grow"
## The lash drawn from the bud towards the player at the blow: a strip pointing right
## that starts at its left edge, frames and speed; lash_height lifts it to the bud.
@export var lash_effect: Texture2D
@export var lash_frames: int = 4
@export var lash_fps: float = 16.0
@export var lash_height: float = 6.0
