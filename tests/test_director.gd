extends TestCase
## Headless test for the directors: the budget formula, the tension wave, the
## frustration guard, adaptation to the player's trouble, the random control mode,
## the learned-director placeholder, and that every plan builds a passable section.

const SEEDS: int = 200


func run() -> void:
	_test_buy_enemies()
	_test_budget_formula()
	_test_tension_wave()
	_test_frustration_guard()
	_test_adaptation()
	_test_random_director()
	_test_learned_and_factory()
	_test_chests_and_arena()
	_test_plans_build_sections()


func _test_buy_enemies() -> void:
	var director: Director = Director.new()
	var cheapest: int = 1000
	for enemy_data: EnemyData in director.catalog.enemies:
		cheapest = mini(cheapest, enemy_data.danger_cost)
	var always_fits: bool = true
	for i in SEEDS:
		var budget: int = i % 15
		var mix: Dictionary = director.buy_enemies(budget, _rng(i))
		var cost: int = director.mix_cost(mix)
		if cost > budget or budget - cost >= cheapest:
			always_fits = false
	check(always_fits, "an enemy mix never costs more than the budget and leaves less than the cheapest enemy")
	var without_archers: Dictionary = director.buy_enemies(12, _rng(1), {&"archer": 0.0})
	check(not without_archers.has(&"archer") and not without_archers.is_empty(), "a zero weight removes an enemy type")
	check(director.buy_enemies(0, _rng(1)).is_empty(), "a zero budget buys nothing")


func _test_budget_formula() -> void:
	# Settings: base 14 at S = 0.62, skill factor 60, depth factor 0.5, phases 0.8 / 1.0 / 1.3 / 0.3, minimum 4.
	var director: RuleDirector = RuleDirector.new()
	var state: PlayerState = _state(0, [], [])
	state.skill = 0.62
	check(director.budget_for(state, SectionPlan.PHASE_BUILD) == 11, "first build-up section, average skill: round(14 * 0.8) = 11")
	state.phases = [SectionPlan.PHASE_BUILD]
	check(director.budget_for(state, SectionPlan.PHASE_BUILD) == 14, "second build-up section: round(14 * 1.0) = 14")
	check(director.budget_for(state, SectionPlan.PHASE_PEAK) == 18, "peak: round(14 * 1.3) = 18")
	check(director.budget_for(state, SectionPlan.PHASE_REST) == 4, "rest: round(14 * 0.3) = 4")
	state.skill = 0.7
	state.depth = 2
	check(director.budget_for(state, SectionPlan.PHASE_PEAK) == 26, "skill and depth raise the budget: round((14 + 4.8 + 1) * 1.3) = 26")
	state.skill = 0.5
	state.depth = 0
	check(director.budget_for(state, SectionPlan.PHASE_PEAK) == 9, "a weaker player gets less: round((14 - 7.2) * 1.3) = 9")
	var low: DirectorSettings = (load(Director.SETTINGS_PATH) as DirectorSettings).duplicate()
	low.budget_base = 2.0
	var low_state: PlayerState = _state(0, [], [])
	low_state.skill = 0.0
	check(RuleDirector.new(null, low).budget_for(low_state, SectionPlan.PHASE_BUILD) == low.min_budget,
			"the budget never drops below the minimum outside rest")


func _test_tension_wave() -> void:
	var director: RuleDirector = RuleDirector.new()
	var phases: Array[StringName] = []
	var results: Array[float] = []
	for i in 8:
		var plan: SectionPlan = director.choose_next(_state(i, phases, results))
		phases.append(plan.phase)
		results.append(0.8)
	check(phases == ([&"build", &"build", &"peak", &"rest", &"build", &"build", &"peak", &"rest"] as Array[StringName]),
			"phases go build, build, peak, rest and repeat")
	var rest_plan: SectionPlan = director.choose_next(_state(3, [&"build", &"build", &"peak"], [0.8, 0.8, 0.8]))
	var peak_plan: SectionPlan = director.choose_next(_state(2, [&"build", &"build"], [0.8, 0.8]))
	check(rest_plan.health_packs > peak_plan.health_packs and rest_plan.cover_density > peak_plan.cover_density
			and rest_plan.budget < peak_plan.budget, "a rest section has more health and cover and a smaller budget than a peak")
	check(rest_plan.corridor_width > peak_plan.corridor_width and rest_plan.room_count < peak_plan.room_count,
			"rest is short and wide, peak is long and narrow")
	check(director.mix_cost(peak_plan.enemy_mix) <= peak_plan.budget, "the enemy mix fits the budget")


