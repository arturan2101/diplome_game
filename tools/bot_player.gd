class_name BotPlayer
extends Node
## Plays the game instead of a person, for headless runs and (later) for training the
## learned director. It "presses" the same Input Map actions as the keyboard and the
## touch controls, so the player script does not know the difference.
## Behaviour: walk along the grid path to the nearest enemy and attack it; get out of
## the way of telegraphed attacks (step aside, dash or raise the shield); pick up a
## health pack when hurt; take a weapon from the floor while a slot is free; when no
## enemies are left, walk to the gate. How well it does all this comes from a
## BotProfile (weak, mid, strong); its random choices come from GameManager.make_bot_rng().

const MOVE_ACTIONS: Array[StringName] = [&"move_left", &"move_right", &"move_up", &"move_down"]
## Launch argument: --bot (mid bot) or --bot=weak|mid|strong.
const BOT_ARG: String = "--bot"
const PROFILES_DIR: String = "res://tools/bots"

const DEFAULT_PROFILE: BotProfile = preload("res://tools/bots/mid.tres")
## An enemy closer than its attack range plus this margin is a threat when it winds up.
const THREAT_MARGIN: float = 16.0
## Shields stay up at most this long when blocking a windup, in seconds.
const BLOCK_HOLD_TIME: float = 0.7
## If the bot gets no closer to its goal than this (pixels) within PROGRESS_TIME
## seconds, it takes a short random detour (stuck on a corner or another body).
const PROGRESS_DISTANCE: float = 8.0
const PROGRESS_TIME: float = 3.0
const DETOUR_TIME: float = 0.8
const DETOUR_DIRECTIONS: int = 8
## Extra pixels of safe floor wanted beyond the end of a dodge.
const DODGE_SAFETY_MARGIN: float = 8.0
## The current goal (enemy or health pack) stays the goal unless another one is
## closer by more than this many pixels of walking.
const KEEP_GOAL_MARGIN: float = 16.0

## The run this bot plays.
@export var game: Game
@export var profile: BotProfile
## Seconds between path recalculations.
@export var repath_interval: float = 0.25
## A waypoint closer than this counts as reached, in pixels.
@export var waypoint_reach: float = 5.0

var _rng: RandomNumberGenerator = null
var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _repath_time_left: float = 0.0
var _walk_straight: bool = false
var _is_attack_held: bool = false
var _attack_held_time: float = 0.0
## The enemy being fought, and the time since it became the target (reaction).
var _target: Enemy = null
var _target_time: float = 0.0
var _retarget_time_left: float = 0.0
var _pack_goal: HealthPack = null
## Windups already decided on: enemy instance id -> true.
var _seen_windups: Dictionary = {}
## Enemy instance id -> seconds since its windup was first seen.
var _windup_seen_time: Dictionary = {}
var _dodge_time_left: float = 0.0
var _dodge_direction: Vector2 = Vector2.ZERO
var _block_time_left: float = 0.0
var _skill_pressed_last_frame: bool = false
var _hesitation_left: float = 0.0
var _jitter_angle: float = 0.0
var _jitter_time_left: float = 0.0
var _progress_time: float = 0.0
var _progress_distance: float = INF


## The profile asked for on the command line, or null if no bot was asked for.
static func profile_from_command_line() -> BotProfile:
	for arg: String in OS.get_cmdline_user_args():
		if arg == BOT_ARG:
			return DEFAULT_PROFILE
		if arg.begins_with(BOT_ARG + "="):
			return load_profile(arg.trim_prefix(BOT_ARG + "="))
	return null


## The profile tools/bots/<name>.tres, or the mid one if there is no such file.
static func load_profile(profile_name: String) -> BotProfile:
	var path: String = PROFILES_DIR.path_join(profile_name + ".tres")
	if ResourceLoader.exists(path):
		return load(path) as BotProfile
	push_warning("Unknown bot profile '%s', using mid" % profile_name)
	return DEFAULT_PROFILE


func _ready() -> void:
	if profile == null:
		profile = DEFAULT_PROFILE
	_rng = GameManager.make_bot_rng()


func _exit_tree() -> void:
	_release_everything()


func _physics_process(delta: float) -> void:
	var player: Player = game.player
	if player == null or not player.is_physics_processing() or player.health.is_dead():
		_release_everything()
		return
	_update_target(player, delta)
	_handle_skill(player, delta)
	var noticed: Enemy = _target if _target_time >= profile.reaction_time else null
	var stand_still: bool = _handle_attack(player, noticed, delta)
	_move(player, _movement_direction(player, noticed, delta, stand_still))
	_handle_interact(player)


