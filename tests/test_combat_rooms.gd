extends TestCase
## Headless test for combat rooms and elite enemies: the director's rule (more often at
## a peak, never in rest), the generator (a room of the path with a double share of
## enemies in waves), a whole fight in the game (doors seal, spawn warnings away from
## the player, waves one after another, doors open), elites only where and when they
## may come, the shield skeleton's guard and the triple-shot bow, and the series switches.

const GAME_SCENE: String = "res://main/main.tscn"
const SHIELD_SKELETON: String = "res://actors/enemies/skeleton_shield.tres"
const TRIPLE_ARCHER: String = "res://actors/enemies/archer_triple.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const BIG_HP: int = 100000
const PLANS: int = 300
const SEEDS: int = 40
const RUN_SEED: int = 23


func run() -> void:
	_test_director()
	_test_generation()
	await _test_fight()
	_test_elites()
	await _test_shield()
	await _test_triple_shot()
	_test_config()


func _test_director() -> void:
	var settings: DirectorSettings = (load(Director.SETTINGS_PATH) as DirectorSettings).duplicate() as DirectorSettings
	var rules: RuleDirector = RuleDirector.new(null, settings)
	var peaks: int = 0
	var builds: int = 0
	var peak_rooms: int = 0
	var build_rooms: int = 0
	var fits: bool = true
	for i in PLANS:
		var plan: SectionPlan = rules.choose_next(_state(2 + i % 4, i))
		if plan.combat_rooms > 0:
			var waves: Vector2i = settings.combat_waves_peak if plan.phase == SectionPlan.PHASE_PEAK else settings.combat_waves_build
			if plan.combat_waves < waves.x or plan.combat_waves > waves.y or plan.phase == SectionPlan.PHASE_REST or plan.is_arena:
				fits = false
		if plan.phase == SectionPlan.PHASE_PEAK:
			peaks += 1
			peak_rooms += plan.combat_rooms
		elif plan.phase == SectionPlan.PHASE_BUILD:
			builds += 1
			build_rooms += plan.combat_rooms
	check(fits and peaks > 0 and builds > 0 and float(peak_rooms) / peaks > float(build_rooms) / builds,
			"combat rooms: waves in the phase's range, more often at a peak (%d/%d) than in a build-up (%d/%d), never in rest"
			% [peak_rooms, peaks, build_rooms, builds])
	settings.combat_room_chance_peak = 0.0
	settings.combat_room_chance_build = 0.0
	settings.combat_room_chance_random = 0.0
	var plan_off: SectionPlan = SectionPlan.new()
	plan_off.phase = SectionPlan.PHASE_PEAK
	plan_off.enemy_mix = {&"skeleton": 3}
	var rng: RandomNumberGenerator = _rng(9)
	var before: int = rng.state
	rules.plan_combat_rooms(plan_off, rng)
	check(plan_off.combat_rooms == 0 and rng.state == before, "combat rooms off: none planned and no random number drawn")


func _test_generation() -> void:
	var builder: SectionBuilder = SectionBuilder.new()
	var good: int = 0
	for i in SEEDS:
		var plan: SectionPlan = SectionPlan.new()
		plan.room_count = 4
		plan.enemy_mix = {&"skeleton": 4, &"archer": 2}
		plan.combat_rooms = 1
		plan.combat_waves = 3
		var layout: SectionLayout = builder.build(plan, _rng(700 + i))
		if layout.combat_rooms.size() != 1:
			continue
		var entry: Dictionary = layout.combat_rooms[0]
		var room: int = int(entry["room"])
		var inside: int = 0
		var waves_seen: Dictionary = {}
		var others: int = 0
		for enemy: Dictionary in layout.enemies:
			if int(enemy["room"]) == room:
				inside += 1
				waves_seen[int(enemy["wave"])] = true
			else:
				others += 1
		if room != 0 and not (entry["doors"] as Array).is_empty() and int(entry["waves"]) == waves_seen.size() \
				and waves_seen.size() <= 3 and inside >= others / 2:
			good += 1
	check(good == SEEDS, "the combat room is a later room of the path, with a double share of enemies in its waves (%d of %d)"
			% [good, SEEDS])


