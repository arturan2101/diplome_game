extends TestCase
## Headless test for the two kinds of spikes: the timed cycle, damage only while the
## spikes are up (with the kind as the damage source), paths over a wave, the director
## buying traps from its budget, the generator placing them (a wave cannot be walked
## around, traps only add spikes), the series switch, and the bot waiting for its moment.

const GAME_SCENE: String = "res://main/main.tscn"
const HAZARDS: String = "res://level/hazards.tres"
const BIG_HP: int = 100000
const BOT_SEED: int = 31
const SEEDS: int = 40
const PLANS: int = 300
const TIMED_MAP: String = """#######
#.....#
#..!..#
#.....#
#######"""
## A corridor 3 cells high: a wave fills columns WAVE_X..WAVE_X+2.
const CORRIDOR: String = """##########################
#........................#
#........................#
#........................#
##########################"""
const WAVE_X: int = 8
const WAVE_ROWS: int = 3
## A room where a wave of one row blocks the middle except for a way around below.
const DETOUR_MAP: String = """###########
#....!....#
#....!....#
#....#....#
#.........#
###########"""

var _timed: SpikeTrapData = null
var _static: SpikeTrapData = null


func run() -> void:
	var hazards: HazardData = load(HAZARDS) as HazardData
	_timed = hazards.timed_spikes
	_static = hazards.static_spikes
	_test_cycle()
	await _test_level_and_damage()
	_test_paths()
	_test_director()
	_test_generation()
	_test_config()
	await _test_bot()


func _test_cycle() -> void:
	var period: float = _timed.get_period()
	var hidden_end: float = _timed.hidden_time
	var up_start: float = _timed.hidden_time + _timed.warn_time + _timed.rise_time
	check(_timed.timed and not _static.timed and _timed.id == &"spikes_timed" and _static.id == &"spikes_static"
			and _timed.danger_cost > _static.danger_cost and is_equal_approx(_timed.warn_time, 0.5),
			"two kinds: static spikes_static and timed spikes_timed (dearer), the warning lasts 0.5 s")
	check(_timed.phase_at(0.1) == SpikeTrapData.PHASE_HIDDEN and _timed.phase_at(hidden_end + 0.1) == SpikeTrapData.PHASE_WARN
			and _timed.phase_at(up_start - 0.05) == SpikeTrapData.PHASE_RISE and _timed.phase_at(up_start + 0.1) == SpikeTrapData.PHASE_UP
			and _timed.phase_at(up_start + _timed.up_time + 0.05) == SpikeTrapData.PHASE_RETRACT
			and _timed.phase_at(period + 0.1) == SpikeTrapData.PHASE_HIDDEN,
			"timed spikes go hidden -> warn -> rise -> up -> retract and around again")
	check(_timed.is_up_at(up_start + 0.1) and not _timed.is_up_at(hidden_end + 0.1) and _static.is_up_at(123.4),
			"only the up phase hurts; static spikes are always up")
	check(_timed.is_down_during(0.0, hidden_end) and not _timed.is_down_during(up_start - 0.2, up_start + 0.05)
			and _timed.is_down_during(period, period + hidden_end) and not _timed.is_down_during(-0.5, period - 0.5),
			"a window is safe only if no up phase overlaps it, in any cycle")


