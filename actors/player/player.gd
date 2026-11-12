class_name Player
extends CharacterBody2D
## Player character: top-down movement, two weapon slots, one basic skill and attacks
## with the active weapon. Reads only Input Map actions, so keyboard, touch controls
## and the bot drive it the same way.

## Emitted when the player swaps to another weapon or gets a new one.
## For the HUD and telemetry (weapon usage).
signal weapon_changed(slot: int, data: WeaponData)
## Emitted when the thing the interact button would use changes (null = nothing near).
signal interaction_changed(target: WeaponPickup)

## How many weapons the player can carry.
const WEAPON_SLOT_COUNT: int = 2
## Group the player is in; enemies find their target through it.
const GROUP: StringName = &"player"

## Maximum speed in pixels per second.
@export var move_speed: float = 90.0
## How quickly the player reaches full speed, in pixels per second squared.
@export var acceleration: float = 900.0
## How quickly the player stops when there is no input, in pixels per second squared.
@export var deceleration: float = 1200.0
## Weapons the player starts with, at most WEAPON_SLOT_COUNT. Chosen before the run.
@export var starting_weapons: Array[WeaponData] = []
## Basic skill for this run (dash or block). Chosen before the run.
@export var starting_skill: SkillData
## Health of the player. Its death is reported to GameManager.
@export var health: Health
## Area where enemy attacks hit the player. The shield guards it.
@export var hurtbox: Hurtbox
## Optional: makes the player react to spikes and pits.
@export var hazards: HazardReceiver
## Optional: camera that follows the player and stops at the edges of the Level.
@export var camera: Camera2D
## Physics layers of the hurtboxes auto-aim looks for (enemy_hurtbox).
@export_flags_2d_physics var aim_target_mask: int = 16
## Physics layers that hide a target from auto-aim (world).
@export_flags_2d_physics var aim_wall_mask: int = 1
## Things closer than this can be used with the interact button, in pixels.
@export var interact_radius: float = 20.0

## Last non-zero movement direction (unit vector).
var facing: Vector2 = Vector2.RIGHT
## Weapon in the player's hands, null when unarmed.
var weapon: Weapon = null
## Basic skill, null if none was chosen.
var skill: Skill = null
## True while a skill carries the player over the ground (dash): hazards are ignored.
var is_airborne: bool = false
## What the interact button would use now, or null.
var interaction_target: WeaponPickup = null

## Weapon nodes by slot. Only the active one is visible and gets input;
## the other one's cooldown keeps running.
var _weapons: Array[Weapon] = []
var _active_slot: int = 0
var _aim_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
var _aim_shape: CircleShape2D = CircleShape2D.new()


func _ready() -> void:
	# Top-down game: no floor or gravity, every collision is treated as a wall.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	add_to_group(GROUP)
	_aim_query.shape = _aim_shape
	_aim_query.collision_mask = aim_target_mask
	_aim_query.collide_with_areas = true
	_aim_query.collide_with_bodies = false
	if health != null:
		health.died.connect(_on_died)
	else:
		push_warning("Player has no Health assigned")
	if hazards != null:
		hazards.fall_started.connect(_on_fall_started)
		hazards.fall_ended.connect(_on_fall_ended)
	for weapon_data: WeaponData in starting_weapons:
		add_weapon(weapon_data)
	if starting_skill != null:
		set_skill(starting_skill)
	update_camera_limits()


func _physics_process(delta: float) -> void:
	_move(delta)
	_handle_skill_input()
	if Input.is_action_just_pressed("swap_weapon"):
		swap_weapon()
	_update_interaction()
	if Input.is_action_just_pressed("interact") and interaction_target != null:
		interaction_target.interact(self)
	_handle_attack_input()


## Takes a weapon from the floor. With a free slot it goes there and nothing is
## returned. With both slots full it replaces the weapon in hand, which is returned
## so it can be left on the floor.
func pick_up_weapon(weapon_data: WeaponData) -> WeaponData:
	if _weapons.size() < WEAPON_SLOT_COUNT:
		add_weapon(weapon_data)
		return null
	var dropped: WeaponData = weapon.data
	var old_weapon: Weapon = weapon
	old_weapon.set_active(false)
	old_weapon.queue_free()
	var new_weapon: Weapon = _create_weapon(weapon_data)
	if new_weapon == null:
		return null
	_weapons[_active_slot] = new_weapon
	_activate_slot(_active_slot)
	weapon_changed.emit(_active_slot, weapon.data)
	return dropped


