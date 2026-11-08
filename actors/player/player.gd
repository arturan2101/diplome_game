class_name Player
extends CharacterBody2D
## Player character with top-down movement.
## Reads only Input Map actions, so keyboard and the touch joystick drive it the same way.

## Maximum speed in pixels per second.
@export var move_speed: float = 90.0
## How quickly the player reaches full speed, in pixels per second squared.
@export var acceleration: float = 900.0
## How quickly the player stops when there is no input, in pixels per second squared.
@export var deceleration: float = 1200.0

## Last non-zero movement direction (unit vector). Used later by attacks and auto-aim.
var facing: Vector2 = Vector2.RIGHT


func _ready() -> void:
	# Top-down game: no floor or gravity, every collision is treated as a wall.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING


func _physics_process(delta: float) -> void:
	# Length is at most 1, and below 1 when a joystick is only partly tilted.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	move_and_slide()