func _test_level_and_damage() -> void:
	var grid: LevelGrid = LevelGrid.from_text(TIMED_MAP)
	var cell: Vector2i = Vector2i(3, 2)
	var level: Level = Level.new()
	add_child(level)
	level.build(grid)
	var up_start: float = _timed.hidden_time + _timed.warn_time + _timed.rise_time
	check(grid.get_cell(cell) == LevelGrid.Cell.SPIKES_TIMED and level.timed_spikes.has_cell(cell)
			and level.timed_spikes.get_child_count() == 1 and grid.to_text() == TIMED_MAP,
			"a ! in a map is a timed spike cell with its own sprite")
	var body: CharacterBody2D = TestFactory.hazard_body(100)
	var health: Health = body.get_node("Health")
	var sources: Array[StringName] = []
	health.damaged.connect(func(info: DamageInfo) -> void: sources.append(info.source_id))
	body.position = level.cell_center(cell)
	add_child(body)
	await physics_frames(3)
	check(health.hp == 100 and not level.are_timed_spikes_up(cell), "hidden timed spikes do no damage")
	level.section_time = up_start - 0.05
	await physics_frames(10)
	check(health.hp == 100 - _timed.damage and sources == ([&"spikes_timed"] as Array[StringName]),
			"rising spikes hurt once they are up, with source spikes_timed")
	var sprite: AnimatedSprite2D = level.timed_spikes.get_child(0) as AnimatedSprite2D
	check(sprite.animation == SpikeTrapData.PHASE_UP, "the sprite shows the phase of the section clock")
	level.section_time = 0.0
	await physics_frames(20)
	check(health.hp == 100 - _timed.damage and sprite.animation == SpikeTrapData.PHASE_HIDDEN,
			"down again, they stop hurting")
	grid.set_timed_spikes(cell, up_start + 0.1)
	level.build(grid)
	check(level.are_timed_spikes_up(cell), "a phase shift moves the cell's cycle (here: up from the start)")
	body.queue_free()
	level.queue_free()
	await physics_frames(2)


func _test_paths() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(CORRIDOR.replace("#........................#\n#........................#\n#........................#",
			"#.......!...............#\n#.......!...............#\n#.......!...............#")))
	var across: PackedVector2Array = level.find_path(level.cell_center(Vector2i(2, 2)), level.cell_center(Vector2i(20, 2)))
	var crosses: bool = false
	for point: Vector2 in across:
		if level.cell_type_at(point) == LevelGrid.Cell.SPIKES_TIMED:
			crosses = true
	check(not across.is_empty() and crosses, "with no way around, a path crosses the timed spikes")
	level.build(LevelGrid.from_text(DETOUR_MAP))
	var around: PackedVector2Array = level.find_path(level.cell_center(Vector2i(2, 1)), level.cell_center(Vector2i(8, 1)))
	var avoids: bool = not around.is_empty()
	for point: Vector2 in around:
		if level.cell_type_at(point) == LevelGrid.Cell.SPIKES_TIMED:
			avoids = false
	check(avoids, "with a way around, a path walks around the timed spikes")
	level.queue_free()


func _test_director() -> void:
	var settings: DirectorSettings = (load(Director.SETTINGS_PATH) as DirectorSettings).duplicate() as DirectorSettings
	settings.trap_chance = 1.0
	var rules: RuleDirector = RuleDirector.new(null, settings)
	var fits: bool = true
	var bought: int = 0
	var kinds: Dictionary = {}
	for i in PLANS:
		var state: PlayerState = _state(3 + i % 3, i)
		var plan: SectionPlan = rules.choose_next(state)
		var cost: int = rules.trap_cost(plan.traps)
		var groups: int = 0
		for id: StringName in plan.traps:
			groups += int(plan.traps[id])
			kinds[id] = true
		bought += 1 if groups > 0 else 0
		if cost > floori(plan.budget * settings.trap_budget_share) or groups > settings.max_trap_groups \
				or rules.mix_cost(plan.enemy_mix) > plan.budget - cost \
				or (groups > 0 and (plan.phase == SectionPlan.PHASE_REST or plan.is_arena)):
			fits = false
	check(fits and bought > PLANS / 3 and kinds.size() == 2,
			"traps cost at most 30%% of the budget, the enemies the rest; none in rest or arena (%d plans with traps)" % bought)
	var off: Director = Director.new()
	var plan_off: SectionPlan = SectionPlan.new()
	plan_off.budget = 14
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 5
	var before: int = rng.state
	off.settings = settings.duplicate() as DirectorSettings
	off.settings.trap_chance = 0.0
	check(off.buy_traps(plan_off, rng) == 14 and plan_off.traps.is_empty() and rng.state == before,
			"traps switched off: none bought and no random number drawn, so plans stay as before")
	var learned_traps: int = 0
	var random_traps: int = 0
	var learned: LearnedDirector = LearnedDirector.new(null, settings)
	var random: RandomDirector = RandomDirector.new(null, settings)
	for i in PLANS:
		learned_traps += 1 if not learned.choose_next(_state(4, i)).traps.is_empty() else 0
		random_traps += 1 if not random.choose_next(_state(4, i)).traps.is_empty() else 0
	check(learned_traps > 0 and random_traps > 0, "the learned and the random director buy traps by the same rule")


