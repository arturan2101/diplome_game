class_name WeaponPickup
extends Area2D
## A weapon lying on the floor. It is not taken by walking over it: the player stands
## next to it and presses the interact button (E or the "Take" touch button).
## If both slots are full, the taken weapon replaces the one in hand and the old one
## is left lying here instead, so it can be taken back.

## Group of everything the player can interact with; the player looks for the nearest.
const GROUP: StringName = &"interactables"

@export var weapon_data: WeaponData
@export var sprite: Sprite2D
## Gentle bobbing, so a weapon on the floor is easy to notice.
@export var bob_height: float = 2.0
@export var bob_speed: float = 3.0

var _time: float = 0.0


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 0
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	if sprite != null:
		sprite.position.y = sin(_time * bob_speed) * bob_height


## Text of the hint shown while the player stands next to it.
func get_prompt() -> String:
	return "Take %s" % weapon_data.display_name if weapon_data != null else ""


## Gives the weapon to the player. Returns true if something was taken.
func interact(player: Player) -> bool:
	if weapon_data == null:
		return false
	var dropped: WeaponData = player.pick_up_weapon(weapon_data)
	if dropped == null:
		queue_free()
	else:
		# Swap in place: the old weapon now lies where the new one was.
		weapon_data = dropped
		_refresh()
	return true


func _refresh() -> void:
	if sprite != null and weapon_data != null:
		sprite.texture = weapon_data.icon
