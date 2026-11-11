class_name Enemy
extends CharacterBody2D
## Enemy driven by a small state machine: idle -> chase -> windup -> recover -> chase.
## A knockback interrupts any action (stagger). All numbers come from EnemyData.
## Attacks use the same Weapon system as the player, with a weapon scene that targets
## the player_hurtbox layer. For now it moves straight at the player; grid pathfinding
## (AStarGrid2D) comes with tunnel generation.

enum State { IDLE, CHASE, WINDUP, RECOVER, STAGGER }

@export var data: EnemyData
@export var health: Health
@export var hurtbox: Hurtbox
## Visual node tinted during the windup and on hits (the PlaceholderShape for now).
@export var visual: CanvasItem
## Tint during the windup, so the player sees the attack coming.
@export var windup_color: Color = Color(1.0, 0.45, 0.2)
@export var hit_color: Color = Color(1.0, 0.3, 0.3)
## Seconds for the hit tint to fade.
@export var hit_flash_duration: float = 0.12
## Below this speed (pixels per second) a knocked-back enemy recovers from the stagger.
@export var stagger_end_speed: float = 10.0

var state: State = State.IDLE
var weapon: Weapon = null

var _target: Node2D = null
var _state_time_left: float = 0.0
## Fixed at the start of the windup, so the player can dodge the telegraphed hit.
var _attack_direction: Vector2 = Vector2.RIGHT
var _flash_tween: Tween = null


func _ready() -> void:
	# Top-down game: no floor or gravity, every collision is treated as a wall.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	health.max_hp = data.max_hp
	health.reset()
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)
	_create_weapon()


func _physics_process(delta: float) -> void:
	match state:
		State.IDLE:
			_update_idle()
		State.CHASE:
			_update_chase()
		State.WINDUP:
			_update_windup(delta)
		State.RECOVER:
			_update_recover(delta)
		State.STAGGER:
			_update_stagger(delta)
	move_and_slide()


func _update_idle() -> void:
	_target = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
	if _target != null and global_position.distance_to(_target.global_position) <= data.detection_range:
		_enter(State.CHASE)


func _update_chase() -> void:
	if not is_instance_valid(_target):
		_enter(State.IDLE)
		return
	var to_target: Vector2 = _target.global_position - global_position
	if to_target.length() <= data.attack_range:
		_enter(State.WINDUP)
		return
	velocity = to_target.normalized() * data.move_speed


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
		State.WINDUP:
			_state_time_left = data.windup
			_attack_direction = global_position.direction_to(_target.global_position)
			visual.modulate = windup_color
		State.RECOVER:
			_state_time_left = data.recovery


func _create_weapon() -> void:
	if data.weapon == null or data.weapon.weapon_scene == null:
		push_error("Enemy %s has no weapon with a weapon_scene" % data.id)
		return
	weapon = data.weapon.weapon_scene.instantiate() as Weapon
	# Damage from this weapon is reported with the enemy type as its source.
	weapon.setup(data.weapon, self, data.id)
	add_child(weapon)


func _on_hit_received(info: DamageInfo) -> void:
	if not info.knockback.is_zero_approx():
		if weapon != null:
			weapon.cancel_attack()
		_enter(State.STAGGER)
		velocity = info.knockback
	elif state == State.IDLE:
		# Hit from afar (an arrow): start chasing even outside the detection range.
		_target = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
		if _target != null:
			_enter(State.CHASE)


func _on_damaged(info: DamageInfo) -> void:
	print("%s: %d damage from %s, hp %d/%d" % [name, info.amount, info.source_id, health.hp, health.max_hp])
	if _flash_tween != null:
		_flash_tween.kill()
	# self_modulate, so the hit flash does not fight the windup tint in modulate.
	visual.self_modulate = hit_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual, "self_modulate", Color.WHITE, hit_flash_duration)


func _on_died(info: DamageInfo) -> void:
	print("%s: defeated by %s" % [name, info.source_id])
	set_physics_process(false)
	queue_free()