func _test_generation() -> void:
	var builder: SectionBuilder = SectionBuilder.new()
	var waves: int = 0
	var cut: int = 0
	var only_added: bool = true
	var same: bool = true
	for seed_index in SEEDS:
		var plan: SectionPlan = SectionPlan.new()
		plan.room_count = 4
		plan.traps = {&"spikes_timed": 1, &"spikes_static": 1}
		var layout: SectionLayout = builder.build(plan, _rng(500 + seed_index))
		var again: SectionLayout = builder.build(plan, _rng(500 + seed_index))
		if again.grid.to_text() != layout.grid.to_text() or again.grid.spike_phase != layout.grid.spike_phase:
			same = false
		var plain: SectionPlan = SectionPlan.new()
		plain.room_count = 4
		var without: SectionLayout = builder.build(plain, _rng(500 + seed_index))
		if not SectionBuilder.is_passable(layout) or not _only_spikes_added(without.grid, layout.grid):
			only_added = false
		if int(layout.traps.get(&"spikes_timed", 0)) == 1:
			waves += 1
			if not _floor_reaches(layout.grid, layout.entrance, layout.exit):
				cut += 1
	check(same, "the same seed and plan give the same spikes and phases")
	check(only_added, "traps only add spikes: everything else is the section without traps, and it stays passable")
	check(waves >= SEEDS * 3 / 4, "a timed wave finds a tunnel of the main path in most sections (%d of %d)" % [waves, SEEDS])
	check(cut >= waves * 4 / 5, "a wave cuts its tunnel: without crossing it the gate is out of reach (%d of %d)" % [cut, waves])


func _test_config() -> void:
	var clean: ExperimentConfig = GameManager.load_config("clean")
	var soft: ExperimentConfig = GameManager.load_config("clean_soft")
	var full: ExperimentConfig = GameManager.load_config("full")
	check(not clean.spike_traps and not soft.spike_traps and full.spike_traps,
			"spike traps are off in the clean series (and so in the playtest), on in the full game")
	GameManager.config = clean
	var clean_director: Director = GameManager.make_director()
	GameManager.config = full
	var full_director: Director = GameManager.make_director()
	GameManager.config = GameManager.DEFAULT_CONFIG
	var traps: int = 0
	for i in PLANS:
		traps += 0 if clean_director.choose_next(_state(3 + i % 3, i)).traps.is_empty() else 1
	check(is_zero_approx(clean_director.settings.trap_chance) and full_director.settings.trap_chance > 0.0 and traps == 0,
			"the clean series' director buys no traps")


## A corridor with a timed wave: the strong bot waits for its moment and crosses
## unhurt; at a moment the strong bot waits, the weak one sometimes goes anyway.
func _test_bot() -> void:
	var strong: Dictionary = await _cross("strong", 2.0)
	check(strong["crossed"] and strong["hits"] == 0 and strong["waited"],
			"the strong bot waits before the wave and crosses it unhurt")
	var weak_crossing: Dictionary = await _cross("weak", 0.4)
	check(weak_crossing["crossed"], "the weak bot crosses the wave too")
	var choices: Dictionary = await _choices_at_bad_moment()
	check(choices["strong_go"] == 0 and choices["weak_go"] > 0 and choices["weak_wait"] > 0,
			"at a bad moment the strong bot always waits, the weak one sometimes goes (%d of %d)"
			% [choices["weak_go"], choices["weak_go"] + choices["weak_wait"]])


## Plays one crossing; returns {"crossed", "hits", "waited"}.
func _cross(profile_name: String, start_time: float) -> Dictionary:
	var game: Game = await _corridor_game()
	var hits: Array[int] = [0]
	game.player.health.damaged.connect(func(info: DamageInfo) -> void:
		if info.source_id == &"spikes_timed":
			hits[0] += 1)
	game.level.section_time = start_time
	game.add_bot(BotPlayer.load_profile(profile_name))
	var crossed: bool = false
	var waited_frames: int = 0
	SimulationSpeed.set_factor(4)
	for _i in 60 * 12:
		await get_tree().physics_frame
		var x: int = game.level.cell_at(game.player.global_position).x
		if x >= WAVE_X + WAVE_ROWS + 1:
			crossed = true
			break
		if x < WAVE_X and game.player.velocity.is_zero_approx():
			waited_frames += 1
	SimulationSpeed.reset()
	game.queue_free()
	await physics_frames(3)
	return {"crossed": crossed, "hits": hits[0], "waited": waited_frames > 10}


