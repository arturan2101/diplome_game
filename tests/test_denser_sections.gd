extends TestCase
## Headless test (after stage 49): with ExperimentConfig.denser_sections every section
## but an arena gets x1.6 of its danger budget, the rest section x0.5 instead of x0.3,
## and every room of the main path after the first holds at least one enemy (the
## cheapest of the floor are added beyond the budget if needed); the health pack the
## playtest tuning took is back. Without it (the clean series) nothing changes.

const CLEAN: String = "res://experiment/clean.tres"
const PLANS: int = 80


func run() -> void:
	var saved: ExperimentConfig = GameManager.config
	_test_budget()
	_test_rooms_filled()
	_test_generation()
	GameManager.config = saved


func _director(config_path: String) -> Director:
	GameManager.config = load(config_path) as ExperimentConfig if config_path != "" else GameManager.DEFAULT_CONFIG
	return GameManager.make_director()


func _state(index: int, phases: Array[StringName], depth: int = 1) -> PlayerState:
	var state: PlayerState = PlayerState.new()
	state.section_index = index
	state.depth = depth
	state.phases = phases
	state.rng.seed = 4950 + index
	return state


func _test_budget() -> void:
	var full: Director = _director("")
	var settings: DirectorSettings = full.settings
	check(is_equal_approx(settings.section_budget_multiplier, GameManager.DENSE_SECTION_BUDGET)
			and is_equal_approx(settings.rest_multiplier, GameManager.DENSE_REST_MULTIPLIER) and settings.enemy_in_every_room
			and settings.health_packs_fewer == 0,
			"the full game makes sections denser and gives the health pack back")
	var clean: Director = _director(CLEAN)
	check(is_equal_approx(clean.settings.section_budget_multiplier, 1.0) and is_equal_approx(clean.settings.rest_multiplier, 0.3)
			and not clean.settings.enemy_in_every_room, "the clean series keeps the old numbers")
	# The same plan before the multiplier, then after it.
	var plan: SectionPlan = SectionPlan.new()
	# Above the depth floor, so only the multiplier counts.
	plan.budget = 30
	full.apply_depth_floor(plan, _state(5, []))
	var arena: SectionPlan = SectionPlan.new()
	arena.budget = 30
	arena.is_arena = true
	full.apply_depth_floor(arena, _state(5, []))
	check(plan.budget == 48 and arena.budget == 30, "a section's budget x1.6, an arena's unchanged (%d, %d)" % [plan.budget, arena.budget])


func _test_rooms_filled() -> void:
	var full: Director = _director("")
	var clean: Director = _director(CLEAN)
	var filled: bool = true
	var clean_short: int = 0
	var full_spawns: int = 0
	var clean_spawns: int = 0
	for i in PLANS:
		var phases: Array[StringName] = []
		if i % 3 == 0:
			phases = [SectionPlan.PHASE_BUILD, SectionPlan.PHASE_REST]
		var dense: SectionPlan = full.choose_next(_state(i, phases))
		var plain: SectionPlan = clean.choose_next(_state(i, phases))
		var wanted: int = dense.room_count - 1 + (1 if dense.combat_rooms > 0 else 0)
		filled = filled and dense.get_spawn_count() >= wanted
		if plain.get_spawn_count() < plain.room_count - 1:
			clean_short += 1
		full_spawns += dense.get_spawn_count()
		clean_spawns += plain.get_spawn_count()
	check(filled, "every plan of the full game has a spawn for every room after the first")
	check(clean_short > 0, "the clean series still has plans with too few (%d of %d)" % [clean_short, PLANS])
	check(full_spawns >= clean_spawns * 1.4, "the full game's sections hold far more enemies (%d against %d)" % [full_spawns, clean_spawns])


## In the built sections every room of the main path after the first holds an enemy.
func _test_generation() -> void:
	var full: Director = _director("")
	var builder: SectionBuilder = SectionBuilder.new()
	var empty_rooms: int = 0
	var rooms: int = 0
	for i in 40:
		var plan: SectionPlan = full.choose_next(_state(i, [], 2))
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 4960 + i
		var layout: SectionLayout = builder.build(plan, rng)
		var counts: Dictionary = {}
		for entry: Dictionary in layout.enemies:
			counts[int(entry["room"])] = int(counts.get(int(entry["room"]), 0)) + 1
		for room in range(1, layout.path_room_count):
			rooms += 1
			if int(counts.get(room, 0)) == 0:
				empty_rooms += 1
	check(rooms > 0 and empty_rooms == 0, "no room of the path after the first is empty (%d of %d)" % [empty_rooms, rooms])
