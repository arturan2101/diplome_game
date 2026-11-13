class_name Enemy
extends CharacterBody2D
## Enemy driven by a small state machine:
## idle -> chase -> (retreat) -> windup -> recover -> chase.
## A knockback interrupts any action (stagger); a pit makes it fall like the player.
## All numbers come from EnemyData, so skeleton, archer and beetle share this script.
## Attacks use the same Weapon system as the player, with a weapon scene that targets
## the player_hurtbox layer. On a Level the enemy walks along a grid path (AStarGrid2D)
## that avoids walls, pits and spikes; without a Level it walks straight.

## Emitted once when the enemy dies, just before it is removed.
signal defeated(enemy: Enemy)

enum State { IDLE, CHASE, RETREAT, WINDUP, RECOVER, STAGGER, FALLING }

@export var data: EnemyData
@export var health: Health
@export var hurtbox: Hurtbox
## Visual node tinted during the windup and on hits. A Sprite2D gets data.sprite.
@export var visual: CanvasItem
## Optional: makes the enemy react to spikes and pits.
@export var hazards: HazardReceiver
## Optional: collision shapes resized from data.body_radius.
@export var body_shape: CollisionShape2D
@export var hurtbox_shape: CollisionShape2D
## Physics layers that block the enemy's sight (world).
@export_flags_2d_physics var sight_mask: int = 1
## Tint during the windup, so the player sees the attack coming.
@export var windup_color: Color = Color(1.0, 0.45, 0.2)
@export var hit_color: Color = Color(1.0, 0.3, 0.3)
## Seconds for the hit tint to fade.
@export var hit_flash_duration: float = 0.12
## Below this speed (pixels per second) a knocked-back enemy recovers from the stagger.
@export var stagger_end_speed: float = 10.0
## A path waypoint closer than this counts as reached, in pixels.
@export var waypoint_reach: float = 4.0
## Tint of a dormant enemy: a sleeping boss looks like stone.
@export var dormant_color: Color = Color(0.55, 0.58, 0.68)
## Drawing offset of animated 24x24 art, so the feet stand on the body's origin.
@export var animated_offset: Vector2 = Vector2(0, -4)

var state: State = State.IDLE
## A dormant enemy stands still, does not notice the player and takes no damage until
## awaken(): the boss sleeps in the middle of its arena until the doors seal, so it
## cannot be lured out of the room or worn down from the doorway.
var is_dormant: bool = false
var weapon: Weapon = null
## Set by the game before the enemy enters the tree: deeper ruins, tougher enemies.
var hp_multiplier: float = 1.0
var damage_multiplier: float = 1.0

var _target: Node2D = null
var _level: Level = null
var _state_time_left: float = 0.0
var _retreat_cooldown_left: float = 0.0
## Fixed at the start of the windup, so the player can dodge the telegraphed hit.
var _attack_direction: Vector2 = Vector2.RIGHT
var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _repath_time_left: float = 0.0
var _flash_tween: Tween = null


func _ready() -> void:
	# Top-down game: no floor or gravity, every collision is treated as a wall.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	if data == null:
		push_error("Enemy %s has no EnemyData" % get_path())
		set_physics_process(false)
		return
	_level = get_tree().get_first_node_in_group(Level.GROUP) as Level
	health.max_hp = maxi(1, roundi(data.max_hp * hp_multiplier))
	health.reset()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)
	if hazards != null:
		hazards.fall_started.connect(_on_fall_started)
		hazards.fall_ended.connect(_on_fall_ended)
	_apply_look()
	_create_weapon()
	if is_dormant:
		_fall_asleep()


func _physics_process(delta: float) -> void:
	if is_dormant:
		return
	_retreat_cooldown_left = maxf(_retreat_cooldown_left - delta, 0.0)
	match state:
		State.IDLE:
			_update_idle()
		State.CHASE:
			_update_chase(delta)
		State.RETREAT:
			_update_retreat(delta)
		State.WINDUP:
			_update_windup(delta)
		State.RECOVER:
			_update_recover(delta)
		State.STAGGER:
			_update_stagger(delta)
		State.FALLING:
			return
	move_and_slide()


