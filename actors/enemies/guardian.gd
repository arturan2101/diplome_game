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
## Stage 50: room-wide attack patterns (GuardianData.patterns_phase_one/two, BossPattern):
## a short wind-up, then the pattern shows where it will strike and the boss stands
## holding its cast pose until it is over. A pattern cast at home (a sweep) first sends
## the boss back to where it woke, the middle of its arena. A boss that burrows (the Sun
## Pharaoh) instead sinks into the floor before each pattern of its second phase and
## comes up where it casts from.

signal phase_changed(phase: int)
## The game spawns the servants: it owns the enemies of the section.
signal summon_requested(guardian: Guardian, count: int)

enum Attack { SLAM, THROW, SHOCKWAVE, SPECIAL, PATTERN }
## Going under the floor before a pattern (GuardianData.burrow_in_phase_two).
enum Burrow { NONE, SINKING, EMERGING }
## Spots tried for coming up away from the player before falling back to the middle.
const BURROW_TRIES: int = 24

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
## The pattern being wound up or played (or the last one).
var _pattern: BossPattern = null
var _pattern_cooldown_left: float = 0.0
## Seconds left to walk home before the chosen pattern; 0 = not walking home.
var _home_walk_left: float = 0.0
## Where the boss woke: the middle of its arena.
var _home: Vector2 = Vector2.ZERO
var _home_known: bool = false
## True while the boss stands still for its pattern.
var _casting: bool = false
var _burrow: Burrow = Burrow.NONE
var _burrow_left: float = 0.0
## Where the boss comes up.
var _burrow_to: Vector2 = Vector2.ZERO


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
	_pattern_cooldown_left = _stats.first_pattern_delay


func _physics_process(delta: float) -> void:
	if is_dormant:
		return
	if not _home_known:
		_home_known = true
		_home = global_position
	_throw_cooldown_left = maxf(_throw_cooldown_left - delta, 0.0)
	_special_cooldown_left = maxf(_special_cooldown_left - delta, 0.0)
	_casting = _casting and state == State.RECOVER
	if not _casting:
		_pattern_cooldown_left = maxf(_pattern_cooldown_left - delta, 0.0)
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
		Attack.PATTERN:
			# The bots read a pattern from its warning on the floor, not from the wind-up.
			return 0.0
	return data.attack_range


func is_windup_ranged() -> bool:
	return attack == Attack.THROW or attack == Attack.SPECIAL


## True when this boss has a special attack (the elemental Wardens).
func has_special() -> bool:
	return _stats != null and _stats.special_zone != null


## True when this boss casts room-wide patterns (stage 50).
func has_patterns() -> bool:
	return _stats != null and not _stats.patterns_phase_one.is_empty()


## The pattern being wound up or played, or null.
func get_pattern() -> BossPattern:
	if _casting or _home_walk_left > 0.0 or _burrow != Burrow.NONE or (state == State.WINDUP and attack == Attack.PATTERN):
		return _pattern
	return null


func is_casting() -> bool:
	return _casting


func is_walking_home() -> bool:
	return _home_walk_left > 0.0


func is_burrowing() -> bool:
	return _burrow != Burrow.NONE


## Where the boss woke (the middle of its arena).
func get_home() -> Vector2:
	return _home


## Standing for a pattern, the boss holds the last frame of its cast animation.
func get_pose() -> StringName:
	if _burrow == Burrow.SINKING:
		return StringName(_stats.sink_animation)
	if _burrow == Burrow.EMERGING:
		return StringName(_stats.emerge_animation)
	if _casting and _pattern != null and _pattern.cast_animation != "":
		return StringName(_pattern.cast_animation)
	return &""


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
		Attack.PATTERN:
			# The pattern sounds its own warning and strike.
			return &""
	return data.attack_sound


func get_attack_animation() -> String:
	if attack == Attack.PATTERN and _pattern != null and _pattern.cast_animation != "":
		return _pattern.cast_animation
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
	if _home_walk_left > 0.0:
		_walk_home(delta)
		return
	if _burrow != Burrow.NONE:
		_update_burrow(delta)
		return
	var distance: float = global_position.distance_to(_target.global_position)
	if _wants_pattern(distance):
		_pattern = _pick_pattern()
		if phase == 2 and _stats.burrow_in_phase_two:
			_start_burrow()
			return
		if _pattern.cast_at_home and global_position.distance_to(_home) > _stats.home_reach:
			_home_walk_left = _stats.home_walk_time
			_repath_time_left = 0.0
			_walk_home(delta)
			return
		_start_attack(Attack.PATTERN)
		return
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
		Attack.PATTERN:
			_state_time_left = _stats.pattern_windup
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
		Attack.PATTERN:
			_cast_pattern()
			return
	struck.emit()
	_enter(State.RECOVER)
	if phase == 2:
		_state_time_left *= _stats.phase_two_recovery_multiplier