## One line about what the bot is doing, for reports of stuck simulations.
func debug_state() -> String:
	var player: Player = game.player
	var target: String = "none"
	if is_instance_valid(_target):
		target = "%s at %d px" % [_target.data.id, roundi(player.global_position.distance_to(_target.global_position))]
	var next: String = "-"
	if _path_index < _path.size():
		next = str(game.level.cell_at(_path[_path_index]))
	return "target %s, path %d points (next %s), straight %s, dodge %.1f s, block %.1f s, hesitation %.1f s" % [
			target, _path.size(), next, _walk_straight, _dodge_time_left, _block_time_left, _hesitation_left]


# --- choosing what to do -------------------------------------------------

func _update_target(player: Player, delta: float) -> void:
	# A killed target is freed at the end of a frame; a freed object must not be kept.
	if not is_instance_valid(_target):
		_target = null
	var nearest: Enemy = _target
	_retarget_time_left -= delta
	if _retarget_time_left <= 0.0 or not is_instance_valid(_target) or _target.health.is_dead():
		_retarget_time_left = repath_interval
		nearest = _nearest_reachable_enemy(player)
	if nearest != _target:
		_target = nearest
		_target_time = 0.0
	else:
		_target_time += delta


## Where to walk this frame: dodge first, then a health pack when hurt, then the
## noticed enemy, else the gate. Zero = stand still.
func _movement_direction(player: Player, enemy: Enemy, delta: float, stand_still: bool) -> Vector2:
	if _dodge_time_left > 0.0:
		_dodge_time_left -= delta
		return _dodge_direction
	if _hesitation_left > 0.0:
		_hesitation_left -= delta
		return Vector2.ZERO
	if _rng.randf() < profile.hesitation_chance * delta:
		_hesitation_left = profile.hesitation_time
	if stand_still:
		return Vector2.ZERO
	var goal: Vector2 = _choose_goal(player, enemy)
	_check_progress(player, goal, delta)
	# A bow user that likes distance steps back from a close enemy.
	if enemy != null and player.weapon is BowWeapon and profile.bow_keep_distance > 0.0 \
			and player.global_position.distance_to(enemy.global_position) < profile.bow_keep_distance:
		return enemy.global_position.direction_to(player.global_position)
	return _jitter(_direction_along_path(player, goal, delta), delta)


func _check_progress(player: Player, goal: Vector2, delta: float) -> void:
	var distance: float = player.global_position.distance_to(goal)
	if distance < _progress_distance - PROGRESS_DISTANCE or distance <= profile.melee_attack_distance:
		_progress_distance = distance
		_progress_time = 0.0
		return
	_progress_time += delta
	if _progress_time < PROGRESS_TIME:
		return
	_progress_time = 0.0
	_progress_distance = INF
	# A short detour in a random direction that does not lead over a hazard.
	var start_angle: float = _rng.randf() * TAU
	for i in DETOUR_DIRECTIONS:
		var direction: Vector2 = Vector2.from_angle(start_angle + TAU * i / DETOUR_DIRECTIONS)
		if _is_safe_line(player.global_position, direction, player.move_speed * DETOUR_TIME):
			_dodge_direction = direction
			_dodge_time_left = DETOUR_TIME
			return


func _choose_goal(player: Player, enemy: Enemy) -> Vector2:
	if float(player.health.hp) / float(player.health.max_hp) < profile.heal_below:
		if not is_instance_valid(_pack_goal) or _pack_goal.is_queued_for_deletion() or _retarget_time_left == repath_interval:
			_pack_goal = _nearest_reachable_health_pack(player)
		if _pack_goal != null:
			return _pack_goal.global_position
	if enemy != null:
		return enemy.global_position
	return game.gate.global_position if game.gate != null else player.global_position


## Dodging telegraphed attacks: each windup is decided once, after the reaction time.
func _handle_skill(player: Player, delta: float) -> void:
	if _skill_pressed_last_frame and not (player.skill is BlockSkill and _block_time_left > 0.0):
		Input.action_release(&"skill")
		_skill_pressed_last_frame = false
	if _block_time_left > 0.0:
		_block_time_left -= delta
		if _block_time_left <= 0.0:
			Input.action_release(&"skill")
			_skill_pressed_last_frame = false
	for enemy: Enemy in game.get_enemies():
		var id: int = enemy.get_instance_id()
		if enemy.state != Enemy.State.WINDUP:
			_windup_seen_time.erase(id)
			_seen_windups.erase(id)
			continue
		if _seen_windups.has(id):
			continue
		var distance: float = player.global_position.distance_to(enemy.global_position)
		if distance > enemy.get_windup_reach() + THREAT_MARGIN:
			continue
		_windup_seen_time[id] = float(_windup_seen_time.get(id, 0.0)) + delta
		if _windup_seen_time[id] < profile.reaction_time:
			continue
		_seen_windups[id] = true
		if _rng.randf() < profile.dodge_chance:
			_dodge(player, enemy)


