extends TestCase
## Headless test for stage 50, part 3: the Sun Pharaoh, boss of the sand floors, built on
## the attack patterns. His data: sun beams (a cross, a fan at the player, the turning
## wheel) and sun cells, mummies as his only servants and escort; in the second phase he
## sinks into the sand before each pattern and comes up where he casts from, out of
## reach while under it. A fan of beams covers only its angle round the aim.

const PHARAOH: String = "res://actors/enemies/sun_pharaoh.tres"
const FAN: String = "res://actors/enemies/boss_patterns/pharaoh_fan.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const BIG_HP: int = 100000
const PLAYER_HURTBOX: int = 8
const ROOM_MAP: String = """#####################
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#####################"""
const DIRECTIONS: Array[String] = ["down", "left", "right", "up"]
const POSES: Array[String] = ["idle", "walk", "beam", "storm", "sink", "emerge", "summon", "roar", "hurt"]


func run() -> void:
	_test_data()
	_test_floor_and_escort()
	await _test_fan()
	await _test_burrow()


func _test_data() -> void:
	var stats: GuardianData = load(PHARAOH) as GuardianData
	var complete: bool = stats.sprite_frames.has_animation(&"death")
	for pose: String in POSES:
		for dir: String in DIRECTIONS:
			complete = complete and stats.sprite_frames.has_animation(StringName(pose + "_" + dir))
	check(complete, "his frames have every pose in four directions and death")
	check(stats.is_boss and stats.floor_style == &"sand" and stats.summon_id == &"mummy"
			and stats.escort_ids == ([&"mummy"] as Array[StringName]) and stats.projectile_scene == null,
			"a boss of the sand floors, calling mummies only, without a throw")
	var animated: bool = true
	var sweeps_home: bool = true
	for pattern: BossPattern in stats.patterns_phase_one + stats.patterns_phase_two:
		for dir: String in DIRECTIONS:
			animated = animated and stats.sprite_frames.has_animation(StringName(pattern.cast_animation + "_" + dir))
		sweeps_home = sweeps_home and pattern.cast_at_home == (pattern is SweepPattern)
	check(not stats.patterns_phase_one.is_empty() and not stats.patterns_phase_two.is_empty() and animated,
			"patterns in both phases, each cast with one of his animations")
	check(sweeps_home, "only the wheel is cast from the middle")
	check(stats.burrow_in_phase_two and stats.sprite_frames.has_animation(StringName(stats.sink_animation + "_down"))
			and stats.sprite_frames.has_animation(StringName(stats.emerge_animation + "_down")),
			"he burrows in the second phase, with his sink and emerge art")
	check(FileAccess.file_exists(Sound.MUSIC_DIR + String(stats.boss_music) + ".ogg")
			and FileAccess.file_exists(Sound.SFX_DIR + String(stats.roar_sound) + ".ogg"), "his music and roar exist")


func _test_floor_and_escort() -> void:
	var director: Director = GameManager.make_director()
	var table: FloorStyleTable = GameManager.floor_style_table()
	var depth: int = 0
	while table.style_at(depth) != &"sand":
		depth += 1
	depth += table.depths_per_style - 1
	check(director.boss_for_depth(depth).id == &"sun_pharaoh", "the sand floors end with him")
	var plan: SectionPlan = SectionPlan.new()
	plan.depth = depth
	plan.is_arena = true
	plan.is_boss = true
	plan.budget = 60
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 51
	director.finish_arena(plan, rng)
	var ids: Array = plan.enemy_mix.keys()
	check(ids.size() == 2 and ids.has(&"mummy") and ids.has(&"sun_pharaoh"), "his arena holds him and mummies only: %s" % [plan.enemy_mix])


