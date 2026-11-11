class_name Coin
extends Pickup
## Adds to the run's coin counter in GameManager.

@export var value: int = 1


func _collect(_player: Player) -> bool:
	GameManager.add_coins(value)
	return true
