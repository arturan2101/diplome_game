class_name QuicksandData
extends Resource
## Numbers of the quicksand of the sand temple (stage 49, Quicksand): after a section
## is built the game lays a few patches of it on free floor of its rooms (from
## GameManager.make_hazard_rng, so the section itself is the same as without them).
## Walkable; whoever walks on it (the player, enemies that walk) is slowed while on it.

## Patches per section (from x to y), never in an arena section.
@export var per_section: Vector2i = Vector2i(1, 3)
## Width and height of a patch in cells (each from x to y).
@export var patch_size: Vector2i = Vector2i(2, 3)
## Two patches are at least this many cells apart.
@export var min_spacing: int = 3
## No patch cell this close (cells) to the entrance or the exit portal, nor this close
## to an item. Enemies may stand on it (they are only slowed).
@export var clearance: int = 2
@export var item_clearance: int = 1
## Speed while on it, and how long the slow lasts after stepping off (seconds).
@export_range(0.0, 1.0) var slow_multiplier: float = 0.5
@export var slow_linger: float = 0.15
@export_group("Look and sound")
## A strip of square frames, one cell each, looping.
@export var strip: Texture2D
@export var strip_frames: int = 4
@export var strip_fps: float = 6.0
## Played when the player steps onto a patch, at most once per sound_cooldown seconds.
@export var step_sound: StringName = &"quicksand_loop"
@export var sound_cooldown: float = 2.5
