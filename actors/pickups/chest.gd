class_name Chest
extends Pickup
## Opens when the player touches it. Gives the first weapon from its list that the
## player does not carry (the second weapon of the run); if the player already has
## them all or no free slot, it gives coins instead. Stays in place, opened.

## Weapons the chest can give, in order of preference.
@export var weapons: Array[WeaponData] = []
## Coins given when no weapon can be given.
@export var coins_instead: int = 10
@export var sprite: Sprite2D
@export var open_texture: Texture2D

var is_open: bool = false
## What the chest gave: a weapon id, or &"coins". Empty until opened.
var given: StringName = &""


func _collect(player: Player) -> bool:
	if is_open:
		return false
	is_open = true
	given = &"coins"
	for weapon_data: WeaponData in weapons:
		if not player.has_weapon(weapon_data.id) and player.add_weapon(weapon_data):
			given = weapon_data.id
			break
	if given == &"coins":
		GameManager.add_coins(coins_instead)
	if sprite != null and open_texture != null:
		sprite.texture = open_texture
	return true


func _after_collect() -> void:
	pass
