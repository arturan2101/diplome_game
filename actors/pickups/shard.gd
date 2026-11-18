class_name Shard
extends Pickup
## A ruin shard (stage 33): dropped by elite enemies, the golem and the boss; kept
## between runs (Progress) and spent in the camp.

@export var value: int = 1
## The shard bobs a little so it reads apart from coins.
@export var bob_height: float = 2.0
@export var bob_speed: float = 3.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	var sprite: Node2D = get_node_or_null("Sprite") as Node2D
	if sprite != null:
		sprite.position.y = -absf(sin(_time * bob_speed)) * bob_height


func _collect(_player: Player) -> bool:
	Progress.add_shards(value)
	return true
