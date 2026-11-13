extends TestCase
## Headless test for the boss, the Guardian of the Ruins: plans (boss arenas on every
## second depth, an escort from the rest of the budget, never bought as an ordinary
## enemy), its attacks and phases in a small room (slam, thrown stone, second phase
## with servants and shockwave, no knockback), and the boss arena in the game.

const GAME_SCENE: String = "res://main/main.tscn"
const GUARDIAN: String = "res://actors/enemies/guardian.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const BIG_HP: int = 100000
const RUN_SEED: int = 77
const ROOM_MAP: String = """###############
#.............#
#.............#
#.............#
#.............#
#.............#
#.............#
#.............#
#.............#
#.............#
###############"""

var _data: GuardianData = null


func run() -> void:
	_data = load(GUARDIAN) as GuardianData
	_test_plans()
	await _test_slam()
	await _test_throw()
	await _test_second_phase()
	await _test_boss_arena()


func _test_plans() -> void:
	var directors: Array[Director] = [RandomDirector.new(), RuleDirector.new()]
	var right_depths: bool = true
	var escort_fits: bool = true
	for director: Director in directors:
		for depth in 6:
			var state: PlayerState = PlayerState.new()
			state.depth = depth
			state.section_index = depth * 4 + 3
			state.is_depth_end = true
			state.rng.seed = depth + 1
			var plan: SectionPlan = director.choose_next(state)
			var wants_boss: bool = depth % 2 == 1
			if plan.is_boss != wants_boss or plan.enemy_mix.has(&"guardian") != wants_boss:
				right_depths = false
			if plan.is_boss:
				var escort: Dictionary = plan.enemy_mix.duplicate()
				escort.erase(&"guardian")
				if int(plan.enemy_mix[&"guardian"]) != 1 or plan.waves != 1 \
						or director.mix_cost(escort) > maxi(0, plan.budget - _data.danger_cost):
					escort_fits = false
	check(right_depths, "the arenas of depths 2, 4 and 6 hold the boss, the others do not (both directors)")
	check(escort_fits, "a boss arena: one Guardian, one wave, an escort bought with the rest of the budget")
	var director: Director = Director.new()
	var bought_boss: bool = false
	for i in 50:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = i
		if director.buy_enemies(60, rng).has(&"guardian"):
			bought_boss = true
	check(not bought_boss, "the boss is never bought from a danger budget")


func _test_slam() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(7, 5))
	var guardian: Guardian = _add_guardian(level, Vector2i(8, 5))
	await physics_frames(3)
	check(guardian.state == Enemy.State.WINDUP and guardian.attack == Guardian.Attack.SLAM
			and is_equal_approx(guardian.get_windup_reach(), _data.attack_range) and not guardian.is_windup_ranged(),
			"close to the player the Guardian winds up a slam")
	var early: float = guardian.get_windup_progress()
	await physics_frames(20)
	check(guardian.get_windup_progress() > early, "the slam's telegraph fills up during the windup")
	await physics_frames(roundi(_data.windup * Engine.physics_ticks_per_second))
	var slam: int = (_data.weapon as MeleeWeaponData).combo[0].damage
	check(BIG_HP - player.health.hp == slam, "a slam that is not avoided hits for %d" % slam)
	for node: Node in [guardian, player, level]:
		node.queue_free()
	await physics_frames(2)


func _test_throw() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(2, 5))
	var guardian: Guardian = _add_guardian(level, Vector2i(9, 5))
	await physics_frames(3)
	check(guardian.state == Enemy.State.WINDUP and guardian.attack == Guardian.Attack.THROW and guardian.is_windup_ranged(),
			"a player keeping away gets a thrown stone, wound up first")
	await physics_frames(roundi((_data.throw_windup + 0.8) * Engine.physics_ticks_per_second))
	check(BIG_HP - player.health.hp == _data.throw_damage, "the stone hits for %d" % _data.throw_damage)
	for node: Node in [guardian, player, level]:
		node.queue_free()
	await physics_frames(2)


