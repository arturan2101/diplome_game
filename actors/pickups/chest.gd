class_name Chest
extends Pickup
## Opens when the player touches it and stays open. The game then puts the loot next
## to it: a weapon lying on the floor (taken with the interact button), a few coins
## and sometimes a spell scroll.
## What a chest holds is decided by the game when the section is built.

## Emitted once, when the chest opens.
signal opened(chest: Chest)
## Emitted when the player touches it while it is locked (for a hint).
signal locked_touch(chest: Chest)

@export var sprite: Sprite2D
@export var open_texture: Texture2D

## The weapon inside, set by the game when the chest is spawned.
var loot_weapon: WeaponData = null
## How many coins fall out, set by the game.
var loot_coins: int = 0
## The spell scroll inside, or null (most chests have none).
var loot_spell: SpellData = null
var is_open: bool = false
## Full game: returns true while it must stay shut (enemies chasing the player nearby);
## the chest then opens as soon as the player stands on it and it is free.
var lock_check: Callable = Callable()

var _waiting: Player = null


func _collect(player: Player) -> bool:
	if is_open:
		return false
	if lock_check.is_valid() and lock_check.call(global_position):
		_waiting = player
		locked_touch.emit(self)
		return false
	_waiting = null
	is_open = true
	var strip: StripSprite = sprite as StripSprite
	if strip != null and strip.hframes > 1:
		# The lid opens: the rest of the strip, once.
		strip.play_range(1, -1, false)
	elif sprite != null and open_texture != null:
		sprite.texture = open_texture
	opened.emit(self)
	return true


func _after_collect() -> void:
	pass


## A locked chest opens once it is free while the player still stands on it.
func _physics_process(_delta: float) -> void:
	if _waiting == null or is_open:
		return
	if not is_instance_valid(_waiting) or not overlaps_body(_waiting):
		_waiting = null
		return
	if not lock_check.call(global_position):
		_on_body_entered(_waiting)

