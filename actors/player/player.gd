class_name Player
extends CharacterBody2D
## Player character: top-down movement and attacks with the equipped weapon.
## Reads only Input Map actions, so keyboard and touch controls drive it the same way.

## Maximum speed in pixels per second.
@export var move_speed: float = 90.0
## How quickly the player reaches full speed, in pixels per second squared.
@export var acceleration: float = 900.0
## How quickly the player stops when there is no input, in pixels per second squared.
@export var deceleration: float = 1200.0
## Weapon the player starts with. Later it is chosen before the run.
@export var starting_weapon: WeaponData

## Last non-zero movement direction (unit vector). Used by attacks and later by auto-aim.
var facing: Vector2 = Vector2.RIGHT
## Currently equipped weapon node, null when unarmed.
var weapon: Weapon = null


func _ready() -> void:
	# Top-down game: no floor or gravity, every collision is treated as a wall.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if starting_weapon != null:
		equip(starting_weapon)


func _physics_process(delta: float) -> void:
	_move(delta)
	if weapon != null and Input.is_action_just_pressed("attack"):
		weapon.try_attack(facing)


## Replaces the current weapon with a new one built from weapon_data.
func equip(weapon_data: WeaponData) -> void:
	if weapon_data.weapon_scene == null:
		push_error("Weapon %s has no weapon_scene" % weapon_data.id)
		return
	if weapon != null:
		weapon.queue_free()
	weapon = weapon_data.weapon_scene.instantiate() as Weapon
	weapon.setup(weapon_data, self)
	add_child(weapon)


func _move(delta: float) -> void:
	# Length is at most 1, and below 1 when a joystick is only partly tilted.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * move_speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	move_and_slide()
