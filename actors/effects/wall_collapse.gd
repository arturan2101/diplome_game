class_name WallCollapse
extends Node2D
## Visual only: a secret wall falling down. Put it at the centre of the wall cell
## (the same moment the cell becomes floor); it plays the collapse, throws dust and
## stone chips, leaves the rubble for a while and frees itself.

@export var frame_time: float = 0.09
@export var rubble_time: float = 3.0
@export var fade_time: float = 0.8

@onready var _sprite: Sprite2D = $Sprite
@onready var _dust: CPUParticles2D = $Dust
@onready var _chips: CPUParticles2D = $Chips

var _time: float = 0.0


func _ready() -> void:
	_dust.emitting = true
	_chips.emitting = true


func _process(delta: float) -> void:
	_time += delta
	var last: int = _sprite.hframes - 1
	_sprite.frame = mini(int(_time / frame_time), last)
	var done: float = frame_time * _sprite.hframes + rubble_time
	if _time > done:
		_sprite.modulate.a = 1.0 - (_time - done) / fade_time
		if _time > done + fade_time:
			queue_free()
