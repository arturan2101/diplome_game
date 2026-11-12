class_name Chest
extends Pickup
## Opens when the player touches it and stays open. The game then puts the loot next
## to it: a weapon lying on the floor (taken with the interact button) and a few coins.
## What a chest holds is decided by the game when the section is built.

## Emitted once, when the chest opens.
signal opened(chest: Chest)

@export var sprite: Sprite2D
@export var open_texture: Texture2D

## The weapon inside, set by the game when the chest is spawned.
var loot_weapon: WeaponData = null
## How many coins fall out, set by the game.
var loot_coins: int = 0
var is_open: bool = false


func _collect(_player: Player) -> bool:
	if is_open:
		return false
	is_open = true
	if sprite != null and open_texture != null:
		sprite.texture = open_texture
	opened.emit(self)
	return true


func _after_collect() -> void:
	pass