func _test_second_phase() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(6, 5))
	var guardian: Guardian = _add_guardian(level, Vector2i(9, 5))
	var phases: Array[int] = []
	var summons: Array[int] = []
	guardian.phase_changed.connect(func(phase: int) -> void: phases.append(phase))
	guardian.summon_requested.connect(func(_boss: Guardian, count: int) -> void: summons.append(count))
	await physics_frames(2)
	guardian.apply_knockback(Vector2(500.0, 0.0))
	check(guardian.state != Enemy.State.STAGGER and guardian.velocity.length() < 100.0, "knockback does not move the boss")
	guardian.health.take_damage(DamageInfo.new(guardian.health.max_hp / 2 + 1, null, &"test"))
	check(guardian.phase == 2 and phases == ([2] as Array[int]) and summons == ([_data.summon_count] as Array[int])
			and guardian.is_roaring(), "below half HP: second phase, a roar and a call for %d servants" % _data.summon_count)
	# Close to the player after the roar: the first close attack is the shockwave.
	player.global_position = guardian.global_position + Vector2(-40.0, 0.0)
	var hp_before: int = player.health.hp
	await physics_frames(roundi((_data.roar_time + 0.1) * Engine.physics_ticks_per_second))
	check(guardian.state == Enemy.State.WINDUP and guardian.attack == Guardian.Attack.SHOCKWAVE
			and is_equal_approx(guardian.get_windup_reach(), _data.shockwave_radius),
			"after the roar the Guardian winds up a shockwave")
	await physics_frames(roundi((_data.shockwave_windup + 0.1) * Engine.physics_ticks_per_second))
	check(hp_before - player.health.hp == _data.shockwave_damage, "the shockwave hits for %d" % _data.shockwave_damage)
	await physics_frames(roundi(_data.summon_interval * Engine.physics_ticks_per_second))
	check(summons.size() >= 2, "it keeps calling servants every %.0f s" % _data.summon_interval)
	for node: Node in [guardian, player, level]:
		node.queue_free()
	await physics_frames(2)


func _test_boss_arena() -> void:
	GameManager.start_run(RUN_SEED)
	while not (GameManager.depth == 1 and GameManager.is_last_section_of_depth()):
		GameManager.advance_section()
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	game.player.health.max_hp = BIG_HP
	game.player.health.reset()
	var boss: Guardian = null
	for enemy: Enemy in game.get_enemies():
		if enemy is Guardian:
			boss = enemy as Guardian
	var arena: Rect2i = game.layout.room_rects[game.layout.arena_room]
	check(game.plan.is_boss and boss != null and arena.has_point(game.level.cell_at(boss.global_position)),
			"the last section of depth 2 is a boss arena with the Guardian inside")
	if boss == null:
		game.queue_free()
		await physics_frames(2)
		return
	game.player.teleport(game.level.cell_center(game.level.nearest_floor_cell(arena.get_center() + Vector2i(0, 3))))
	await physics_frames(3)
	check(game.is_arena_sealed() and game.hud.boss_bar.visible, "entering the arena seals it and shows the boss bar")
	boss.health.take_damage(DamageInfo.new(boss.health.max_hp / 2 + 1, null, &"test"))
	await physics_frames(2)
	check(_servants(game) == _data.summon_count, "the second phase brings %d servants" % _data.summon_count)
	for _i in 3:
		boss.summon_requested.emit(boss, _data.summon_count)
	await physics_frames(2)
	check(_servants(game) == _data.summon_max_alive, "never more than %d servants at once" % _data.summon_max_alive)
	boss.health.take_damage(DamageInfo.new(BIG_HP, null, &"test", Vector2.ZERO))
	await physics_frames(2)
	check(_servants(game) == 0 and not game.hud.boss_bar.visible, "when the boss falls its servants crumble")
	check(game.spell_choice.is_open() and get_tree().paused, "beating the boss offers a spell")
	game.spell_choice.back_button.pressed.emit()
	for enemy: Enemy in game.get_enemies():
		enemy.health.take_damage(DamageInfo.new(BIG_HP, null, &"test"))
	await physics_frames(3)
	check(not get_tree().paused and game.gate.is_open and not game.is_arena_sealed(), "with the escort gone the way down opens")
	game.queue_free()
	await physics_frames(3)


func _servants(game: Game) -> int:
	var count: int = 0
	for enemy: Enemy in game.get_enemies():
		if enemy.has_meta(Game.SUMMONED_META):
			count += 1
	return count


func _add_level() -> Level:
	var level: Level = Level.new()
	level.debug_map = ROOM_MAP
	add_child(level)
	return level


func _add_player(level: Level, cell: Vector2i) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.global_position = level.cell_center(cell)
	player.health.max_hp = BIG_HP
	player.health.reset()
	return player


func _add_guardian(level: Level, cell: Vector2i) -> Guardian:
	var guardian: Guardian = _data.scene.instantiate() as Guardian
	guardian.data = _data
	add_child(guardian)
	guardian.global_position = level.cell_center(cell)
	return guardian
