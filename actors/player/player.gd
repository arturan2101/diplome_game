class_name Player
extends CharacterBody2D
## Player character: top-down movement, two weapon slots and attacks with the active weapon.
## Reads only Input Map actions, so keyboard and touch controls drive it the same way.

## Emitted when the player swaps to another weapon. For the HUD and telemetry (weapon usage).
signal weapon_changed(slot: int, data: WeaponData)

## How many weapons the player can carry.
const WEAPON_SLOT_COUNT: int = 2
## Group the player is in; enemies find their target through it.
const GROUP: StringName = &"player"
const GAME_MANAGER_PATH: NodePath = ^"/root/GameManager"

## Maximum speed in pixels per second.
@export var move_speed: float = 90.0
## How quickly the player reaches full speed, in pixels per second squared.
@export var acceleration: float = 900.0
## How quickly the player stops when there is no input, in pixels per second squared.
@export var deceleration: float = 1200.0
## Weapons the player starts with, at most WEAPON_SLOT_COUNT. Later chosen before the run.
@export var starting_weapons: Array[WeaponData] = []
## Health of the player. Its death is reported to GameManager.
@export var health: Health

## Last non-zero movement direction (unit vector). Used by attacks and later by auto-aim.
var facing: Vector2 = Vector2.RIGHT
## Weapon in the player's hands, null when unarmed.
var weapon: Weapon = null

## Weapon nodes by slot. Only the active one is visible and gets input;
## the other one's cooldown keeps running.
var _weapons: Array[Weapon] = []
var _active_slot: int = 0


func _ready() -> void:
	# Top-down game: no floor or gravity, every collision is treated as a wall.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(GROUP)
	if health != null:
		health.damaged.connect(_on_damaged)
		health.died.connect(_on_died)
	else:
		push_warning("Player has no Health assigned")
	_create_starting_weapons()


func _physics_process(delta: float) -> void:
	_move(delta)
	if Input.is_action_just_pressed("swap_weapon"):
		swap_weapon()
	if weapon == null:
		return
	if Input.is_action_just_pressed("attack"):
		weapon.try_attack(_aim_direction())
	if Input.is_action_just_released("attack"):
		weapon.release_attack(_aim_direction())


## Switches to the next weapon slot. With fewer than two weapons it does nothing.
func swap_weapon() -> void:
	if _weapons.size() < 2:
		return
	_activate_slot((_active_slot + 1) % _weapons.size())
	weapon_changed.emit(_active_slot, weapon.data)


## Direction of attacks and shots. The single place to plug in auto-aim later.
func _aim_direction() -> Vector2:
	return facing


func _move(delta: float) -> void:
	# Length is at most 1, and below 1 when a joystick is only partly tilted.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# The weapon can slow the player down, e.g. while drawing a bow.
	var speed: float = move_speed
	if weapon != null:
		speed *= weapon.get_move_speed_multiplier()
	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	move_and_slide()


func _create_starting_weapons() -> void:
	if starting_weapons.size() > WEAPON_SLOT_COUNT:
		push_warning("Player has %d starting weapons but only %d slots" % [starting_weapons.size(), WEAPON_SLOT_COUNT])
	for weapon_data: WeaponData in starting_weapons.slice(0, WEAPON_SLOT_COUNT):
		var new_weapon: Weapon = _create_weapon(weapon_data)
		if new_weapon != null:
			_weapons.append(new_weapon)
	if not _weapons.is_empty():
		_activate_slot(0)


func _create_weapon(weapon_data: WeaponData) -> Weapon:
	if weapon_data == null or weapon_data.weapon_scene == null:
		push_error("Starting weapon %s has no weapon_scene" % weapon_data)
		return null
	var new_weapon: Weapon = weapon_data.weapon_scene.instantiate() as Weapon
	new_weapon.setup(weapon_data, self)
	add_child(new_weapon)
	return new_weapon


func _on_damaged(info: DamageInfo) -> void:
	print("Player: %d damage from %s, hp %d/%d" % [info.amount, info.source_id, health.hp, health.max_hp])


## The player only reports its death; GameManager decides what happens next.
func _on_died(info: DamageInfo) -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	if weapon != null:
		weapon.cancel_attack()
	# Looked up by path, not by the autoload name: headless tests (--script) compile this
	# script before autoloads are registered, so the name GameManager would not resolve.
	get_node(GAME_MANAGER_PATH).report_player_death(info)


func _activate_slot(slot: int) -> void:
	for i in _weapons.size():
		_weapons[i].set_active(i == slot)
	_active_slot = slot
	weapon = _weapons[slot]