func _test_frustration_guard() -> void:
	var director: RuleDirector = RuleDirector.new()
	var low_hp: PlayerState = _state(1, [&"build"], [0.8])
	low_hp.hp_fraction = 0.2
	check(director.choose_next(low_hp).phase == SectionPlan.PHASE_REST, "HP below 25% forces a rest section")
	var bad_streak: PlayerState = _state(2, [&"build", &"build"], [0.2, 0.1])
	check(director.choose_next(bad_streak).phase == SectionPlan.PHASE_REST, "two sections in a row with p < 0.3 force a rest")
	var one_bad: PlayerState = _state(2, [&"build", &"build"], [0.8, 0.1])
	check(director.choose_next(one_bad).phase == SectionPlan.PHASE_PEAK, "one bad section does not break the wave")
	var after_rest: PlayerState = _state(3, [&"build", &"build", &"rest"], [0.2, 0.1, 0.25])
	check(director.choose_next(after_rest).phase == SectionPlan.PHASE_BUILD, "after a forced rest the wave starts again with build-up")
	var hurt: PlayerState = _state(1, [&"build"], [0.8])
	hurt.hp_fraction = 0.4
	var healthy: PlayerState = _state(1, [&"build"], [0.8])
	check(director.choose_next(hurt).health_packs > director.choose_next(healthy).health_packs,
			"a hurt player gets an extra health pack")


func _test_adaptation() -> void:
	var director: RuleDirector = RuleDirector.new()
	var archers_for_weak: int = 0
	var archers_for_strong: int = 0
	for i in SEEDS:
		var weak: PlayerState = _state(1, [&"build"], [0.3], i)
		weak.skill = 0.2
		weak.recent_damage = {&"archer": 40, &"skeleton": 10}
		archers_for_weak += int(director.choose_next(weak).enemy_mix.get(&"archer", 0))
		var strong: PlayerState = _state(1, [&"build"], [0.9], i)
		strong.skill = 0.9
		strong.recent_damage = {&"archer": 40, &"skeleton": 10}
		archers_for_strong += int(director.choose_next(strong).enemy_mix.get(&"archer", 0))
	check(archers_for_weak < archers_for_strong,
			"hurt by archers: a weak player meets fewer of them than a strong one (%d vs %d over %d plans)" % [archers_for_weak, archers_for_strong, SEEDS])
	var weak_vs_archers: PlayerState = _state(1, [&"build"], [0.3])
	weak_vs_archers.skill = 0.2
	weak_vs_archers.recent_damage = {&"archer": 40}
	var plan: SectionPlan = director.choose_next(weak_vs_archers)
	check(&"cover" in plan.preferred_tags and plan.cover_density >= 0.9, "against archers a weak player gets cover")
	var weak_vs_pits: PlayerState = _state(1, [&"build"], [0.3])
	weak_vs_pits.skill = 0.2
	weak_vs_pits.recent_damage = {&"pit": 60, &"skeleton": 10}
	check(&"hazard" in director.choose_next(weak_vs_pits).avoided_tags, "a weak player who keeps falling gets fewer hazard rooms")
	var first: Dictionary = director.choose_next(_state(4, [&"build"], [0.5], 77)).to_dictionary()
	var second: Dictionary = director.choose_next(_state(4, [&"build"], [0.5], 77)).to_dictionary()
	check(first == second, "the same state and generator give the same plan")


func _test_random_director() -> void:
	var director: RandomDirector = RandomDirector.new()
	var in_range: bool = true
	var seen_budgets: Dictionary = {}
	for i in SEEDS:
		var plan: SectionPlan = director.choose_next(_state(i % 6, [], [], i))
		seen_budgets[plan.budget] = true
		if plan.budget < director.settings.random_budget_min or plan.budget > director.settings.random_budget_max \
				or plan.phase != SectionPlan.PHASE_RANDOM or director.mix_cost(plan.enemy_mix) > plan.budget \
				or plan.corridor_width < 2 or plan.corridor_width > 4 or plan.room_count < 3 or plan.room_count > 5:
			in_range = false
	check(in_range, "random plans stay inside the allowed ranges and are marked as phase random")
	check(seen_budgets.size() >= 6, "random budgets really vary (%d different values)" % seen_budgets.size())
	var good_player: PlayerState = _state(3, [], [0.9, 0.9, 0.9], 5)
	good_player.skill = 0.9
	var bad_player: PlayerState = _state(3, [], [0.1, 0.1, 0.1], 5)
	bad_player.skill = 0.1
	bad_player.hp_fraction = 0.1
	check(director.choose_next(good_player).to_dictionary() == director.choose_next(bad_player).to_dictionary(),
			"the random director ignores how the player is doing")