func _test_fight() -> void:
	GameManager.config = GameManager.load_config("full")
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	var director: Director = game._director
	director.settings = director.settings.duplicate() as DirectorSettings
	director.settings.combat_room_chance_build = 1.0
	director.settings.combat_waves_build = Vector2i(2, 2)
	director.settings.trap_chance = 0.0
	game._start_section()
	await physics_frames(2)
	game.player.health.max_hp = BIG_HP
	game.player.health.reset()
	var tracker: CombatRoomTracker = game.get_combat_rooms()
	check(game.plan.combat_rooms == 1 and tracker.rooms.size() == 1, "the planned combat room is in the section")
	if tracker.rooms.is_empty():
		game.queue_free()
		GameManager.config = GameManager.DEFAULT_CONFIG
		await physics_frames(2)
		return
	var room: CombatRoom = tracker.rooms[0]
	check(_enemies_in(game, room.rect) == 0, "before the player comes, the combat room is empty")
	game.player.teleport(game.level.cell_center(game.level.nearest_floor_cell(room.rect.get_center())))
	await physics_frames(3)
	var sealed: bool = room.state == CombatRoom.State.FIGHTING
	for cell: Vector2i in room.doors:
		if game.level.grid.get_cell(cell) != LevelGrid.Cell.WALL:
			sealed = false
	check(sealed and _markers(game) > 0, "walking in seals the doors and shows where the first wave will appear")
	await physics_frames(roundi(tracker.warning_time * Engine.physics_ticks_per_second) + 3)
	var far: bool = _enemies_in(game, room.rect) > 0
	for enemy: Enemy in game.get_enemies():
		if room.rect.has_point(game.level.cell_at(enemy.global_position)) \
				and enemy.global_position.distance_to(game.player.global_position) < tracker.min_player_distance - 1.0:
			far = false
	check(far and _markers(game) == 0, "after the warning the wave appears, never right next to the player")
	var waves_fought: int = 0
	for _round in 6:
		if room.state != CombatRoom.State.FIGHTING:
			break
		waves_fought += 1
		for enemy: Enemy in game.get_enemies():
			enemy.health.take_damage(DamageInfo.new(BIG_HP, null, &"test"))
		await physics_frames(roundi(tracker.warning_time * Engine.physics_ticks_per_second) + 5)
	var open: bool = room.state == CombatRoom.State.CLEARED
	for cell: Vector2i in room.doors:
		if game.level.grid.get_cell(cell) != LevelGrid.Cell.FLOOR:
			open = false
	check(open and waves_fought == 2, "the waves come one after another (%d) and then the doors open" % waves_fought)
	game.queue_free()
	GameManager.config = GameManager.DEFAULT_CONFIG
	await physics_frames(3)


func _test_elites() -> void:
	var settings: DirectorSettings = (load(Director.SETTINGS_PATH) as DirectorSettings).duplicate() as DirectorSettings
	var director: Director = Director.new(null, settings)
	var at_first_depth: int = 0
	var later: int = 0
	var switched_off: int = 0
	for i in PLANS:
		at_first_depth += _elites(director.buy_enemies(20, _rng(i), {}, 0))
		later += _elites(director.buy_enemies(20, _rng(i), {}, 1))
	settings.elites_enabled = false
	for i in PLANS:
		switched_off += _elites(director.buy_enemies(20, _rng(i), {}, 3))
	check(at_first_depth == 0 and later > 0 and switched_off == 0,
			"elites come from the second depth on (%d bought), never at the first or when switched off" % later)
	var shield: EnemyData = load(SHIELD_SKELETON) as EnemyData
	var archer: EnemyData = load(TRIPLE_ARCHER) as EnemyData
	check(shield.is_elite and archer.is_elite and shield.min_depth == 1 and archer.min_depth == 1
			and shield.danger_cost > 2 and archer.danger_cost > 3, "both elites cost more than their plain kin")


func _test_shield() -> void:
	var data: ShieldSkeletonData = load(SHIELD_SKELETON) as ShieldSkeletonData
	var skeleton: ShieldSkeleton = data.scene.instantiate() as ShieldSkeleton
	skeleton.data = data
	add_child(skeleton)
	skeleton.global_position = Vector2(200.0, 200.0)
	await physics_frames(2)
	skeleton.shield_direction = Vector2.RIGHT
	var hp: int = skeleton.health.hp
	var front: DamageInfo = DamageInfo.new(10, null, &"sword")
	front.direction = Vector2.LEFT
	check(not skeleton.hurtbox.receive_hit(front) and skeleton.health.hp == hp, "a hit from the front hits the shield")
	var side: DamageInfo = DamageInfo.new(10, null, &"sword")
	side.direction = Vector2.DOWN
	check(skeleton.hurtbox.receive_hit(side) and skeleton.health.hp == hp - 10, "a hit from the side gets past the shield")
	var finisher: DamageInfo = DamageInfo.new(10, null, &"sword", Vector2(-200.0, 0.0))
	finisher.direction = Vector2.LEFT
	check(skeleton.hurtbox.receive_hit(finisher) and skeleton.state == Enemy.State.STAGGER,
			"the combo's knockback hit breaks through and staggers it")
	skeleton.queue_free()
	await physics_frames(2)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.global_position = Vector2(100.0, 200.0)
	player.health.max_hp = BIG_HP
	player.health.reset()
	var turner: ShieldSkeleton = data.scene.instantiate() as ShieldSkeleton
	turner.data = data
	add_child(turner)
	turner.global_position = Vector2(200.0, 200.0)
	await physics_frames(1)
	turner.shield_direction = Vector2.RIGHT
	await physics_frames(6)
	var to_player: Vector2 = turner.global_position.direction_to(player.global_position)
	check(absf(turner.shield_direction.angle_to(to_player)) > deg_to_rad(90.0),
			"the shield turns slowly: a moment after the player shows up behind, it still faces away")
	for node: Node in [turner, player]:
		node.queue_free()
	await physics_frames(2)


