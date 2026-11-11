class_name Pickup
extends Area2D
## Base class of things the player takes by walking over them (health pack, coin, chest).
## Subclasses implement _collect(). The pickup watches the player body layer only.

## Emitted when the player took the pickup.
signal collected(pickup: Pickup, collector: Player)

## Physics layers of the bodies that can take the pickup (player).
@export_flags_2d_physics var collector_mask: int = 2


func _ready() -> void:
	collision_layer = 0
	collision_mask = collector_mask
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	var player: Player = body as Player
	if player == null or not _collect(player):
		return
	collected.emit(self, player)
	_after_collect()


## Subclasses: give the player what the pickup holds. Return false to stay on the
## ground (for example a health pack at full health).
func _collect(_player: Player) -> bool:
	return false


## What happens to the pickup once taken. By default it disappears.
func _after_collect() -> void:
	queue_free()
