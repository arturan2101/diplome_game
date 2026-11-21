class_name Guardian
extends Enemy
## The boss (numbers in GuardianData). Since stage 41 it looks like the Ruins Warden, a
## living marble statue; the class and the log id stay "guardian".
## Phase 1: walks slowly; a heavy slam (its weapon) when the player is close, a thrown
## stone when the player keeps away.
## Phase 2 (below half HP): roars for a moment, calls servants and keeps calling them
## while few are left, moves and recovers faster, and every second close attack is a
## shockwave around itself.
## Every attack has its own wind-up pose in the art (slam: shield and fist overhead;
## throw: a boulder cocked behind the head; shockwave: arms wide, knee up), so nothing
## is drawn on the ground. Knockback does not move the Guardian and it does not fall
## into pits.

signal phase_changed(phase: int)
## The game spawns the servants: it owns the enemies of the section.
signal summon_requested(guardian: Guardian, count: int)

enum Attack { SLAM, THROW, SHOCKWAVE }

## Physics layers the stone and the shockwave hurt (player_hurtbox).
@export_flags_2d_physics var player_hurtbox_mask: int = 8
## Animation of each attack ("<name>_<dir>" in the art).
@export var attack_animations: Dictionary = {Attack.SLAM: "slam", Attack.THROW: "throw", Attack.SHOCKWAVE: "wave"}

var phase: int = 1
## The attack being wound up (or the last one).
var attack: Attack = Attack.SLAM

var _stats: GuardianData = null
var _roar_left: float = 0.0
var _summon_left: float = 0.0
var _throw_cooldown_left: float = 0.0
var _shockwave_next: bool = false


func _ready() -> void:
	super()
	_stats = data as GuardianData
	if _stats == null:
		push_error("Guardian needs GuardianData: %s" % data)
		set_physics_process(false)
		return
	# A boss does not fall into pits or bleed on spikes.
	if hazards != null:
		hazards.process_mode = Node.PROCESS_MODE_DISABLED
	health.damaged.connect(_check_phase)


func _physics_process(delta: float) -> void:
	if is_dormant:
		return
	_throw_cooldown_left = maxf(_throw_cooldown_left - delta, 0.0)
	if phase == 2:
		_summon_left -= delta
		if _summon_left <= 0.0:
			_summon_left = _stats.summon_interval
			summon_requested.emit(self, _stats.summon_count)
	if _roar_left > 0.0:
		_roar_left -= delta
		velocity = Vector2.ZERO
		return
	super(delta)


func get_windup_reach() -> float:
	match attack:
		Attack.THROW:
			return _stats.throw_range
		Attack.SHOCKWAVE:
			return _stats.shockwave_radius
	return data.attack_range


func is_windup_ranged() -> bool:
	return attack == Attack.THROW


func is_roaring() -> bool:
	return _roar_left > 0.0


## Seconds it stands and roars going into the second phase.
func get_roar_time() -> float:
	return _stats.roar_time if _stats != null else 0.0


func get_attack_animation() -> String:
	return String(attack_animations.get(attack, "attack"))


## A boss stands its ground: hits and the shield do not push or stagger it.
func apply_knockback(_knockback_velocity: Vector2) -> void:
	pass


func _update_chase(delta: float) -> void:
	if not is_instance_valid(_target):
		super(delta)
		return
	var distance: float = global_position.distance_to(_target.global_position)
	if _can_see_target():
		if phase == 2 and _shockwave_next and distance <= _stats.shockwave_radius:
			_start_attack(Attack.SHOCKWAVE)
			return
		if distance <= data.attack_range:
			_start_attack(Attack.SLAM)
			return
		if distance >= _stats.throw_min_distance and distance <= _stats.throw_range and _throw_cooldown_left <= 0.0:
			_start_attack(Attack.THROW)
			return
	super(delta)
	if phase == 2:
		velocity *= _stats.phase_two_speed_multiplier


func _start_attack(kind: Attack) -> void:
	attack = kind
	_enter(State.WINDUP)
	match kind:
		Attack.THROW:
			_state_time_left = _stats.throw_windup
		Attack.SHOCKWAVE:
			_state_time_left = _stats.shockwave_windup
	_windup_total = _state_time_left


func _update_windup(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left > 0.0:
		return
	match attack:
		Attack.SLAM:
			if weapon != null:
				weapon.try_attack(_attack_direction)
				weapon.release_attack(_attack_direction)
			_shockwave_next = phase == 2
		Attack.THROW:
			_throw()
			_throw_cooldown_left = _stats.throw_cooldown
		Attack.SHOCKWAVE:
			AreaDamage.hit(get_world_2d().direct_space_state, global_position, _stats.shockwave_radius,
					roundi(_stats.shockwave_damage * damage_multiplier), self, data.id, _stats.shockwave_knockback,
					player_hurtbox_mask, sight_mask)
			_shockwave_next = false
	struck.emit()
	_enter(State.RECOVER)
	if phase == 2:
		_state_time_left *= _stats.phase_two_recovery_multiplier


func _throw() -> void:
	if _stats.projectile_scene == null:
		return
	var stone: Arrow = _stats.projectile_scene.instantiate() as Arrow
	var info: DamageInfo = DamageInfo.new(roundi(_stats.throw_damage * damage_multiplier), self, data.id)
	stone.setup(info, _attack_direction, _stats.throw_speed, _stats.throw_range)
	# Next to the Guardian in the section, so the stone is cleared with it.
	get_parent().add_child(stone)
	stone.global_position = global_position


func _check_phase(_info: DamageInfo) -> void:
	if phase == 1 and not health.is_dead() and health.hp <= roundi(health.max_hp * _stats.phase_two_at):
		_enter_phase_two()


func _enter_phase_two() -> void:
	phase = 2
	if weapon != null:
		weapon.cancel_attack()
	_enter(State.CHASE)
	_roar_left = _stats.roar_time
	_summon_left = _stats.summon_interval
	_shockwave_next = true
	phase_changed.emit(phase)
	summon_requested.emit(self, _stats.summon_count)

