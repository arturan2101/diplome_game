class_name Interactable
extends Area2D
## Something the player uses with the interact button (E or the Take touch button)
## while standing next to it: a weapon on the floor, a spell scroll, a shrine.
## The player looks for the nearest one in GROUP; the HUD shows its hint.
## Subclasses override get_prompt(), interact() and, if needed, can_interact().

## Group of everything the player can interact with.
const GROUP: StringName = &"interactables"


func _ready() -> void:
	add_to_group(GROUP)
	# Found by distance, not by physics: no collision layers needed.
	collision_layer = 0
	collision_mask = 0


## Hint shown while the player stands next to it, as BBCode.
func get_prompt() -> String:
	return ""


## False while it cannot be used (a shrine already used); the player then ignores it.
func can_interact(_player: Player) -> bool:
	return true


## Uses it. Returns true if something happened.
func interact(_player: Player) -> bool:
	return false
