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
## Stage 45: the same class plays the elemental Wardens of the flooded and fire floors
## (GuardianData decides): the thrown projectile may leave a patch, the slam lava cracks,
## the shockwave a ring that slows; and a special attack drops strikes on the floor
## after a warning (geysers in a line, meteors on and around the player).
## Stage 48: the Mycelium Mother of the fungal floors too: no throw, a spore burst all
## round that leaves a cloud, roots bursting from the floor in a line, a spore ring.

signal phase_changed(phase: int)
## The game spawns the servants: it owns the enemies of the section.
signal summon_requested(guardian: Guardian, count: int)

enum Attack { SLAM, THROW, SHOCKWAVE, SPECIAL }

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
var _special_cooldown_left: float = 0.0
## The patches with damage_multiplier applied, made on first use.
var _scaled_zones: Dictionary = {}


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
	# The first special attack waits half its cooldown after the boss wakes.
	_special_cooldown_left = _stats.special_cooldown * 0.5


func _physics_process(delta: float) -> void:
	if is_dormant:
		return
	_throw_cooldown_left = maxf(_throw_cooldown_left - delta, 0.0)
	_special_cooldown_left = maxf(_special_cooldown_left - delta, 0.0)
	if phase == 2:
		_summon_left -= delta
		if _summon_left <= 0.0:
			_summon_left = _stats.summon_interval
			Sound.play_at(_stats.summon_sound, global_position)
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
		Attack.SPECIAL:
			return _stats.special_range
	return data.attack_range


func is_windup_ranged() -> bool:
	return attack == Attack.THROW or attack == Attack.SPECIAL


## True when this boss has a special attack (the elemental Wardens).
func has_special() -> bool:
	return _stats != null and _stats.special_zone != null


func is_roaring() -> bool:
	return _roar_left > 0.0


## Seconds it stands and roars going into the second phase.
func get_roar_time() -> float:
	return _stats.roar_time if _stats != null else 0.0


func get_attack_sound() -> StringName:
	match attack:
		Attack.THROW:
			return _stats.throw_sound
		Attack.SHOCKWAVE:
			return _stats.shockwave_sound
		Attack.SPECIAL:
			return _stats.special_sound
	return data.attack_sound


func get_attack_animation() -> String:
	if attack == Attack.SPECIAL and _stats.special_animation != "":
		return _stats.special_animation
	if attack == Attack.SLAM and _stats.slam_animation != "":
		return _stats.slam_animation
	if attack == Attack.SHOCKWAVE and _stats.wave_animation != "":
		return _stats.wave_animation
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
		if has_special() and _special_cooldown_left <= 0.0 and distance >= _stats.special_min_distance 				and distance <= _stats.special_range:
			_start_attack(Attack.SPECIAL)
			return
		if _stats.projectile_scene != null and distance >= _stats.throw_min_distance and distance <= _stats.throw_range \
				and _throw_cooldown_left <= 0.0:
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
		Attack.SPECIAL:
			_state_time_left = _stats.special_windup
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
			if _stats.slam_zone != null:
				_spawn_zone(_stats.slam_zone, global_position + _attack_direction * _stats.slam_zone_distance)
		Attack.THROW:
			_throw()
			_throw_cooldown_left = _stats.throw_cooldown
		Attack.SHOCKWAVE:
			var on_hit: Callable = _slow_player if _stats.shockwave_slow_time > 0.0 else Callable()
			AreaDamage.hit(get_world_2d().direct_space_state, global_position, _stats.shockwave_radius,
					roundi(_stats.shockwave_damage * damage_multiplier), self, data.id, _stats.shockwave_knockback,
					player_hurtbox_mask, sight_mask, on_hit)
			_show_ring()
			_shockwave_next = false
		Attack.SPECIAL:
			_special()
			_special_cooldown_left = _stats.special_cooldown
	struck.emit()
	_enter(State.RECOVER)
	if phase == 2:
		_state_time_left *= _stats.phase_two_recovery_multiplier


