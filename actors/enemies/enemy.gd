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
## Emitted when a wound-up attack lands (not when the windup is cut short). The look
## plays the blow then.
signal struck

enum State { IDLE, CHASE, RETREAT, WINDUP, RECOVER, STAGGER, FALLING }

## Search depth from a hurtbox up to the enemy that owns it (owner_of()).
const OWNER_SEARCH_DEPTH: int = 4

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
## Tint during the windup. White (none) since stage 41: the wind-up pose of the art
## shows the attack coming; a colour brings the old orange warning back.
@export var windup_color: Color = Color.WHITE
## A hit flashes the enemy white (values above 1 brighten the sprite).
@export var hit_color: Color = Color(3.0, 3.0, 3.0)
## Seconds for the hit tint to fade.
@export var hit_flash_duration: float = 0.12
## Below this speed (pixels per second) a knocked-back enemy recovers from the stagger.
@export var stagger_end_speed: float = 10.0
## A path waypoint closer than this counts as reached, in pixels.
@export var waypoint_reach: float = 4.0
## Tint of a dormant enemy: a sleeping boss looks like stone.
@export var dormant_color: Color = Color(0.55, 0.58, 0.68)
## Tint of an enemy frozen by the water's ice form.
@export var frozen_color: Color = Color(0.55, 0.8, 1.0)
## Statuses of the elements (stage 40): drops falling from a wet enemy (an animation of
## status_frames over its head) and ice crust over a frozen one (feet on the bottom row).
@export var status_frames: SpriteFrames = preload("res://assets/art/fx/element2_frames.tres")
@export var wet_animation: StringName = &"wet_drops"
@export var wet_mark_height: float = 14.0
@export var frozen_mark: Texture2D = preload("res://assets/art/fx/frozen_mark.png")
## Tint of an enemy stunned by the player's parry.
@export var stunned_color: Color = Color(1.0, 0.95, 0.6)
## Animated art has the feet on the second-to-last row of its square frame; it is
## drawn so the feet sit this many pixels below the body's centre.
@export var feet_below_centre: float = 6.0

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
## Length of the current windup (bosses set their own), for get_windup_progress().
var _windup_total: float = 0.0
var _retreat_cooldown_left: float = 0.0
## Fixed at the start of the windup, so the player can dodge the telegraphed hit.
var _attack_direction: Vector2 = Vector2.RIGHT
var _path: PackedVector2Array = PackedVector2Array()
var _path_index: int = 0
var _repath_time_left: float = 0.0
var _flash_tween: Tween = null
## Seconds left in the ice (freeze()).
var _frozen_left: float = 0.0
## Seconds the stagger lasts at least (a parry's stun, stun()).
var _stun_left: float = 0.0
## Element statuses (stage 40): seconds left wet (lightning hurts more), rooted (vines:
## no walking, attacks still come), slowed (sandstorm: walking at _slow_multiplier).
var _wet_left: float = 0.0
var _root_left: float = 0.0
var _slow_left: float = 0.0
var _slow_multiplier: float = 1.0
## Drops shown while wet and ice shown while frozen, created when first needed.
var _wet_mark: AnimatedSprite2D = null
var _ice_mark: Sprite2D = null


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
	_update_statuses(delta)
	if is_frozen():
		_frozen_left -= delta
		if not is_frozen():
			_thaw()
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


## True if the attack being wound up hits a whole circle around the enemy (the golem's
## slam): step out and stay out until it lands.
func is_windup_area() -> bool:
	return false


## Seconds until the attack being wound up lands; 0 when not winding up.
func get_windup_time_left() -> float:
	return maxf(_state_time_left, 0.0) if state == State.WINDUP else 0.0


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


## Holds the enemy in ice for this many seconds (the water's ice form): it does not move,
## attack or get pushed, and its animation stops. Freezing again extends the time to
## the longer one. Bosses, sleeping and falling enemies do not freeze.
func freeze(seconds: float) -> void:
	if seconds <= 0.0 or data == null or data.is_boss or is_dormant or state == State.FALLING:
		return
	if not is_frozen():
		if weapon != null:
			weapon.cancel_attack()
		_enter(State.IDLE)
		visual.modulate = frozen_color
		_show_ice(true)
		var animated: AnimatedSprite2D = visual as AnimatedSprite2D
		if animated != null:
			animated.speed_scale = 0.0
	_frozen_left = maxf(_frozen_left, seconds)


func is_frozen() -> bool:
	return _frozen_left > 0.0


func _thaw() -> void:
	_frozen_left = 0.0
	_show_ice(false)
	var animated: AnimatedSprite2D = visual as AnimatedSprite2D
	if animated != null:
		animated.speed_scale = 1.0
	_enter(State.CHASE)


## Pushes the enemy with the given velocity and interrupts what it was doing.
## Called for hits with knockback and by the player's shield. A frozen enemy stays put.
func apply_knockback(knockback_velocity: Vector2) -> void:
	if state == State.FALLING or is_frozen():
		return
	if weapon != null:
		weapon.cancel_attack()
	_enter(State.STAGGER)
	velocity = knockback_velocity


## Stunned by a parry: the attack is lost and the enemy reels back and stands dazed for
## at least this many seconds. Bosses, stagger-immune enemies (the golem) and frozen,
## sleeping or falling ones are not stunned.
func stun(seconds: float, push: Vector2 = Vector2.ZERO) -> void:
	if data == null or data.is_boss or is_dormant:
		return
	apply_knockback(push)
	if state != State.STAGGER:
		return
	_stun_left = maxf(_stun_left, seconds)
	visual.modulate = stunned_color


