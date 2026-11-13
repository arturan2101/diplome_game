class_name Guardian
extends Enemy
## The boss, Guardian of the Ruins (numbers in GuardianData).
## Phase 1: walks slowly; a heavy slam (its weapon) when the player is close, a thrown
## stone when the player keeps away.
## Phase 2 (below half HP): roars for a moment, calls servants and keeps calling them
## while few are left, moves and recovers faster, and every second close attack is a
## shockwave around itself.
## Every attack is drawn on the ground while it winds up (the slam's arc, the stone's
## line, the shockwave's circle) and fills up until the hit. Knockback does not move
## the Guardian and it does not fall into pits.

signal phase_changed(phase: int)
## The game spawns the servants: it owns the enemies of the section.
signal summon_requested(guardian: Guardian, count: int)

enum Attack { SLAM, THROW, SHOCKWAVE }

## Physics layers the stone and the shockwave hurt (player_hurtbox).
@export_flags_2d_physics var player_hurtbox_mask: int = 8
## Look of the telegraphs.
@export var telegraph_color: Color = Color(1.0, 0.2, 0.15)
@export var telegraph_alpha: float = 0.45
@export var telegraph_segments: int = 24
@export var stone_line_width: float = 3.0

var phase: int = 1
## The attack being wound up (or the last one).
var attack: Attack = Attack.SLAM

var _stats: GuardianData = null
var _windup_total: float = 0.0
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
		queue_redraw()
		return
	super(delta)
	if state == State.WINDUP:
		queue_redraw()


func get_windup_reach() -> float:
	match attack:
		Attack.THROW:
			return _stats.throw_range
		Attack.SHOCKWAVE:
			return _stats.shockwave_radius
	return data.attack_range


func is_windup_ranged() -> bool:
	return attack == Attack.THROW


## Share of the current windup already done, 0-1 (the telegraph fills up with it).
func get_windup_progress() -> float:
	if state != State.WINDUP or _windup_total <= 0.0:
		return 0.0
	return clampf(1.0 - _state_time_left / _windup_total, 0.0, 1.0)


func is_roaring() -> bool:
	return _roar_left > 0.0


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
	queue_redraw()


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
	_enter(State.RECOVER)
	if phase == 2:
		_state_time_left *= _stats.phase_two_recovery_multiplier
	queue_redraw()


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
	queue_redraw()


func _draw() -> void:
	if _roar_left > 0.0:
		var t: float = 1.0 - _roar_left / _stats.roar_time
		draw_arc(Vector2.ZERO, data.body_radius + 4.0 + 24.0 * t, 0.0, TAU, telegraph_segments,
				Color(telegraph_color, 0.7 * (1.0 - t)), 2.0)
		return
	if state != State.WINDUP:
		return
	var progress: float = get_windup_progress()
	var fill: Color = Color(telegraph_color, telegraph_alpha * (0.3 + 0.7 * progress))
	var edge: Color = Color(telegraph_color, 0.9)
	match attack:
		Attack.SLAM:
			var stats: MeleeWeaponData = data.weapon as MeleeWeaponData
			if stats != null and not stats.combo.is_empty():
				var step: MeleeAttackStep = stats.combo[0]
				_draw_sector(step.reach, step.arc_degrees, edge, false)
				_draw_sector(step.reach * progress, step.arc_degrees, fill, true)
		Attack.THROW:
			draw_line(Vector2.ZERO, _attack_direction * _stats.throw_range, fill, stone_line_width)
		Attack.SHOCKWAVE:
			draw_circle(Vector2.ZERO, _stats.shockwave_radius * progress, fill)
			draw_arc(Vector2.ZERO, _stats.shockwave_radius, 0.0, TAU, telegraph_segments * 2, edge, 1.5)


## The slam's area: a sector around the attack direction, filled or as an outline.
func _draw_sector(radius: float, arc_degrees: float, color: Color, filled: bool) -> void:
	var half: float = deg_to_rad(arc_degrees) * 0.5
	var start: float = _attack_direction.angle() - half
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i in telegraph_segments + 1:
		points.append(Vector2.from_angle(start + 2.0 * half * i / telegraph_segments) * radius)
	if filled:
		if radius > 0.0:
			draw_colored_polygon(points, color)
	else:
		points.append(Vector2.ZERO)
		draw_polyline(points, color, 1.5)
