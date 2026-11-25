class_name SporeTrapData
extends Resource
## Numbers of the fungal puffball (stage 48, SporePuff): a floor trap of the fungal
## catacombs. After a section is built the game puts a few puffballs on free floor of
## its rooms (from GameManager.make_hazard_rng, so the section itself is the same as
## without them). A puffball breathes; when the player comes close it bursts and leaves
## a cloud of spores that hurts the player while inside; then it grows back.

## Damage source in the log.
@export var id: StringName = &"spore_trap"
## Puffballs per section (from x to y), never in an arena section.
@export var per_section: Vector2i = Vector2i(2, 4)
## Two puffballs are at least this many cells apart.
@export var min_spacing: int = 4
## No puffball this close (cells) to the entrance, the exit portal, an item or an enemy.
@export var clearance: int = 2
## The player this close (pixels) makes it burst.
@export var trigger_radius: float = 18.0
## Seconds after the burst until it can burst again.
@export var regrow_time: float = 7.0
## The cloud (a SpellZone with tick damage, aimed at target_mask).
@export var cloud: ZoneData
@export_flags_2d_physics var target_mask: int = 8
@export_flags_2d_physics var wall_mask: int = 1
@export_group("Look")
@export var frames: SpriteFrames
@export var breathe_animation: StringName = &"spore_puff_breathe"
## The burst, played once; the cloud comes out on release_frame of it.
@export var burst_animation: StringName = &"spore_puff_burst"
@export var release_frame: int = 1
@export var burst_sound: StringName = &"spore_burst"