func is_stunned() -> bool:
	return state == State.STAGGER and _stun_left > 0.0


## Wet for this many seconds (the water's wave): lightning hurts it more. Again: the
## longer time wins.
func make_wet(seconds: float) -> void:
	if seconds <= 0.0 or data == null:
		return
	_wet_left = maxf(_wet_left, seconds)
	_show_wet(true)


func is_wet() -> bool:
	return _wet_left > 0.0


## Held in place for this many seconds (the vines): it cannot walk, but still turns and
## attacks whatever comes into reach. Bosses are not rooted.
func root(seconds: float) -> void:
	if seconds <= 0.0 or data == null or data.is_boss:
		return
	_root_left = maxf(_root_left, seconds)


func is_rooted() -> bool:
	return _root_left > 0.0


## Walks at multiplier of its speed for this many seconds (the sandstorm). The stronger
## slow wins while both last.
func slow(multiplier: float, seconds: float) -> void:
	if seconds <= 0.0 or data == null:
		return
	if _slow_left <= 0.0 or multiplier < _slow_multiplier:
		_slow_multiplier = clampf(multiplier, 0.0, 1.0)
	_slow_left = maxf(_slow_left, seconds)


func is_slowed() -> bool:
	return _slow_left > 0.0


## Speed of walking now: the data's speed, slowed or stopped by statuses.
func get_walk_speed() -> float:
	if is_rooted():
		return 0.0
	return data.move_speed * (_slow_multiplier if is_slowed() else 1.0)


func _update_statuses(delta: float) -> void:
	if _wet_left > 0.0:
		_wet_left = maxf(_wet_left - delta, 0.0)
		if _wet_left <= 0.0:
			_show_wet(false)
	_root_left = maxf(_root_left - delta, 0.0)
	_slow_left = maxf(_slow_left - delta, 0.0)


func _show_wet(wet: bool) -> void:
	if _wet_mark == null:
		if not wet or status_frames == null or not status_frames.has_animation(wet_animation):
			return
		_wet_mark = AnimatedSprite2D.new()
		_wet_mark.name = "WetDrops"
		_wet_mark.sprite_frames = status_frames
		_wet_mark.position = Vector2(0.0, -wet_mark_height)
		add_child(_wet_mark)
	_wet_mark.visible = wet
	if wet:
		_wet_mark.play(wet_animation)
	else:
		_wet_mark.stop()


func _show_ice(frozen: bool) -> void:
	if _ice_mark == null:
		if not frozen or frozen_mark == null:
			return
		_ice_mark = Sprite2D.new()
		_ice_mark.name = "IceCrust"
		_ice_mark.texture = frozen_mark
		_ice_mark.position = Vector2(0.0, feet_below_centre - frozen_mark.get_height() * 0.5 + 1.0)
		add_child(_ice_mark)
	_ice_mark.visible = frozen


## The enemy a hurtbox belongs to (a spell effect hits hurtboxes), or null.
static func owner_of(hurtbox: Node) -> Enemy:
	var node: Node = hurtbox
	for _i in OWNER_SEARCH_DEPTH:
		if node == null or node is Enemy:
			break
		node = node.get_parent()
	return node as Enemy


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
	velocity = _direction_to_target(delta) * get_walk_speed()


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
	velocity = away * get_walk_speed()


func _update_windup(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left > 0.0:
		return
	if weapon != null:
		weapon.try_attack(_attack_direction)
		weapon.release_attack(_attack_direction)
	struck.emit()
	_enter(State.RECOVER)


## Share of the current windup already done, 0-1 (0 when not winding up).
func get_windup_progress() -> float:
	if state != State.WINDUP or _windup_total <= 0.0:
		return 0.0
	return clampf(1.0 - _state_time_left / _windup_total, 0.0, 1.0)


## Name of the animation of the attack being wound up ("<name>_<dir>"); the boss has
## one per attack.
func get_attack_animation() -> String:
	return "attack"


func _update_recover(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left <= 0.0:
		_enter(State.CHASE)


func _update_stagger(delta: float) -> void:
	velocity = velocity.move_toward(Vector2.ZERO, data.knockback_friction * delta)
	_stun_left = maxf(_stun_left - delta, 0.0)
	if velocity.length() <= stagger_end_speed and _stun_left <= 0.0:
		_enter(State.CHASE)


func _enter(new_state: State) -> void:
	state = new_state
	# A stun lasts only through its own stagger (another push keeps it).
	if new_state != State.STAGGER:
		_stun_left = 0.0
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
			_windup_total = data.windup
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
			# Drawn at its own size (sprite_scale is for the old still pictures).
			animated.scale = Vector2.ONE
			var frame_height: float = float(_frame_height(data.sprite_frames))
			var feet: float = float(data.feet_row) if data.feet_row >= 0 else frame_height - 2.0
			animated.offset = Vector2(0.0, feet_below_centre * data.body_radius / 6.0 - (feet - frame_height * 0.5))
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


static func _frame_height(frames: SpriteFrames) -> int:
	for anim: StringName in frames.get_animation_names():
		if frames.get_frame_count(anim) > 0:
			return frames.get_frame_texture(anim, 0).get_height()
	return 0


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
