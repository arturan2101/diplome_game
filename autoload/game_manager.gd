extends Node
## Global run state, registered as the autoload "GameManager".
## Owns the run seed and every random number generator, so a run can be replayed:
## the same seed and the same director decisions produce the same tunnel.
## Also keeps what belongs to the whole run: section and depth counters, coins,
## kills, and the loadout chosen before the run.

## Emitted when a new run starts (counters are already reset).
signal run_started
## Emitted when the player moves on to the next section.
signal section_changed(section_index: int, depth: int)
signal coins_changed(coins: int)
## Emitted once when the player dies; killing_blow is the last hit.
signal player_died(killing_blow: DamageInfo)

## Who plans the sections. The player never sees the mode; it is written to the log.
enum DirectorMode { RANDOM, RULES, LEARNED }

## Launch argument that picks the director mode, e.g. `--mode=rules`.
const MODE_ARG_PREFIX: String = "--mode="
## Launch argument that fixes the seed, e.g. `--seed=12345`.
const SEED_ARG_PREFIX: String = "--seed="
## Launch argument that picks the experiment series, e.g. `--config=clean`
## (a name in CONFIG_DIR or a full res:// path).
const CONFIG_ARG_PREFIX: String = "--config="
const CONFIG_DIR: String = "res://experiment"
const DEFAULT_CONFIG: ExperimentConfig = preload("res://experiment/full.tres")
## Pass this to start_run() to pick a random seed.
const RANDOM_SEED: int = -1
## Random seeds are picked below this value, so they stay short to type and log.
const MAX_RANDOM_SEED: int = 1_000_000_000
## Seconds between the player's death and the death screen.
const DEATH_SCREEN_DELAY: float = 1.0
## A depth lasts this many sections (picked per depth from the run seed).
const MIN_SECTIONS_PER_DEPTH: int = 3
const MAX_SECTIONS_PER_DEPTH: int = 4
const DEFAULT_WEAPON: WeaponData = preload("res://combat/weapons/sword.tres")
const DEFAULT_SKILL: SkillData = preload("res://combat/skills/dash.tres")

## Director mode of the next runs (debug menu or --mode=).
var director_mode: DirectorMode = DirectorMode.RULES
## Which parts of the game the runs include (--config=); the whole game by default.
var config: ExperimentConfig = DEFAULT_CONFIG
## Seed for the next runs: from --seed= or the debug menu. RANDOM_SEED = a new random
## seed for every run.
var forced_seed: int = RANDOM_SEED
## Seed of the current run. Always written to the log.
var run_seed: int = 0
## Randomness during play (damage spread, drops).
## Section generation must use make_section_rng() instead.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Index of the current section in the run, starting at 0.
var section_index: int = 0
## Current depth, starting at 0. Grows every 3-4 sections.
var depth: int = 0
var coins: int = 0
var kills: int = 0
## Seconds played in the current run (the game scene adds to it).
var run_time: float = 0.0
## Loadout chosen before the run (the menu sets these).
var starting_weapon: WeaponData = DEFAULT_WEAPON
var starting_skill: SkillData = DEFAULT_SKILL
## True from the player's death until the next run starts.
var is_run_over: bool = false

var _sections_into_depth: int = 0


func _ready() -> void:
	director_mode = _mode_from_command_line()
	forced_seed = _seed_from_command_line()
	config = _config_from_command_line()
	start_run()


## A new director for the current mode. The game asks for one per run.
func make_director() -> Director:
	var director: Director = null
	match director_mode:
		DirectorMode.RANDOM:
			director = RandomDirector.new()
		DirectorMode.LEARNED:
			director = LearnedDirector.new()
		_:
			director = RuleDirector.new()
	_apply_config(director)
	return director


## The experiment series as the director sees it: no boss arenas and no shrines when
## they are switched off. Works on a copy, the shared settings resource stays as is.
func _apply_config(director: Director) -> void:
	if config.boss_enabled and config.spells_enabled:
		return
	director.settings = director.settings.duplicate() as DirectorSettings
	if not config.boss_enabled:
		director.settings.boss_every_depths = 0
	if not config.spells_enabled:
		director.settings.shrine_chance = 0.0


## An experiment config by name ("clean" means CONFIG_DIR/clean.tres) or by path;
## the default config if there is no such file.
func load_config(name_or_path: String) -> ExperimentConfig:
	var path: String = name_or_path
	if not path.begins_with("res://"):
		path = CONFIG_DIR.path_join(name_or_path + ".tres")
	var loaded: ExperimentConfig = load(path) as ExperimentConfig if ResourceLoader.exists(path) else null
	if loaded == null:
		push_warning("No experiment config %s, using %s" % [name_or_path, DEFAULT_CONFIG.series])
		return DEFAULT_CONFIG
	return loaded