## True when a pattern is due: it has some, its cooldown is over, none of its hazards
## is still on the floor and the player is within reach.
func _wants_pattern(distance: float) -> bool:
	if not has_patterns() or _pattern_cooldown_left > 0.0 or distance > _stats.pattern_range:
		return false
	for node: Node in get_tree().get_nodes_in_group(BossHazard.GROUP):
		var hazard: BossHazard = node as BossHazard
		if hazard != null and hazard.caster == self and not hazard.is_queued_for_deletion():
			return false
	return true


## A pattern of the current phase at random, not the last one again.
func _pick_pattern() -> BossPattern:
	var patterns: Array[BossPattern] = _stats.patterns_phase_one
	if phase == 2 and not _stats.patterns_phase_two.is_empty():
		patterns = _stats.patterns_phase_two
	var choices: Array[BossPattern] = []
	for pattern: BossPattern in patterns:
		if pattern != _pattern:
			choices.append(pattern)
	if choices.is_empty():
		choices = patterns
	return choices[GameManager.rng.randi_range(0, choices.size() - 1)]


## Back to the middle of the arena before a pattern cast at home; casts on arrival or
## when the time is up.
func _walk_home(delta: float) -> void:
	_home_walk_left -= delta
	if global_position.distance_to(_home) <= _stats.home_reach or _home_walk_left <= 0.0:
		_home_walk_left = 0.0
		_start_attack(Attack.PATTERN)
		return
	velocity = _direction_to_point(_home, delta) * get_walk_speed()
	if phase == 2:
		velocity *= _stats.phase_two_speed_multiplier


## Sinks into the floor to come up where the chosen pattern is cast from.
func _start_burrow() -> void:
	_burrow = Burrow.SINKING
	_burrow_left = _stats.sink_time
	_burrow_to = _home if _pattern.cast_at_home else _burrow_spot()
	velocity = Vector2.ZERO
	Sound.play_at(_stats.sink_sound, global_position)


## Sinking, then (out of reach under the floor) moved and coming up; casts once up.
func _update_burrow(delta: float) -> void:
	velocity = Vector2.ZERO
	_burrow_left -= delta
	if _burrow_left > 0.0:
		return
	if _burrow == Burrow.SINKING:
		set_buried(true)
		global_position = _burrow_to
		_burrow = Burrow.EMERGING
		_burrow_left = _stats.emerge_time
		Sound.play_at(_stats.emerge_sound, global_position)
		return
	_burrow = Burrow.NONE
	set_buried(false)
	_start_attack(Attack.PATTERN)


## A plain floor spot near the middle of the arena, away from the player; the middle
## itself when none is found.
func _burrow_spot() -> Vector2:
	var level: Level = get_tree().get_first_node_in_group(Level.GROUP) as Level
	var player: Vector2 = _target.global_position if is_instance_valid(_target) else global_position
	for _i in BURROW_TRIES:
		var spot: Vector2 = _home + Vector2.from_angle(GameManager.rng.randf() * TAU) 				* _stats.burrow_radius * sqrt(GameManager.rng.randf())
		if level != null:
			# Come up in the middle of a cell.
			spot = level.cell_center(level.cell_at(spot))
		if _on_floor(spot, level) and spot.distance_to(player) >= _stats.burrow_min_distance:
			return spot
	return _home


## Casts the wound-up pattern and stands still while it plays; the cooldown starts when
## it is over.
func _cast_pattern() -> void:
	var aim: Vector2 = _target.global_position if is_instance_valid(_target) else global_position + _attack_direction
	_pattern.cast(get_parent(), global_position, aim, self, data.id, damage_multiplier, player_hurtbox_mask,
			GameManager.rng)
	struck.emit()
	_enter(State.RECOVER)
	_state_time_left = _pattern.get_duration()
	_casting = true
	_pattern_cooldown_left = _stats.pattern_cooldown_phase_two if phase == 2 else _stats.pattern_cooldown


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
		_scaled_zones[zone] = zone.scaled(damage_multiplier)
	return _scaled_zones[zone]


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
	_home_walk_left = 0.0
	_casting = false
	_burrow = Burrow.NONE
	if weapon != null:
		weapon.cancel_attack()
	_enter(State.CHASE)
	_roar_left = _stats.roar_time
	_summon_left = _stats.summon_interval
	_shockwave_next = true
	Sound.play(_stats.roar_sound)
	phase_changed.emit(phase)
	summon_requested.emit(self, _stats.summon_count)

