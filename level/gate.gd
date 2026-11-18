class_name Gate
extends Area2D
## Ancient gate with a portal to the next section. It is closed (and looks closed)
## until open() is called, which the game does when every enemy of the section is dead.
## An open gate reports the player stepping into it.

## Emitted when the player enters the open gate.
signal entered(player: Player)

@export var sprite: Sprite2D
@export var closed_texture: Texture2D
## The open portal; with open_frames > 1 a strip that loops (a StripSprite plays it).
@export var open_texture: Texture2D
@export var open_frames: int = 1
## Burst of light when the portal opens (a strip played once over the gate), or null.
@export var open_burst: Texture2D
@export var open_burst_frames: int = 1
@export var open_burst_fps: float = 12.0
## Physics layers of the bodies that can use the gate (player).
@export_flags_2d_physics var traveller_mask: int = 2
## Short "pop" when the gate opens: the sprite grows to this scale and back.
@export var open_pulse_scale: float = 1.6
@export var open_pulse_time: float = 0.25

var is_open: bool = false


func _ready() -> void:
	collision_layer = 0
	collision_mask = traveller_mask
	body_entered.connect(_on_body_entered)
	if sprite != null:
		sprite.texture = closed_texture
		sprite.hframes = 1


func open() -> void:
	if is_open:
		return
	is_open = true
	if sprite != null:
		sprite.texture = open_texture
		sprite.hframes = maxi(open_frames, 1)
		var strip: StripSprite = sprite as StripSprite
		if strip != null and open_frames > 1:
			strip.play_range(0, -1, true)
		_play_burst()
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2.ONE * open_pulse_scale, open_pulse_time * 0.5)
		tween.tween_property(sprite, "scale", Vector2.ONE, open_pulse_time * 0.5)
	# The player may already be standing in the gate when the last enemy dies.
	for body: Node2D in get_overlapping_bodies():
		_on_body_entered(body)


## The burst of light over the gate as it opens (visual only, frees itself).
func _play_burst() -> void:
	if open_burst == null:
		return
	var burst: StripSprite = StripSprite.new()
	burst.texture = open_burst
	burst.hframes = maxi(open_burst_frames, 1)
	burst.fps = open_burst_fps
	burst.looping = false
	burst.free_when_done = true
	burst.offset = sprite.offset if sprite != null else Vector2.ZERO
	add_child(burst)


func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if is_open and player != null:
		entered.emit(player)
