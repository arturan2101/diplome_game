extends TestCase
## Headless test for experiment configs: the two series files, loading by name or
## path, the director without boss arenas and shrines in the clean series (on a copy
## of its settings), common chest weapons without scrolls, and the series in the log.

const GAME_SCENE: String = "res://main/main.tscn"
const FIRST_SEED: int = 900
const SEED_TRIES: int = 20
const PLANS: int = 200


func run() -> void:
	_test_files()
	_test_director()
	await _test_game_and_log()
	GameManager.config = GameManager.DEFAULT_CONFIG


func _test_files() -> void:
	var full: ExperimentConfig = GameManager.load_config("full")
	var clean: ExperimentConfig = GameManager.load_config("clean")
	check(full == GameManager.DEFAULT_CONFIG and full.series == "full" and full.boss_enabled and full.spells_enabled
			and full.rarity_enabled, "the full series has everything on and is the default")
	check(clean.series == "clean" and not clean.boss_enabled and not clean.spells_enabled and not clean.rarity_enabled,
			"the clean series has boss, spells and rarity off")
	check(GameManager.load_config("res://experiment/clean.tres") == clean, "a config also loads by its path")
	check(GameManager.load_config("no_such_series") == GameManager.DEFAULT_CONFIG, "an unknown name falls back to the full game")
	check(clean.to_dictionary() == {"boss": false, "spells": false, "rarity": false}, "the switches go to the log as a dictionary")


func _test_director() -> void:
	GameManager.config = GameManager.load_config("clean")
	var clean_director: Director = GameManager.make_director()
	GameManager.config = GameManager.DEFAULT_CONFIG
	var full_director: Director = GameManager.make_director()
	check(clean_director.settings.boss_every_depths == 0 and is_zero_approx(clean_director.settings.shrine_chance)
			and full_director.settings.boss_every_depths > 0 and full_director.settings.shrine_chance > 0.0,
			"the clean series turns boss arenas and shrines off on a copy of the director settings")
	var bosses: int = 0
	var shrines: int = 0
	for i in PLANS:
		var state: PlayerState = PlayerState.new()
		state.section_index = i
		state.depth = i % 6
		state.is_depth_end = i % 2 == 0
		state.rng.seed = i
		var plan: SectionPlan = clean_director.choose_next(state)
		bosses += 1 if plan.is_boss else 0
		shrines += plan.shrines
	check(bosses == 0 and shrines == 0, "clean plans have no boss and no shrine (%d bosses, %d shrines)" % [bosses, shrines])


func _test_game_and_log() -> void:
	GameManager.config = GameManager.load_config("clean")
	var chests: int = 0
	var rare: int = 0
	var scrolls: int = 0
	var record: Dictionary = {}
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	for run_seed in range(FIRST_SEED, FIRST_SEED + SEED_TRIES):
		GameManager.start_run(run_seed)
		var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
		game.death_screen_enabled = false
		add_child(game)
		await physics_frames(2)
		for pickup: Pickup in game.get_pickups():
			var chest: Chest = pickup as Chest
			if chest == null or chest.loot_weapon == null:
				continue
			chests += 1
			if chest.loot_weapon.rarity != null:
				rare += 1
			if chest.loot_spell != null:
				scrolls += 1
		if record.is_empty():
			record = Telemetry.end_section(false)
		game.queue_free()
		await physics_frames(3)
	Telemetry.write_enabled = write_was
	GameManager.config = GameManager.DEFAULT_CONFIG
	check(chests > 0 and rare == 0 and scrolls == 0,
			"in the clean series chests hold common weapons and no scrolls (%d chests)" % chests)
	check(record.get("series") == "clean" and record.get("config") == {"boss": false, "spells": false, "rarity": false},
			"every log line names the series and its switches")
