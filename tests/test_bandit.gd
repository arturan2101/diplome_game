extends TestCase
## Headless test for the learned director's parts: the context features, the 27
## actions and how they fill a plan, the exploring director, the LinUCB choice with
## hand-made parameters, the fall back to the rules without parameters, the trained
## parameter file (if it exists) and the action and context in the log.

const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const PLANS: int = 600


func run() -> void:
	_test_features()
	_test_actions()
	_test_explore()
	_test_learned()
	await _test_log()


func _state(i: int) -> PlayerState:
	var state: PlayerState = PlayerState.new()
	state.section_index = i
	state.depth = i % 8
	state.hp_fraction = float(i % 10) / 10.0
	state.skill = 0.3 + float(i % 7) / 10.0
	state.rng.seed = i
	return state


func _test_features() -> void:
	var state: PlayerState = _state(3)
	state.results = [0.4, 0.9] as Array[float]
	state.recent_damage = {&"skeleton": 30, &"archer": 10, &"pit": 10}
	var x: PackedFloat32Array = BanditContext.features(state)
	check(x.size() == BanditContext.FEATURE_NAMES.size() and is_equal_approx(x[0], 1.0), "the context starts with the bias 1")
	var inside: bool = true
	for value: float in x:
		if value < 0.0 or value > 1.0:
			inside = false
	check(inside, "every feature lies between 0 and 1")
	check(is_equal_approx(x[4], 0.9) and is_equal_approx(x[5], 0.6) and is_equal_approx(x[6], 0.2) and is_zero_approx(x[7]),
			"last result and the enemies' shares of the recent damage (hazards count in the total)")
	check(is_equal_approx(BanditContext.features(_state(1))[4], _state(1).skill), "before the first section the last result is the skill")


func _test_actions() -> void:
	var director: Director = Director.new()
	var settings: DirectorSettings = director.settings
	var count: int = BanditActions.count(settings)
	var round_trip: bool = true
	for index in count:
		var action: Dictionary = BanditActions.decode(index, settings)
		if BanditActions.encode(action["type"], action["level"], action["enemy"], settings) != index:
			round_trip = false
	check(count == 27 and round_trip, "27 actions: section type x budget level x dominant enemy")
	check(BanditActions.label(BanditActions.encode(SectionPlan.PHASE_PEAK, 2, &"archer", settings), settings) == "peak/high/archer",
			"actions have readable names")
	var dominant: int = 0
	var other: int = 0
	var fills: bool = true
	for i in PLANS:
		var state: PlayerState = _state(i)
		var plan: SectionPlan = director.new_plan(state)
		var index: int = BanditActions.encode(SectionPlan.PHASE_REST, 1, &"beetle", settings)
		BanditActions.apply(director, plan, state, index)
		var budget: int = settings.bandit_budget_levels[1] + roundi(settings.budget_depth_factor * state.depth)
		if plan.action != index or plan.budget != budget or (not plan.is_arena and plan.phase != SectionPlan.PHASE_REST):
			fills = false
		dominant += int(plan.enemy_mix.get(&"beetle", 0))
		other += int(plan.enemy_mix.get(&"skeleton", 0)) + int(plan.enemy_mix.get(&"archer", 0))
	check(fills, "an action sets the plan's action, phase and budget (level plus depth growth)")
	check(dominant > other, "the dominant enemy is bought more often than the other two together (%d vs %d)" % [dominant, other])


func _test_explore() -> void:
	var director: ExploreDirector = ExploreDirector.new()
	var seen: Dictionary = {}
	var logged: bool = true
	for i in PLANS:
		var plan: SectionPlan = director.choose_next(_state(i))
		seen[plan.action] = true
		if plan.context.size() != BanditContext.FEATURE_NAMES.size():
			logged = false
	check(seen.size() == BanditActions.count(director.settings) and logged, "exploring tries all 27 actions and keeps the context")
	check(director.choose_next(_state(42)).action == director.choose_next(_state(42)).action, "the same seed gives the same random action")


func _test_learned() -> void:
	var untrained: LearnedDirector = LearnedDirector.new(null, null, "res://no_such_file.json")
	var rules: RuleDirector = RuleDirector.new()
	check(not untrained.is_trained() and JSON.stringify(untrained.choose_next(_state(7)).to_dictionary())
			== JSON.stringify(rules.choose_next(_state(7)).to_dictionary()), "without parameters it plans like the rules director")
	var count: int = BanditActions.count(untrained.settings)
	var features: int = BanditContext.FEATURE_NAMES.size()
	var theta: Array = []
	for action in count:
		var row: Array = []
		row.resize(features)
		row.fill(0.0)
		theta.append(row)
	var low: int = BanditActions.encode(SectionPlan.PHASE_REST, 0, &"skeleton", untrained.settings)
	var high: int = BanditActions.encode(SectionPlan.PHASE_PEAK, 2, &"archer", untrained.settings)
	theta[high][1] = 1.0
	theta[low][0] = 1.0
	theta[low][1] = -1.0
	var learned: LearnedDirector = LearnedDirector.new(null, null, "res://no_such_file.json")
	var data: Dictionary = {"features": Array(BanditContext.FEATURE_NAMES), "theta": theta, "alpha": 0.0}
	check(learned.load_parameters(data) and learned.is_trained(), "parameters in the trainer's format load")
	var strong: PlayerState = _state(5)
	strong.skill = 0.9
	var weak: PlayerState = _state(5)
	weak.skill = 0.2
	check(learned.choose_next(strong).action == high and learned.choose_next(weak).action == low,
			"the action with the best expected reward wins: high budget for a skilled player, rest for a weak one")
	var bad: Dictionary = data.duplicate()
	bad["features"] = ["bias", "skill"]
	check(not learned.load_parameters(bad) and not learned.is_trained(), "parameters for other features are refused")
	var identity: Array = []
	for i in features:
		var row: Array = []
		row.resize(features)
		row.fill(0.0)
		row[i] = 1.0
		identity.append(row)
	var bonus: Dictionary = data.duplicate()
	bonus["alpha"] = 0.5
	var inverses: Array = []
	for action in count:
		inverses.append(identity)
	bonus["a_inverse"] = inverses
	learned.load_parameters(bonus)
	var x: PackedFloat32Array = BanditContext.features(strong)
	var length: float = 0.0
	for value: float in x:
		length += value * value
	check(is_equal_approx(learned.score(high, x), x[1] + 0.5 * sqrt(length)), "LinUCB adds alpha * sqrt(x^T A^-1 x) for exploration")
	if FileAccess.file_exists(LearnedDirector.PARAMETERS_PATH):
		check(LearnedDirector.new().is_trained(), "the trained parameter file fits the game's features and actions")


func _test_log() -> void:
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = Vector2(-400.0, -400.0)
	add_child(player)
	await physics_frames(2)
	var plan: SectionPlan = ExploreDirector.new().choose_next(_state(9))
	var layout: SectionLayout = SectionLayout.new()
	layout.reference_time = 30.0
	Telemetry.begin_section(plan, layout, player)
	var record: Dictionary = Telemetry.end_section(false)
	Telemetry.write_enabled = write_was
	check(record.get("action") == plan.action and (record.get("context") as Array).size() == BanditContext.FEATURE_NAMES.size(),
			"the log has the action and the context of every section")
	player.queue_free()
	await physics_frames(2)