func _throw() -> void:
	if _stats.projectile_scene == null:
		return
	var stone: Arrow = _stats.projectile_scene.instantiate() as Arrow
	stone.land_sound = _stats.throw_land_sound
	stone.wall_sound = &""
	var info: DamageInfo = DamageInfo.new(roundi(_stats.throw_damage * damage_multiplier), self, data.id)
	stone.setup(info, _attack_direction, _stats.throw_speed, _stats.throw_range)
	# Next to the Guardian in the section, so the stone is cleared with it.
	get_parent().add_child(stone)
	stone.global_position = global_position


## The special attack: its strikes on plain floor, one after another.
func _special() -> void:
	var level: Level = get_tree().get_first_node_in_group(Level.GROUP) as Level
	var spots: Array[Vector2] = special_spots(level)
	for i in spots.size():
		_spawn_zone(_stats.special_zone, spots[i], _stats.special_stagger * i)


## Where the special attack's strikes fall now: a line towards the player (it stops at
## the first wall or pit), or the player's spot and a few around it. Spots off plain
## floor are left out.
func special_spots(level: Level) -> Array[Vector2]:
	var spots: Array[Vector2] = []
	var count: int = _stats.special_count_phase_two if phase == 2 else _stats.special_count
	if _stats.special_pattern == GuardianData.SpecialPattern.LINE:
		for i in count:
			var spot: Vector2 = global_position + _attack_direction * _stats.special_spacing * (i + 1)
			if not _on_floor(spot, level):
				break
			spots.append(spot)
		return spots
	var center: Vector2 = _target.global_position if is_instance_valid(_target) else global_position + _attack_direction * _stats.special_spacing
	for i in count:
		var spot: Vector2 = center
		if i > 0:
			var angle: float = GameManager.rng.randf() * TAU
			spot += Vector2.from_angle(angle) * _stats.special_spread * GameManager.rng.randf_range(0.4, 1.0)
		if _on_floor(spot, level):
			spots.append(spot)
	return spots


func _on_floor(spot: Vector2, level: Level) -> bool:
	return level == null or level.cell_type_at(spot) == LevelGrid.Cell.FLOOR


## A boss patch at a spot, with this boss's damage multiplier; delay before it lands.
func _spawn_zone(zone: ZoneData, at: Vector2, delay: float = 0.0) -> void:
	if zone == null or get_parent() == null:
		return
	SpellZone.spawn(get_parent(), at, _scaled(zone), 1, self, data.id, player_hurtbox_mask, sight_mask, delay)


## The patch's damage times damage_multiplier (deeper floors hit harder).
func _scaled(zone: ZoneData) -> ZoneData:
	if is_equal_approx(damage_multiplier, 1.0):
		return zone
	if not _scaled_zones.has(zone):
		var copy: ZoneData = zone.duplicate() as ZoneData
		copy.impact_damage = _times(zone.impact_damage)
		copy.tick_damage = _times(zone.tick_damage)
		_scaled_zones[zone] = copy
	return _scaled_zones[zone]


func _times(values: PackedInt32Array) -> PackedInt32Array:
	var scaled: PackedInt32Array = PackedInt32Array()
	for value: int in values:
		scaled.append(roundi(value * damage_multiplier))
	return scaled


## The shockwave's ring, scaled to its reach.
func _show_ring() -> void:
	var ring: StripSprite = StripSprite.spawn(get_parent(), global_position, _stats.shockwave_ring,
			_stats.shockwave_ring_frames, _stats.shockwave_ring_fps)
	if ring != null:
		ring.scale = Vector2.ONE * (_stats.shockwave_radius / maxf(_stats.shockwave_ring_art_radius, 1.0))


func _slow_player(hurtbox: Hurtbox) -> void:
	var player: Player = hurtbox.get_parent() as Player
	if player != null:
		player.slow(_stats.shockwave_slow_multiplier, _stats.shockwave_slow_time)


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
	Sound.play(_stats.roar_sound)
	phase_changed.emit(phase)
	summon_requested.emit(self, _stats.summon_count)

