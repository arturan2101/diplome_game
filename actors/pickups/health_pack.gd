class_name HealthPack
extends Pickup
## Restores health. Stays on the ground while the player is at full health.

@export var heal_amount: int = 30


func _collect(player: Player) -> bool:
	return player.health != null and player.health.heal(heal_amount) > 0