func _test_learned_and_factory() -> void:
	# Without a parameter file (a path that does not exist) the learned director falls back to the rules.
	var learned: LearnedDirector = LearnedDirector.new(null, null, "res://no_such_parameters.json")
	var rule: RuleDirector = RuleDirector.new()
	check(not learned.is_trained() and learned.choose_next(_state(2, [&"build", &"build"], [0.8, 0.8], 9)).to_dictionary()
			== rule.choose_next(_state(2, [&"build", &"build"], [0.8, 0.8], 9)).to_dictionary(),
			"the untrained learned director plans like the rule director")
	var manager: Node = (load("res://autoload/game_manager.gd") as GDScript).new()
	manager.director_mode = manager.DirectorMode.RANDOM
	var random_ok: bool = manager.make_director() is RandomDirector and manager.get_mode_name() == "RANDOM"
	manager.director_mode = manager.DirectorMode.RULES
	var rules_ok: bool = manager.make_director() is RuleDirector and manager.get_mode_name() == "RULES"
	manager.director_mode = manager.DirectorMode.LEARNED
	var learned_ok: bool = manager.make_director() is LearnedDirector and manager.get_mode_name() == "LEARNED"
	manager.director_mode = manager.DirectorMode.EXPLORE
	var explore_ok: bool = manager.make_director() is ExploreDirector and manager.get_mode_name() == "EXPLORE"
	check(random_ok and rules_ok and learned_ok and explore_ok, "GameManager creates the director of the selected mode")
	manager.free()


func _test_chests_and_arena() -> void:
	var director: RuleDirector = RuleDirector.new()
	var counts: Array[int] = [0, 0, 0]
	var branches_ok: bool = true
	for i in SEEDS:
		var plan: SectionPlan = director.choose_next(_state(1, [&"build"], [0.7], i))
		counts[plan.chests] += 1
		if plan.side_branches > plan.chests or plan.is_arena:
			branches_ok = false
	check(counts[1] > counts[0] and counts[1] > counts[2] and counts[0] > 0 and counts[2] > 0,
			"0-2 chests per section, one is the most common (%s)" % [counts])
	check(branches_ok, "side branches never outnumber chests; ordinary sections are not arenas")
	var depth_end: PlayerState = _state(3, [&"build", &"build", &"peak"], [0.7, 0.7, 0.7])
	depth_end.is_depth_end = true
	var arena: SectionPlan = director.choose_next(depth_end)
	check(arena.is_arena and arena.phase == SectionPlan.PHASE_ARENA and arena.room_count == director.settings.arena_rooms
			and arena.waves == (2 if arena.budget >= director.settings.arena_two_waves_budget else 1),
			"the last section of a depth is an arena with 1-2 waves")
	check(director.choose_next(_state(4, [&"build", &"build", &"peak", &"arena"], [0.7, 0.7, 0.7, 0.7])).phase == SectionPlan.PHASE_REST,
			"a rest follows the arena")
	var random_end: PlayerState = _state(3, [], [], 4)
	random_end.is_depth_end = true
	check(RandomDirector.new().choose_next(random_end).is_arena, "the random director also ends a depth with an arena")


func _test_plans_build_sections() -> void:
	var builder: SectionBuilder = SectionBuilder.new()
	var impassable: int = 0
	var directors: Array[Director] = [RandomDirector.new(), RuleDirector.new(), LearnedDirector.new()]
	for director: Director in directors:
		var phases: Array[StringName] = []
		var results: Array[float] = []
		for i in 12:
			var state: PlayerState = _state(i, phases, results, 1000 + i)
			state.depth = i / 3
			state.is_depth_end = i % 3 == 2
			state.skill = 0.3 + 0.05 * i
			var plan: SectionPlan = director.choose_next(state)
			phases.append(plan.phase)
			results.append(0.7)
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = hash([555, i])
			if not SectionBuilder.is_passable(builder.build(plan, rng)):
				impassable += 1
	check(impassable == 0, "every plan of every director builds a passable section (%d fail)" % impassable)


func _state(section_index: int, phases: Array, results: Array, rng_seed: int = 1) -> PlayerState:
	var state: PlayerState = PlayerState.new()
	state.section_index = section_index
	state.rng = _rng(rng_seed)
	for phase: StringName in phases:
		state.phases.append(phase)
	for result: float in results:
		state.results.append(result)
	return state


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
