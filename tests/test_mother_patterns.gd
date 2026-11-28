extends TestCase
## Headless test for stage 50, part 2: the Mycelium Mother fights with attack patterns.
## Her data has a pattern list for each phase, each with one of her animations; she winds
## up, casts, stands still holding her pose while the pattern plays and never starts
## another while one is on the floor; a sweep is cast from the middle of her arena,
## where she walks back first; her arena's escort is sporelings only.

const MOTHER: String = "res://actors/enemies/mycelium_mother.tres"
const SWEEP: String = "res://actors/enemies/boss_patterns/mother_sweep.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const BIG_HP: int = 100000
## Her HP before the patterns.
const HP_BEFORE: int = 180
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


func run() -> void:
	_test_data()
	_test_escort()
	await _test_cast()
	await _test_sweep_from_home()


func _test_data() -> void:
	var stats: GuardianData = load(MOTHER) as GuardianData
	check(stats.max_hp >= roundi(HP_BEFORE * 1.4), "she has much more HP than before stage 50 (%d, was %d)" % [stats.max_hp, HP_BEFORE])
	check(not stats.patterns_phase_one.is_empty() and not stats.patterns_phase_two.is_empty(),
			"she has patterns for both phases")
	var animated: bool = true
	var home_only_sweeps: bool = true
	for pattern: BossPattern in stats.patterns_phase_one + stats.patterns_phase_two:
		for dir: String in DIRECTIONS:
			var anim: StringName = StringName(pattern.cast_animation + "_" + dir)
			animated = animated and stats.sprite_frames.has_animation(anim) \
					and stats.sprite_frames.get_frame_count(anim) > stats.attack_strike_frame
		home_only_sweeps = home_only_sweeps and pattern.cast_at_home == (pattern is SweepPattern)
	check(animated, "every pattern is cast with one of her animations")
	check(home_only_sweeps, "only the sweeps are cast from the middle of the arena")
	var phase_one_sweeps: int = stats.patterns_phase_one.filter(func(p: BossPattern) -> bool: return p is SweepPattern).size()
	var phase_two_sweeps: int = stats.patterns_phase_two.filter(func(p: BossPattern) -> bool: return p is SweepPattern).size()
	check(phase_one_sweeps == 0 and phase_two_sweeps > 0, "the sweeps come in the second phase")
	check(stats.escort_ids == ([&"sporeling"] as Array[StringName]), "her escort is sporelings")


func _test_escort() -> void:
	var director: Director = GameManager.make_director()
	var table: FloorStyleTable = GameManager.floor_style_table()
	var depth: int = 0
	while table.style_at(depth) != &"fungal":
		depth += 1
	depth += table.depths_per_style - 1
	var plan: SectionPlan = SectionPlan.new()
	plan.depth = depth
	plan.is_arena = true
	plan.is_boss = true
	plan.budget = 60
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 50
	director.finish_arena(plan, rng)
	var ids: Array = plan.enemy_mix.keys()
	check(ids.size() == 2 and ids.has(&"mycelium_mother") and ids.has(&"sporeling") and int(plan.enemy_mix[&"mycelium_mother"]) == 1,
			"her arena holds her and sporelings only: %s" % [plan.enemy_mix])
	var ruins: SectionPlan = SectionPlan.new()
	ruins.depth = table.depths_per_style - 1
	ruins.is_arena = true
	ruins.is_boss = true
	ruins.budget = 60
	director.finish_arena(ruins, rng)
	check(ruins.enemy_mix.has(&"guardian") and ruins.enemy_mix.size() > 2,
			"the Ruins Warden's escort is still any enemies: %s" % [ruins.enemy_mix])


func _test_cast() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(7, 6))
	var boss: Guardian = _add_boss(level, Vector2i(14, 6))
	boss._pattern_cooldown_left = 0.0
	boss._special_cooldown_left = 100.0
	await physics_frames(3)
	var pattern: BossPattern = boss.get_pattern()
	check(boss.state == Enemy.State.WINDUP and boss.attack == Guardian.Attack.PATTERN and pattern != null
			and boss.get_attack_animation() == pattern.cast_animation,
			"with the player in reach she winds up a pattern with its animation")
	check(boss.get_windup_reach() == 0.0, "the bots read it from the floor, not from her wind-up")
	await physics_frames(roundi(((boss.data as GuardianData).pattern_windup + 0.05) * Engine.physics_ticks_per_second))
	var hazards: Array[BossHazard] = _hazards_of(boss)
	var labelled: bool = not hazards.is_empty()
	for hazard: BossHazard in hazards:
		labelled = labelled and hazard.source_id == &"mycelium_mother" and hazard.pattern == pattern
	check(labelled, "then the pattern is on the floor, its hits named after her (%d pieces)" % hazards.size())
	check(boss.is_casting() and boss.get_pose() == StringName(pattern.cast_animation),
			"she holds her cast pose while it plays")
	var at: Vector2 = boss.global_position
	var stood: bool = true
	var second: bool = false
	while not _hazards_of(boss).is_empty():
		await physics_frames(1)
		stood = stood and (not boss.is_casting() or boss.global_position.distance_to(at) < 0.5)
		second = second or (boss.state == Enemy.State.WINDUP and boss.attack == Guardian.Attack.PATTERN)
	check(stood, "she stands still while casting")
	check(not second, "no new pattern while one is on the floor")
	check(not boss.is_casting() and boss._pattern_cooldown_left > 0.0, "after it the next one waits its cooldown")
	await _clean_up([boss, player, level])


func _test_sweep_from_home() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(3, 2))
	var home_cell: Vector2i = Vector2i(10, 6)
	var boss: Guardian = _add_boss(level, home_cell)
	boss._special_cooldown_left = 100.0
	boss._pattern_cooldown_left = 100.0
	await physics_frames(2)
	check(boss.get_home().distance_to(level.cell_center(home_cell)) < 0.5, "she remembers where she woke")
	boss.phase = 2
	boss.global_position = level.cell_center(home_cell + Vector2i(5, 3))
	boss._pattern = load(SWEEP) as BossPattern
	boss._home_walk_left = (boss.data as GuardianData).home_walk_time
	boss._repath_time_left = 0.0
	var started: bool = false
	for _i in roundi(4.0 * Engine.physics_ticks_per_second):
		await physics_frames(1)
		if boss.state == Enemy.State.WINDUP:
			started = true
			break
	check(started and boss.global_position.distance_to(boss.get_home()) <= (boss.data as GuardianData).home_reach + 1.0,
			"before a sweep she walks back to the middle")
	await physics_frames(roundi(((boss.data as GuardianData).pattern_windup + 0.05) * Engine.physics_ticks_per_second))
	var sweeps: Array[BossHazard] = _hazards_of(boss)
	check(sweeps.size() == 1 and sweeps[0] is SweepHazard and sweeps[0].global_position.distance_to(boss.get_home()) <= 9.0,
			"and the arms turn round her there")
	await _clean_up([boss, player, level])


func _hazards_of(boss: Guardian) -> Array[BossHazard]:
	var found: Array[BossHazard] = []
	for node: Node in get_tree().get_nodes_in_group(BossHazard.GROUP):
		var hazard: BossHazard = node as BossHazard
		if hazard != null and hazard.caster == boss and not hazard.is_queued_for_deletion():
			found.append(hazard)
	return found


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
	var stats: GuardianData = load(MOTHER) as GuardianData
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