## How far the attack being wound up reaches; the bot dodges when it is closer.
## A boss with several attacks answers for the current one.
func get_windup_reach() -> float:
	return data.attack_range


## True if the attack being wound up flies along a line (step across it, not back).
func is_windup_ranged() -> bool:
	return data.preferred_distance > 0.0


## Puts the enemy to sleep until awaken(); works before and after it enters the tree.
func make_dormant() -> void:
	is_dormant = true
	if is_inside_tree():
		_fall_asleep()


## Wakes a dormant enemy: it can be hurt again and goes straight for the player.
func awaken() -> void:
	if not is_dormant:
		return
	is_dormant = false
	health.end_invulnerability()
	_target = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
	_enter(State.CHASE if _target != null else State.IDLE)


func _fall_asleep() -> void:
	if weapon != null:
		weapon.cancel_attack()
	_enter(State.IDLE)
	# Only Health makes anything invulnerable; this lasts until awaken().
	health.make_invulnerable(INF)
	visual.modulate = dormant_color


## Pushes the enemy with the given velocity and interrupts what it was doing.
## Called for hits with knockback and by the player's shield.
func apply_knockback(knockback_velocity: Vector2) -> void:
	if state == State.FALLING:
		return
	if weapon != null:
		weapon.cancel_attack()
	_enter(State.STAGGER)
	velocity = knockback_velocity


func _update_idle() -> void:
	_target = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
	if _target != null and global_position.distance_to(_target.global_position) <= data.detection_range:
		_enter(State.CHASE)


func _update_chase(delta: float) -> void:
	if not is_instance_valid(_target):
		_enter(State.IDLE)
		return
	var distance: float = global_position.distance_to(_target.global_position)
	if data.preferred_distance > 0.0 and distance < data.preferred_distance and _retreat_cooldown_left <= 0.0:
		_enter(State.RETREAT)
		return
	if distance <= data.attack_range and _can_see_target():
		_enter(State.WINDUP)
		return
	velocity = _direction_to_target(delta) * data.move_speed


## A short step away from the player (ranged enemies). Ends on time, at the preferred
## distance, or when the way back is blocked; then the enemy shoots if it can.
func _update_retreat(delta: float) -> void:
	if not is_instance_valid(_target):
		_enter(State.IDLE)
		return
	_state_time_left -= delta
	var away: Vector2 = _target.global_position.direction_to(global_position)
	var distance: float = global_position.distance_to(_target.global_position)
	if _state_time_left <= 0.0 or distance >= data.preferred_distance or not _can_step(away):
		_retreat_cooldown_left = data.retreat_cooldown
		_enter(State.WINDUP if distance <= data.attack_range and _can_see_target() else State.CHASE)
		return
	velocity = away * data.move_speed


