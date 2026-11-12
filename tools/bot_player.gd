class_name BotPlayer
extends Node
## Plays the game instead of a person, for headless test runs and (later) for
## training the learned director. It "presses" the same Input Map actions as the
## keyboard and the touch controls, so the player script does not know the difference.
## Behaviour: walk along the grid path to the nearest enemy and attack it; pick up a
## health pack when hurt; take a weapon from the floor while a slot is free; when no
## enemies are left, walk to the gate.

const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]

## The run this bot plays.
@export var game: Game
## Seconds between path recalculations.
@export var repath_interval: float = 0.25
## A waypoint closer than this counts as reached, in pixels.
@export var waypoint_reach: float = 5.0
## The bot goes for a health pack below this share of max HP.
@export_range(0.0, 1.0) var heal_below: float = 0.5
## Melee: attack when the enemy is this close, in pixels.
@export var melee_attack_distance: float = 22.0
## Bow: shoot from at most this far, and hold the draw this long, in seconds.
@export var bow_attack_distance: float = 120.0
@export var bow_hold_time: float = 0.6

var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _repath_time_left: float = 0.0
var _is_attack_held: bool = false
var _attack_held_time: float = 0.0


func _exit_tree() -> void:
	_release_everything()


func _physics_process(delta: float) -> void:
	var player: Player = game.player
	if player == null or not player.is_physics_processing() or player.health.is_dead():
		_release_everything()
		return
	var enemy: Enemy = _nearest_enemy(player)
	var goal: Vector2 = _choose_goal(player, enemy)
	var wants_to_stand: bool = _handle_attack(player, enemy, delta)
	_move(player, goal, delta, wants_to_stand)
	_handle_interact(player)


## Where to walk: a health pack when hurt, else the nearest enemy, else the gate.
func _choose_goal(player: Player, enemy: Enemy) -> Vector2:
	if float(player.health.hp) / float(player.health.max_hp) < heal_below:
		var pack: HealthPack = _nearest_health_pack(player)
		if pack != null:
			return pack.global_position
	if enemy != null:
		return enemy.global_position
	return game.gate.global_position if game.gate != null else player.global_position


## Presses or releases the attack action. Returns true if the bot should stand still
## (drawing the bow).
func _handle_attack(player: Player, enemy: Enemy, delta: float) -> bool:
	if enemy == null or player.weapon == null:
		_set_attack(false)
		return false
	var distance: float = player.global_position.distance_to(enemy.global_position)
	if player.weapon is BowWeapon:
		if distance <= bow_attack_distance and _can_see(player, enemy):
			_attack_held_time += delta
			if _is_attack_held and _attack_held_time >= bow_hold_time:
				_set_attack(false)
			elif not _is_attack_held:
				_set_attack(true)
			return true
		_set_attack(false)
		return false
	# Melee: tap the button every other frame while the enemy is in reach.
	_set_attack(distance <= melee_attack_distance and not _is_attack_held)
	return false


func _move(player: Player, goal: Vector2, delta: float, stand_still: bool) -> void:
	var direction: Vector2 = Vector2.ZERO
	if not stand_still:
		direction = _direction_along_path(player, goal, delta)
	for action: StringName in MOVE_ACTIONS:
		Input.action_release(action)
	if direction.x < 0.0:
		Input.action_press(&"move_left", -direction.x)
	elif direction.x > 0.0:
		Input.action_press(&"move_right", direction.x)
	if direction.y < 0.0:
		Input.action_press(&"move_up", -direction.y)
	elif direction.y > 0.0:
		Input.action_press(&"move_down", direction.y)


func _direction_along_path(player: Player, goal: Vector2, delta: float) -> Vector2:
	_repath_time_left -= delta
	if _repath_time_left <= 0.0:
		_repath_time_left = repath_interval
		_path = game.level.find_path(player.global_position, goal)
		_path_index = 1
	while _path_index < _path.size() and player.global_position.distance_to(_path[_path_index]) <= waypoint_reach:
		_path_index += 1
	if _path_index < _path.size():
		return player.global_position.direction_to(_path[_path_index])
	if player.global_position.distance_to(goal) > waypoint_reach:
		return player.global_position.direction_to(goal)
	return Vector2.ZERO


func _set_attack(pressed: bool) -> void:
	if pressed == _is_attack_held:
		return
	_is_attack_held = pressed
	_attack_held_time = 0.0
	if pressed:
		Input.action_press(&"attack")
	else:
		Input.action_release(&"attack")


## Presses interact for one frame when a weapon lies near and a slot is free.
func _handle_interact(player: Player) -> void:
	if Input.is_action_pressed(&"interact"):
		Input.action_release(&"interact")
	elif player.interaction_target != null and player.get_weapon_slots().size() < Player.WEAPON_SLOT_COUNT:
		Input.action_press(&"interact")


func _release_everything() -> void:
	Input.action_release(&"interact")
	for action: StringName in MOVE_ACTIONS:
		Input.action_release(action)
	_set_attack(false)


func _nearest_enemy(player: Player) -> Enemy:
	var nearest: Enemy = null
	var nearest_distance: float = INF
	for enemy: Enemy in game.get_enemies():
		var distance: float = player.global_position.distance_squared_to(enemy.global_position)
		if distance < nearest_distance:
			nearest = enemy
			nearest_distance = distance
	return nearest


func _nearest_health_pack(player: Player) -> HealthPack:
	var nearest: HealthPack = null
	var nearest_distance: float = INF
	for pickup: Pickup in game.get_pickups():
		var pack: HealthPack = pickup as HealthPack
		if pack == null:
			continue
		var distance: float = player.global_position.distance_squared_to(pack.global_position)
		if distance < nearest_distance:
			nearest = pack
			nearest_distance = distance
	return nearest


func _can_see(player: Player, enemy: Enemy) -> bool:
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			player.global_position, enemy.global_position, player.aim_wall_mask)
	return player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
