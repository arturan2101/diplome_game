class_name Coin
extends Pickup
## Adds to the run's coin counter in GameManager.

@export var value: int = 1
## Speed at which the coin flies to a player with the coin magnet (permanent skill).
@export var magnet_speed: float = 160.0


func _physics_process(delta: float) -> void:
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	if player == null or player.coin_magnet_radius <= 0.0:
		return
	var distance: float = global_position.distance_to(player.global_position)
	if distance <= player.coin_magnet_radius:
		global_position = global_position.move_toward(player.global_position, magnet_speed * delta)


func _collect(_player: Player) -> bool:
	GameManager.add_coins(value)
	return true


func _init() -> void:
	collect_sound = &"coin_pickup"