## The decision of both bots just before the wave, at a moment the wave will be up.
func _choices_at_bad_moment() -> Dictionary:
	var game: Game = await _corridor_game()
	var player: Player = game.player
	player.teleport(game.level.cell_center(Vector2i(WAVE_X - 2, 2)))
	var goal: Vector2 = game.gate.global_position
	var result: Dictionary = {"strong_go": 0, "weak_go": 0, "weak_wait": 0}
	var strong_bot: BotPlayer = game.add_bot(BotPlayer.load_profile("strong"))
	strong_bot.set_physics_process(false)
	var bad: float = -1.0
	for step in 64:
		game.level.section_time = step * _timed.get_period() / 64.0
		strong_bot._path = game.level.find_path(player.global_position, goal)
		strong_bot._path_index = 1
		strong_bot._spike_error_drawn = false
		if strong_bot._must_wait_for_spikes(player):
			bad = game.level.section_time
			break
	strong_bot.queue_free()
	var weak_bot: BotPlayer = game.add_bot(BotPlayer.load_profile("weak"))
	weak_bot.set_physics_process(false)
	game.level.section_time = bad
	weak_bot._path = game.level.find_path(player.global_position, goal)
	for _i in 200:
		weak_bot._path_index = 1
		weak_bot._spike_error_drawn = false
		if weak_bot._must_wait_for_spikes(player):
			result["weak_wait"] += 1
		else:
			result["weak_go"] += 1
	result["strong_go"] = 0 if bad >= 0.0 else 1
	game.queue_free()
	await physics_frames(3)
	return result


## The game with its section replaced by a corridor with a timed wave, no enemies,
## no pickups, the player at the west end and the gate far to the east.
func _corridor_game() -> Game:
	GameManager.start_run(BOT_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	for enemy: Enemy in game.get_enemies():
		enemy.queue_free()
	for pickup: Pickup in game.get_pickups():
		pickup.queue_free()
	var grid: LevelGrid = LevelGrid.from_text(CORRIDOR)
	for row in WAVE_ROWS:
		for y in range(1, 4):
			grid.set_timed_spikes(Vector2i(WAVE_X + row, y), -row * _timed.wave_step)
	game.level.build(grid)
	game.player.health.max_hp = BIG_HP
	game.player.health.reset()
	game.player.teleport(game.level.cell_center(Vector2i(2, 2)))
	game.gate.global_position = game.level.cell_center(Vector2i(23, 2))
	await physics_frames(2)
	return game


func _only_spikes_added(before: LevelGrid, after: LevelGrid) -> bool:
	if before.width != after.width or before.height != after.height:
		return false
	for y in before.height:
		for x in before.width:
			var cell: Vector2i = Vector2i(x, y)
			var was: LevelGrid.Cell = before.get_cell(cell)
			var now: LevelGrid.Cell = after.get_cell(cell)
			if was != now and not (was == LevelGrid.Cell.FLOOR and (now == LevelGrid.Cell.SPIKES or now == LevelGrid.Cell.SPIKES_TIMED)):
				return false
	return true


## Flood fill over plain floor only: can the exit be reached without crossing timed spikes?
func _floor_reaches(grid: LevelGrid, from: Vector2i, to: Vector2i) -> bool:
	var seen: Dictionary = {from: true}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		if cell == to:
			return true
		for step: Vector2i in LevelGrid.NEIGHBOURS:
			var next: Vector2i = cell + step
			if grid.is_floor(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return false


func _state(section_index: int, rng_seed: int) -> PlayerState:
	var state: PlayerState = PlayerState.new()
	state.section_index = section_index
	state.depth = section_index / 3
	state.skill = 0.62
	state.phases = [SectionPlan.PHASE_BUILD, SectionPlan.PHASE_BUILD] as Array[StringName]
	state.results = [0.6, 0.6] as Array[float]
	state.rng = _rng(rng_seed)
	return state


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
