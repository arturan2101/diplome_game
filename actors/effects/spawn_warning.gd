class_name SpawnWarning
extends Sprite2D
## Visual only: a ring on the floor that grows and brightens where an elite enemy or
## a wave is about to appear, then frees itself. The spawner sets duration (seconds)
## and adds it at the spawn point; the enemy comes when the ring is done.

@export var duration: float = 0.8
@export var frame_count: int = 8

var _time: float = 0.0


func _ready() -> void:
	hframes = frame_count
	z_index = -1


func _process(delta: float) -> void:
	_time += delta
	frame = mini(int(_time / duration * frame_count), frame_count - 1)
	if _time >= duration:
		queue_free()
