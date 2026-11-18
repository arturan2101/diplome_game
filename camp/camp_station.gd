class_name CampStation
extends Interactable
## A place in the camp the player uses with the interact button: the entrance to the
## ruins, the skill altar, the spell shelf. It only reports the use; the camp acts.

signal used(station: CampStation)

## Hint shown next to it.
@export var prompt: String = ""


func get_prompt() -> String:
	return prompt


func interact(_player: Player) -> bool:
	used.emit(self)
	return true
