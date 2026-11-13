class_name Shrine
extends Interactable
## A shrine in the tunnels. Used once with the interact button: it emits activated and
## the game shows the spell choice (one of three). After that it stays dark.

signal activated(shrine: Shrine)

@export var sprite: Sprite2D
## Picture of the used shrine.
@export var used_texture: Texture2D

var is_used: bool = false


func get_prompt() -> String:
	return "Pray at the shrine"


func can_interact(_player: Player) -> bool:
	return not is_used


func interact(_player: Player) -> bool:
	if is_used:
		return false
	is_used = true
	if sprite != null and used_texture != null:
		sprite.texture = used_texture
	activated.emit(self)
	return true