func _test_triple_shot() -> void:
	var archer: EnemyData = load(TRIPLE_ARCHER) as EnemyData
	var stats: BowWeaponData = archer.weapon as BowWeaponData
	var holder: Node2D = Node2D.new()
	add_child(holder)
	var bow: BowWeapon = stats.weapon_scene.instantiate() as BowWeapon
	bow.setup(stats, holder, archer.id)
	holder.add_child(bow)
	var before: int = get_tree().get_nodes_in_group(Arrow.GROUP).size()
	bow._shoot(Vector2.RIGHT, 8)
	var arrows: Array[Node] = get_tree().get_nodes_in_group(Arrow.GROUP)
	var angles: Array[float] = []
	for node: Node in arrows:
		var arrow: Arrow = node as Arrow
		if arrow != null and arrow.get_parent() != null:
			angles.append(rad_to_deg(arrow._direction.angle()))
	angles.sort()
	check(arrows.size() - before == 3 and angles.size() >= 3 and is_equal_approx(angles[0], -stats.spread_degrees * 0.5)
			and is_equal_approx(angles[angles.size() - 1], stats.spread_degrees * 0.5),
			"the elite archer shoots a fan of three arrows over %d degrees" % roundi(stats.spread_degrees))
	for node: Node in arrows:
		node.queue_free()
	holder.queue_free()
	await physics_frames(2)


func _test_config() -> void:
	var clean: ExperimentConfig = GameManager.load_config("clean")
	var soft: ExperimentConfig = GameManager.load_config("clean_soft")
	var full: ExperimentConfig = GameManager.load_config("full")
	check(not clean.combat_rooms and not clean.elite_enemies and not soft.combat_rooms and not soft.elite_enemies
			and full.combat_rooms and full.elite_enemies,
			"combat rooms and elites are off in the clean series (and so in the playtest), on in the full game")
	GameManager.config = clean
	var clean_director: Director = GameManager.make_director()
	GameManager.config = GameManager.DEFAULT_CONFIG
	check(is_zero_approx(clean_director.settings.combat_room_chance_peak) and is_zero_approx(clean_director.settings.combat_room_chance_build)
			and is_zero_approx(clean_director.settings.combat_room_chance_random) and not clean_director.settings.elites_enabled,
			"the clean series' director plans no combat rooms and buys no elites")


func _elites(mix: Dictionary) -> int:
	return int(mix.get(&"skeleton_shield", 0)) + int(mix.get(&"archer_triple", 0))


func _enemies_in(game: Game, rect: Rect2i) -> int:
	var count: int = 0
	for enemy: Enemy in game.get_enemies():
		if rect.has_point(game.level.cell_at(enemy.global_position)):
			count += 1
	return count


func _markers(game: Game) -> int:
	var count: int = 0
	for node: Node in game.level.get_children():
		for child: Node in node.get_children():
			if child is SpawnMarker:
				count += 1
	return count


func _state(section_index: int, rng_seed: int) -> PlayerState:
	var state: PlayerState = PlayerState.new()
	state.section_index = section_index
	state.depth = section_index / 3
	state.skill = 0.62
	var phases: Array[StringName] = []
	for k in section_index % 4:
		phases.append([SectionPlan.PHASE_BUILD, SectionPlan.PHASE_BUILD, SectionPlan.PHASE_PEAK, SectionPlan.PHASE_REST][k])
	state.phases = phases
	for _k in phases.size():
		state.results.append(0.6)
	state.rng = _rng(rng_seed)
	return state


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