func _update_windup(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left > 0.0:
		return
	if weapon != null:
		weapon.try_attack(_attack_direction)
		weapon.release_attack(_attack_direction)
	_enter(State.RECOVER)


func _update_recover(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter(State.CHASE)


func _update_stagger(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, data.knockback_friction * delta)
	if velocity.length() <= stagger_end_speed:
		_enter(State.CHASE)


func _enter(new_state: State) -> void:
	state = new_state
	velocity = Vector2.ZERO
	visual.modulate = Color.WHITE
	match new_state:
		State.CHASE:
			# Ask for a fresh path at once.
			_repath_time_left = 0.0
			if not is_instance_valid(_target):
				_target = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
		State.RETREAT:
			_state_time_left = data.retreat_time
		State.WINDUP:
			_state_time_left = data.windup
			_attack_direction = global_position.direction_to(_target.global_position)
			visual.modulate = windup_color
		State.RECOVER:
			_state_time_left = data.recovery


## Unit direction of the next step towards the target: along the grid path on a Level,
## straight otherwise. Zero when there is no way.
func _direction_to_target(delta: float) -> Vector2:
	var straight: Vector2 = global_position.direction_to(_target.global_position)
	if not is_instance_valid(_level):
		return straight
	_repath_time_left -= delta
	if _repath_time_left <= 0.0:
		_repath_time_left = data.repath_interval
		_path = _level.find_path(global_position, _target.global_position)
		# Point 0 is the cell the enemy already stands on.
		_path_index = 1
	while _path_index < _path.size() and global_position.distance_to(_path[_path_index]) <= waypoint_reach:
		_path_index += 1
	if _path_index < _path.size():
		return global_position.direction_to(_path[_path_index])
	# Path finished (the target is in this cell or the next one) or there is none:
	# go straight only over safe ground.
	return straight if _can_step(straight) else Vector2.ZERO


## True if one tile ahead in this direction is plain floor (or there is no Level).
func _can_step(direction: Vector2) -> bool:
	if not is_instance_valid(_level):
		return not is_on_wall()
	var ahead: Vector2 = global_position + direction * float(_level.theme.tile_size)
	return _level.cell_type_at(ahead) == LevelGrid.Cell.FLOOR


func _can_see_target() -> bool:
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			global_position, _target.global_position, sight_mask)
	return get_world_2d().direct_space_state.intersect_ray(ray).is_empty()


## Picture and body size come from the data, so one scene serves every enemy type.
func _apply_look() -> void:
	var sprite: Sprite2D = visual as Sprite2D
	if sprite != null:
		if data.sprite != null:
			sprite.texture = data.sprite
		sprite.scale = Vector2.ONE * data.sprite_scale
	var animated: AnimatedSprite2D = visual as AnimatedSprite2D
	if animated != null:
		if data.sprite_frames != null:
			animated.sprite_frames = data.sprite_frames
			animated.offset = animated_offset
		elif data.sprite != null:
			# No animations yet: the old still picture as a one-frame placeholder.
			var still: SpriteFrames = SpriteFrames.new()
			still.add_frame(&"default", data.sprite)
			animated.sprite_frames = still
			animated.offset = Vector2.ZERO
			animated.scale = Vector2.ONE * data.sprite_scale
		animated.play(animated.sprite_frames.get_animation_names()[0] if animated.sprite_frames != null else &"default")
	# New shape objects: the ones in the scene file are shared by all instances.
	if body_shape != null:
		var body_circle: CircleShape2D = CircleShape2D.new()
		body_circle.radius = data.body_radius
		body_shape.shape = body_circle
	if hurtbox_shape != null:
		var hurtbox_circle: CircleShape2D = CircleShape2D.new()
		hurtbox_circle.radius = data.body_radius + 1.0
		hurtbox_shape.shape = hurtbox_circle


func _create_weapon() -> void:
	if data.weapon == null or data.weapon.weapon_scene == null:
		push_error("Enemy %s has no weapon with a weapon_scene" % data.id)
		return
	weapon = data.weapon.weapon_scene.instantiate() as Weapon
	# Damage from this weapon is reported with the enemy type as its source.
	weapon.setup(data.weapon, self, data.id)
	weapon.damage_multiplier = damage_multiplier
	add_child(weapon)


func _on_hit_received(info: DamageInfo) -> void:
	if not info.knockback.is_zero_approx():
		apply_knockback(info.knockback)
	elif state == State.IDLE:
		# Hit from afar (an arrow): start chasing even outside the detection range.
		_target = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
		if _target != null:
			_enter(State.CHASE)


func _on_damaged(_info: DamageInfo) -> void:
	if _flash_tween != null:
		_flash_tween.kill()
	# self_modulate, so the hit flash does not fight the windup tint in modulate.
	visual.self_modulate = hit_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual, "self_modulate", Color.WHITE, hit_flash_duration)


func _on_died(_info: DamageInfo) -> void:
	set_physics_process(false)
	defeated.emit(self)
	queue_free()


func _on_fall_started() -> void:
	if weapon != null:
		weapon.cancel_attack()
	_enter(State.FALLING)


func _on_fall_ended() -> void:
	_enter(State.CHASE)