func _dodge(player: Player, enemy: Enemy) -> void:
	var away: Vector2 = enemy.global_position.direction_to(player.global_position)
	var side: Vector2 = away.orthogonal() * (1.0 if _rng.randf() < 0.5 else -1.0)
	# Arrows fly along the line to the player: step across it instead.
	var is_ranged: bool = enemy.is_windup_ranged()
	# Out of a melee swing: back and to the side leaves both its reach and its arc.
	var wanted: Array[Vector2] = [(away + side).normalized(), (away - side).normalized(), away, side, -side]
	if is_ranged:
		wanted = [side, -side, away]
	var uses_skill: bool = player.skill != null and player.skill.is_ready() and _rng.randf() < profile.skill_use_chance
	var duration: float = profile.dodge_time
	if is_ranged:
		# Stay off the line until the arrow has flown past: the rest of the windup plus its flight.
		var bow: BowWeaponData = enemy.weapon.data as BowWeaponData if enemy.weapon != null else null
		if bow != null:
			duration += enemy.data.windup + player.global_position.distance_to(enemy.global_position) / bow.arrow_speed
	# The bot walks that way for the whole dodge; a dash adds its own distance on top.
	var reach: float = player.move_speed * duration + DODGE_SAFETY_MARGIN
	if uses_skill and player.skill is DashSkill:
		reach += (player.skill.data as DashSkillData).distance
	_dodge_direction = Vector2.ZERO
	for direction: Vector2 in wanted:
		if _is_safe_line(player.global_position, direction, reach):
			_dodge_direction = direction
			break
	if _dodge_direction.is_zero_approx() and not player.skill is BlockSkill:
		# Nowhere safe to go: better take the hit than jump into a pit.
		return
	_dodge_time_left = duration
	if not uses_skill:
		return
	Input.action_press(&"skill")
	_skill_pressed_last_frame = true
	if player.skill is BlockSkill:
		# Stand and hold the shield towards the attacker instead of running.
		_dodge_time_left = 0.0
		_block_time_left = BLOCK_HOLD_TIME


## Presses or releases the attack action. Returns true if the bot should stand still
## (drawing the bow).
func _handle_attack(player: Player, enemy: Enemy, delta: float) -> bool:
	if enemy == null or player.weapon == null or _block_time_left > 0.0:
		_set_attack(false)
		return false
	var distance: float = player.global_position.distance_to(enemy.global_position)
	if player.weapon is BowWeapon:
		if distance <= profile.bow_attack_distance and _can_see(player, enemy):
			_attack_held_time += delta
			if _is_attack_held and _attack_held_time >= profile.bow_hold_time:
				_set_attack(false)
			elif not _is_attack_held:
				_set_attack(true)
			return true
		_set_attack(false)
		return false
	# Melee: tap the button every other frame while the enemy is in reach;
	# a careless bot sometimes swings from too far.
	var reach: float = profile.melee_attack_distance
	var in_reach: bool = distance <= reach or (distance <= reach * 2.0 and _rng.randf() < profile.miss_chance)
	_set_attack(in_reach and not _is_attack_held)
	return false


# --- moving --------------------------------------------------------------

func _direction_along_path(player: Player, goal: Vector2, delta: float) -> Vector2:
	_repath_time_left -= delta
	if _repath_time_left <= 0.0:
		_repath_time_left = repath_interval
		# Not looking where it goes: straight at the goal, over whatever lies there.
		_walk_straight = _rng.randf() < profile.hazard_blind_chance
		_path = PackedVector2Array() if _walk_straight else game.level.find_path(player.global_position, goal)
		_path_index = 1
	while _path_index < _path.size() and player.global_position.distance_to(_path[_path_index]) <= waypoint_reach:
		_path_index += 1
	if _path_index < _path.size():
		return player.global_position.direction_to(_path[_path_index])
	if player.global_position.distance_to(goal) > waypoint_reach:
		return player.global_position.direction_to(goal)
	return Vector2.ZERO


## Turns the direction a little at random, so the bot does not move perfectly.
func _jitter(direction: Vector2, delta: float) -> Vector2:
	if direction.is_zero_approx() or profile.move_jitter_degrees <= 0.0:
		return direction
	_jitter_time_left -= delta
	if _jitter_time_left <= 0.0:
		_jitter_time_left = profile.jitter_interval
		_jitter_angle = deg_to_rad(_rng.randf_range(-profile.move_jitter_degrees, profile.move_jitter_degrees))
	return direction.rotated(_jitter_angle)