## Puts a weapon into the first free slot. Returns false if both slots are taken.
## The first weapon becomes the active one.
func add_weapon(weapon_data: WeaponData) -> bool:
	if _weapons.size() >= WEAPON_SLOT_COUNT:
		return false
	var new_weapon: Weapon = _create_weapon(weapon_data)
	if new_weapon == null:
		return false
	_weapons.append(new_weapon)
	if _weapons.size() == 1:
		_activate_slot(0)
	else:
		new_weapon.set_active(false)
	weapon_changed.emit(_active_slot, weapon.data)
	return true


## True if the player already carries a weapon with this id.
func has_weapon(weapon_id: StringName) -> bool:
	for carried: Weapon in _weapons:
		if carried.data.id == weapon_id:
			return true
	return false


## Data of the weapon in each slot, in slot order. For the HUD.
func get_weapon_slots() -> Array[WeaponData]:
	var slots: Array[WeaponData] = []
	for carried: Weapon in _weapons:
		slots.append(carried.data)
	return slots


func get_active_slot() -> int:
	return _active_slot


func _create_weapon(weapon_data: WeaponData) -> Weapon:
	if weapon_data == null or weapon_data.weapon_scene == null:
		push_error("Weapon %s has no weapon_scene" % weapon_data)
		return null
	var new_weapon: Weapon = weapon_data.weapon_scene.instantiate() as Weapon
	new_weapon.setup(weapon_data, self)
	add_child(new_weapon)
	return new_weapon


## Finds the nearest thing to interact with and reports when it changes.
func _update_interaction() -> void:
	var nearest: WeaponPickup = null
	var nearest_distance: float = interact_radius
	for node: Node in get_tree().get_nodes_in_group(WeaponPickup.GROUP):
		var pickup: WeaponPickup = node as WeaponPickup
		if pickup == null or pickup.is_queued_for_deletion():
			continue
		var distance: float = global_position.distance_to(pickup.global_position)
		if distance <= nearest_distance:
			nearest = pickup
			nearest_distance = distance
	if nearest != interaction_target:
		interaction_target = nearest
		interaction_changed.emit(nearest)


## Switches to the next weapon slot. With fewer than two weapons it does nothing.
func swap_weapon() -> void:
	if _weapons.size() < 2:
		return
	_activate_slot((_active_slot + 1) % _weapons.size())
	weapon_changed.emit(_active_slot, weapon.data)


## Replaces the basic skill with one built from skill_data.
func set_skill(skill_data: SkillData) -> void:
	if skill != null:
		skill.queue_free()
		skill = null
	if skill_data == null or skill_data.skill_scene == null:
		push_error("Skill %s has no skill_scene" % skill_data)
		return
	skill = skill_data.skill_scene.instantiate() as Skill
	skill.setup(skill_data, self)
	add_child(skill)


## Where attacks, shots and the shield point: at the nearest visible enemy within the
## weapon's auto-aim radius, otherwise where the player last moved.
func get_look_direction() -> Vector2:
	var target: Hurtbox = _find_aim_target()
	if target == null:
		return facing
	return global_position.direction_to(target.global_position)


## Moves the player to a new place at once (start of a section).
func teleport(new_position: Vector2) -> void:
	global_position = new_position
	velocity = Vector2.ZERO
	if hazards != null:
		hazards.reset()
	update_camera_limits()
	if camera != null:
		camera.reset_smoothing()


## Switches player control off (section change) and back on.
func set_controls_enabled(enabled: bool) -> void:
	if not enabled:
		_stop_acting()
	elif not health.is_dead() and not (hazards != null and hazards.is_falling()):
		set_physics_process(true)