## Name of the director mode as written to the log: RANDOM, RULES or LEARNED.
func get_mode_name() -> String:
	return DirectorMode.keys()[director_mode]


## Starts a new run with fresh counters. Without an argument the seed is forced_seed,
## or a random one if no seed is forced.
func start_run(new_seed: int = RANDOM_SEED) -> void:
	if new_seed == RANDOM_SEED:
		new_seed = forced_seed
	if new_seed == RANDOM_SEED:
		var seeder: RandomNumberGenerator = RandomNumberGenerator.new()
		seeder.randomize()
		new_seed = seeder.randi_range(0, MAX_RANDOM_SEED - 1)
	run_seed = new_seed
	rng.seed = run_seed
	section_index = 0
	depth = 0
	coins = 0
	kills = 0
	run_time = 0.0
	is_run_over = false
	_sections_into_depth = 0
	print("Run seed: %d" % run_seed)
	run_started.emit()
	coins_changed.emit(coins)


## Starts a new run and reloads the current scene (the "play again" button).
func restart_run() -> void:
	start_run()
	get_tree().reload_current_scene()


## Results of the current run for the death screen.
func get_run_summary() -> Dictionary:
	return {
		"seed": run_seed,
		"depth": depth,
		"sections": section_index,
		"time": run_time,
		"kills": kills,
		"coins": coins,
	}


## Called by the game scene when the player goes through a gate.
func advance_section() -> void:
	section_index += 1
	_sections_into_depth += 1
	if _sections_into_depth >= sections_in_depth(depth):
		depth += 1
		_sections_into_depth = 0
	section_changed.emit(section_index, depth)


## How many sections the given depth has: 3 or 4, fixed by the run seed.
func sections_in_depth(depth_index: int) -> int:
	var spread: int = MAX_SECTIONS_PER_DEPTH - MIN_SECTIONS_PER_DEPTH + 1
	return MIN_SECTIONS_PER_DEPTH + absi(hash([run_seed, "depth", depth_index])) % spread


## True if the current section is the last of its depth (the arena).
func is_last_section_of_depth() -> bool:
	return _sections_into_depth == sections_in_depth(depth) - 1


## Returns a new generator for the bot's own choices in this run (only bots use it).
func make_bot_rng() -> RandomNumberGenerator:
	var bot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	bot_rng.seed = hash([run_seed, "bot"])
	return bot_rng


## Returns a new generator for the loot of one section (what chests hold).
## Separate from the section generator, so loot does not change the tunnels.
func make_loot_rng(index: int) -> RandomNumberGenerator:
	var loot_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	loot_rng.seed = hash([run_seed, "loot", index])
	return loot_rng


func add_coins(amount: int) -> void:
	coins += amount
	coins_changed.emit(coins)


func add_kill() -> void:
	kills += 1


## Called by the player when it dies; killing_blow is the last hit.
## The run is over; listeners (game scene, telemetry) react to player_died.
func report_player_death(killing_blow: DamageInfo) -> void:
	if is_run_over:
		return
	is_run_over = true
	player_died.emit(killing_blow)


## Returns a new generator for building one section. It depends only on the run seed
## and the section index, so randomness used in combat never changes a section.
func make_section_rng(index: int) -> RandomNumberGenerator:
	var section_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	section_rng.seed = hash([run_seed, index])
	return section_rng


## Returns a new generator for the director's choices about one section.
## Separate from the section generator, so both stay reproducible on their own.
func make_director_rng(index: int) -> RandomNumberGenerator:
	var director_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	director_rng.seed = hash([run_seed, "director", index])
	return director_rng


## Reads --config=<name or path> from the launch arguments; the default config if absent.
func _config_from_command_line() -> ExperimentConfig:
	for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if arg.begins_with(CONFIG_ARG_PREFIX):
			return load_config(arg.trim_prefix(CONFIG_ARG_PREFIX))
	return DEFAULT_CONFIG


## Reads --mode=random|rules|learned from the launch arguments; RULES if absent.
func _mode_from_command_line() -> DirectorMode:
	for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if not arg.begins_with(MODE_ARG_PREFIX):
			continue
		var value: String = arg.trim_prefix(MODE_ARG_PREFIX).to_upper()
		if DirectorMode.has(value):
			return DirectorMode[value]
		push_warning("Ignoring unknown director mode: %s" % arg)
	return DirectorMode.RULES


## Reads --seed=N from the launch arguments, or returns RANDOM_SEED if it is absent.
func _seed_from_command_line() -> int:
	for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if not arg.begins_with(SEED_ARG_PREFIX):
			continue
		var value: String = arg.trim_prefix(SEED_ARG_PREFIX)
		if value.is_valid_int():
			return value.to_int()
		push_warning("Ignoring invalid seed argument: %s" % arg)
	return RANDOM_SEED