func _move(_player: Player, direction: Vector2) -> void:
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


## Presses interact for one frame when a weapon lies near and either a slot is free
## or it hits harder than the weapon in hand (a rarer one).
func _handle_interact(player: Player) -> void:
	if Input.is_action_pressed(&"interact"):
		Input.action_release(&"interact")
	elif is_instance_valid(player.interaction_target) and player.interaction_target is WeaponPickup \
			and _wants(player, (player.interaction_target as WeaponPickup).weapon_data):
		Input.action_press(&"interact")


## The bot only takes weapons (no scrolls or shrines): a free slot, or a harder hitter.
func _wants(player: Player, lying: WeaponData) -> bool:
	if lying == null:
		return false
	if player.get_weapon_slots().size() < Player.WEAPON_SLOT_COUNT:
		return true
	return player.weapon != null and lying.get_damage_multiplier() > player.weapon.data.get_damage_multiplier()


func _set_attack(pressed: bool) -> void:
	if pressed == _is_attack_held:
		return
	_is_attack_held = pressed
	_attack_held_time = 0.0
	if pressed:
		Input.action_press(&"attack")
	else:
		Input.action_release(&"attack")


func _release_everything() -> void:
	Input.action_release(&"interact")
	Input.action_release(&"skill")
	_skill_pressed_last_frame = false
	for action: StringName in MOVE_ACTIONS:
		Input.action_release(action)
	_set_attack(false)


# --- looking around ------------------------------------------------------

## The enemy with the shortest walk from the bot (or one already next to it), or null.
func _nearest_reachable_enemy(player: Player) -> Enemy:
	var enemies: Array[Node2D] = []
	enemies.assign(game.get_enemies())
	return _nearest_by_walk(player, enemies, _target) as Enemy


## The health pack with the shortest walk (not one behind a sealed arena door), or null.
func _nearest_reachable_health_pack(player: Player) -> HealthPack:
	var packs: Array[Node2D] = []
	for pickup: Pickup in game.get_pickups():
		if pickup is HealthPack:
			packs.append(pickup)
	var current: HealthPack = _pack_goal if is_instance_valid(_pack_goal) else null
	return _nearest_by_walk(player, packs, current) as HealthPack


## The node the bot can reach by the shortest walk, or null if it can reach none.
## Walking distance, not straight-line distance: two enemies on opposite sides of a
## wall can swap places as "nearest by straight line" at every step, and the bot then
## walks back and forth between them forever. Walking towards the nearest node along
## its path keeps it the nearest. The current goal (keep) also wins near-ties.
func _nearest_by_walk(player: Player, nodes: Array[Node2D], keep: Node2D) -> Node2D:
	var from: Vector2 = player.global_position
	nodes.sort_custom(func(a: Node2D, b: Node2D) -> bool:
		return from.distance_squared_to(a.global_position) < from.distance_squared_to(b.global_position))
	var tile: float = float(game.level.theme.tile_size)
	var best: Node2D = null
	var best_length: float = INF
	for node: Node2D in nodes:
		var straight: float = from.distance_to(node.global_position)
		# A walk is never shorter than the straight line (up to the cell rounding and
		# the bonus of the current goal), so the farther nodes cannot win any more.
		if straight - KEEP_GOAL_MARGIN - tile >= best_length:
			break
		var length: float = straight if straight <= tile * 2.0 else _walk_length(from, node.global_position)
		if node == keep:
			length -= KEEP_GOAL_MARGIN
		if length < best_length:
			best_length = length
			best = node
	return best


## Length of the walkable path between two points in pixels, INF when there is none.
func _walk_length(from: Vector2, to: Vector2) -> float:
	var path: PackedVector2Array = game.level.find_path(from, to)
	if path.is_empty():
		return INF
	var length: float = 0.0
	for i in range(1, path.size()):
		length += path[i - 1].distance_to(path[i])
	return length


## True if every tile along the line, up to the given distance, is plain floor.
func _is_safe_line(from: Vector2, direction: Vector2, distance: float) -> bool:
	var step: float = float(game.level.theme.tile_size) * 0.5
	var travelled: float = step
	while travelled <= distance + step:
		if game.level.cell_type_at(from + direction * travelled) != LevelGrid.Cell.FLOOR:
			return false
		travelled += step
	return true


func _can_see(player: Player, enemy: Enemy) -> bool:
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			player.global_position, enemy.global_position, player.aim_wall_mask)
	return player.get_world_2d().direct_space_state.intersect_ray(ray).is_empty()