func _test_fan() -> void:
	var level: Level = _add_level()
	var fan: RaysPattern = load(FAN) as RaysPattern
	var origin: Vector2 = level.cell_center(Vector2i(10, 6))
	var target: Vector2 = level.cell_center(Vector2i(16, 6))
	var lines: Array[BossHazard] = fan.cast(level, origin, target, null, &"test", 1.0, PLAYER_HURTBOX, RandomNumberGenerator.new())
	await physics_frames(1)
	var spread: float = deg_to_rad(fan.spread_degrees)
	var widest: float = 0.0
	for line: BossHazard in lines:
		widest = maxf(widest, absf(angle_difference(0.0, line.rotation)))
	check(lines.size() == fan.count * fan.volleys and fan.is_fan(), "a fan of %d beams per volley" % fan.count)
	check(widest <= spread * 0.5 + spread / (fan.count - 1) * fan.volley_turn + 0.001,
			"all beams within the fan round the aim (widest %.0f°)" % rad_to_deg(widest))
	var hit_aim: bool = BossHazard.threat_at(get_tree(), target, 0.0, 0.0, fan.get_duration(), lines)
	var behind: Vector2 = origin - (target - origin)
	var hit_behind: bool = BossHazard.threat_at(get_tree(), behind, 6.0, 0.0, fan.get_duration(), lines)
	check(hit_aim and not hit_behind, "the beams cross the aim, behind him is safe")
	await _clean_up([level])


func _test_burrow() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(5, 6))
	var home_cell: Vector2i = Vector2i(10, 6)
	var boss: Guardian = _add_boss(level, home_cell)
	boss._pattern_cooldown_left = 100.0
	await physics_frames(2)
	var stats: GuardianData = boss.data as GuardianData
	boss.phase = 2
	boss._pattern_cooldown_left = 0.0
	await physics_frames(2)
	check(boss.is_burrowing() and boss.get_pose() == StringName(stats.sink_animation) and boss.get_pattern() != null,
			"before a pattern of the second phase he sinks into the sand")
	await physics_frames(roundi((stats.sink_time + 0.05) * Engine.physics_ticks_per_second))
	var pattern: BossPattern = boss.get_pattern()
	check(boss.is_buried() and boss.get_pose() == StringName(stats.emerge_animation), "then, under it, he comes up")
	var absorbed: bool = not boss.health.take_damage(DamageInfo.new(10, player, &"test"))
	check(absorbed and boss.hurtbox.collision_layer == 0, "nothing can hit him under the sand")
	var spot_ok: bool = boss.global_position.distance_to(boss.get_home()) <= 1.0 if pattern.cast_at_home \
			else (boss.global_position.distance_to(player.global_position) >= stats.burrow_min_distance - 0.5
				and boss.global_position.distance_to(boss.get_home()) <= stats.burrow_radius + 16.0
				and level.cell_type_at(boss.global_position) == LevelGrid.Cell.FLOOR)
	check(spot_ok, "where the pattern is cast from (%s)" % pattern.resource_path.get_file())
	await physics_frames(roundi((stats.emerge_time + 0.05) * Engine.physics_ticks_per_second))
	check(not boss.is_buried() and not boss.is_burrowing() and boss.state == Enemy.State.WINDUP
			and boss.attack == Guardian.Attack.PATTERN, "up again, he winds up the pattern and can be hit")
	# The wheel always from the middle, from wherever he sinks.
	await _clean_up([boss])
	boss = _add_boss(level, home_cell)
	boss._pattern_cooldown_left = 100.0
	await physics_frames(2)
	boss.phase = 2
	boss.global_position = level.cell_center(home_cell + Vector2i(4, 3))
	boss._pattern = null
	var wheel: BossPattern = null
	for candidate: BossPattern in stats.patterns_phase_two:
		if candidate.cast_at_home:
			wheel = candidate
	boss._pattern = wheel
	boss._start_burrow()
	await physics_frames(roundi((stats.sink_time + 0.05) * Engine.physics_ticks_per_second))
	check(boss.global_position.distance_to(boss.get_home()) <= 1.0, "the wheel is cast from the middle")
	await _clean_up([boss, player, level])


func _add_level() -> Level:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(ROOM_MAP))
	return level


func _add_player(level: Level, cell: Vector2i) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.global_position = level.cell_center(cell)
	player.health.max_hp = BIG_HP
	player.health.reset()
	return player


func _add_boss(level: Level, cell: Vector2i) -> Guardian:
	var stats: GuardianData = load(PHARAOH) as GuardianData
	var boss: Guardian = stats.scene.instantiate() as Guardian
	boss.data = stats
	add_child(boss)
	boss.global_position = level.cell_center(cell)
	return boss


func _clean_up(nodes: Array) -> void:
	for node: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		node.queue_free()
	for node: Node in nodes:
		node.queue_free()
	await physics_frames(2)