## Keeps the camera inside the Level the player stands on, if there is one.
func update_camera_limits() -> void:
	if camera == null or not is_inside_tree():
		return
	var level: Level = get_tree().get_first_node_in_group(Level.GROUP) as Level
	if level == null or level.grid == null:
		return
	var bounds: Rect2 = level.get_bounds()
	camera.limit_left = int(bounds.position.x)
	camera.limit_top = int(bounds.position.y)
	camera.limit_right = int(bounds.end.x)
	camera.limit_bottom = int(bounds.end.y)


## Called by skills that lift the player off the ground (dash).
func set_airborne(value: bool) -> void:
	is_airborne = value
	if hazards != null:
		hazards.suspended = value


func _move(delta: float) -> void:
	if skill != null:
		var forced_velocity: Vector2 = skill.get_forced_velocity()
		if not forced_velocity.is_zero_approx():
			# The skill moves the player (dash): input is ignored for its duration.
			velocity = forced_velocity
			facing = forced_velocity.normalized()
			move_and_slide()
			return
	# Length is at most 1, and below 1 when a joystick is only partly tilted.
	var input_dir: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	# Weapon and skill can slow the player down (drawn bow, raised shield).
	var speed: float = move_speed
	if weapon != null:
		speed *= weapon.get_move_speed_multiplier()
	if skill != null:
		speed *= skill.get_move_speed_multiplier()
	if input_dir != Vector2.ZERO:
		facing = input_dir.normalized()
		velocity = velocity.move_toward(input_dir * speed, acceleration * delta)
	else:
		velocity = velocity.move_toward(Vector2.ZERO, deceleration * delta)
	move_and_slide()


func _handle_skill_input() -> void:
	if skill == null:
		return
	if Input.is_action_just_pressed("skill"):
		# Dash goes where the player is heading; without input, where they last moved.
		var heading: Vector2 = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		skill.press(heading if not heading.is_zero_approx() else facing)
		if skill.blocks_attacks() and weapon != null:
			weapon.cancel_attack()
	if Input.is_action_just_released("skill"):
		skill.release()


func _handle_attack_input() -> void:
	if weapon == null or (skill != null and skill.blocks_attacks()):
		return
	if Input.is_action_just_pressed("attack"):
		weapon.try_attack(get_look_direction())
	if Input.is_action_just_released("attack"):
		weapon.release_attack(get_look_direction())


## Nearest enemy hurtbox within the active weapon's auto-aim radius that is not
## behind a wall, or null.
func _find_aim_target() -> Hurtbox:
	if weapon == null or weapon.data.auto_aim_radius <= 0.0 or not is_inside_tree():
		return null
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	_aim_shape.radius = weapon.data.auto_aim_radius
	_aim_query.transform = Transform2D(0.0, global_position)
	var nearest: Hurtbox = null
	var nearest_distance: float = INF
	for result: Dictionary in space.intersect_shape(_aim_query):
		var candidate: Hurtbox = result["collider"] as Hurtbox
		if candidate == null or (candidate.health != null and candidate.health.is_dead()):
			continue
		var distance: float = global_position.distance_to(candidate.global_position)
		if distance >= nearest_distance:
			continue
		var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
				global_position, candidate.global_position, aim_wall_mask)
		if not space.intersect_ray(ray).is_empty():
			continue
		nearest = candidate
		nearest_distance = distance
	return nearest


## The player only reports its death; GameManager decides what happens next.
func _on_died(info: DamageInfo) -> void:
	_stop_acting()
	GameManager.report_player_death(info)


func _on_fall_started() -> void:
	_stop_acting()


func _on_fall_ended() -> void:
	if not health.is_dead():
		set_physics_process(true)


## Freezes the player: no movement, attacks or skill (death, falling into a pit).
func _stop_acting() -> void:
	if interaction_target != null:
		interaction_target = null
		interaction_changed.emit(null)
	set_physics_process(false)
	velocity = Vector2.ZERO
	if weapon != null:
		weapon.cancel_attack()
	if skill != null:
		skill.cancel()


func _activate_slot(slot: int) -> void:
	for i in _weapons.size():
		_weapons[i].set_active(i == slot)
	_active_slot = slot
	weapon = _weapons[slot]
