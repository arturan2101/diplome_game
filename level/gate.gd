class_name Gate
extends Area2D
## Ancient gate with a portal to the next section. It is closed (and looks closed)
## until open() is called, which the game does when every enemy of the section is dead.
## An open gate reports the player stepping into it.

## Emitted when the player enters the open gate.
signal entered(player: Player)

@export var sprite: Sprite2D
@export var closed_texture: Texture2D
@export var open_texture: Texture2D
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


func open() -> void:
	if is_open:
		return
	is_open = true
	if sprite != null:
		sprite.texture = open_texture
		var tween: Tween = create_tween()
		tween.tween_property(sprite, "scale", Vector2.ONE * open_pulse_scale, open_pulse_time * 0.5)
		tween.tween_property(sprite, "scale", Vector2.ONE, open_pulse_time * 0.5)
	# The player may already be standing in the gate when the last enemy dies.
	for body: Node2D in get_overlapping_bodies():
		_on_body_entered(body)


func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if is_open and player != null:
		entered.emit(player)
