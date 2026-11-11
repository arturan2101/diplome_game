extends Node
## Plays many runs with the bot, without a window and faster than real time, to fill
## the logs for comparing director modes (and later for training the learned one).
## Run:
##   godot --headless --path . res://tools/simulate.tscn -- --runs=20 --mode=rules --seed=100
## Arguments (all optional): --runs=N (default 5), --mode=random|rules|learned,
## --seed=N (seed of the first run; the next runs use N+1, N+2, ...),
## --sections=N (stop a run after N sections, default 12), --speed=N (default 8).
## Each section is written to the usual log, user://logs/<session>.jsonl.

const GAME_SCENE: PackedScene = preload("res://main/main.tscn")
const RUNS_ARG: String = "--runs="
const SECTIONS_ARG: String = "--sections="
const SPEED_ARG: String = "--speed="
const SEED_ARG: String = "--seed="
const DEFAULT_RUNS: int = 5
const DEFAULT_SECTIONS: int = 12
const DEFAULT_SPEED: int = 8
const DEFAULT_FIRST_SEED: int = 1
## A run that takes longer than this many seconds of game time is cut off.
const RUN_TIME_LIMIT: float = 1200.0

var _runs: int = DEFAULT_RUNS
var _max_sections: int = DEFAULT_SECTIONS
var _first_seed: int = DEFAULT_FIRST_SEED


func _ready() -> void:
	_runs = _int_argument(RUNS_ARG, DEFAULT_RUNS)
	_max_sections = _int_argument(SECTIONS_ARG, DEFAULT_SECTIONS)
	_first_seed = _int_argument(SEED_ARG, DEFAULT_FIRST_SEED)
	SimulationSpeed.set_factor(_int_argument(SPEED_ARG, DEFAULT_SPEED))
	print("Simulating %d runs, mode %s, log %s" % [_runs, GameManager.get_mode_name(), Telemetry.get_log_path()])
	var total_sections: int = 0
	var deaths: int = 0
	for i in _runs:
		var cleared: int = await _play_run(_first_seed + i)
		total_sections += cleared
		if GameManager.is_run_over:
			deaths += 1
		print("run %d (seed %d): %d sections cleared, depth %d, %s" % [
				i + 1, _first_seed + i, cleared, GameManager.depth, "died" if GameManager.is_run_over else "stopped"])
	SimulationSpeed.reset()
	print("Done: %d runs, %.1f sections per run on average, %d deaths" % [
			_runs, float(total_sections) / float(maxi(_runs, 1)), deaths])
	get_tree().quit()


## Plays one run with the bot. Returns how many sections were cleared.
func _play_run(run_seed: int) -> int:
	GameManager.start_run(run_seed)
	var game: Game = GAME_SCENE.instantiate() as Game
	game.restart_on_death = false
	add_child(game)
	game.add_bot()
	var time_left: float = RUN_TIME_LIMIT
	while time_left > 0.0 and not GameManager.is_run_over and GameManager.section_index < _max_sections:
		await get_tree().physics_frame
		time_left -= get_physics_process_delta_time()
	var cleared: int = GameManager.section_index
	game.queue_free()
	await get_tree().physics_frame
	await get_tree().physics_frame
	return cleared


func _int_argument(prefix: String, default_value: int) -> int:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix) and arg.trim_prefix(prefix).is_valid_int():
			return arg.trim_prefix(prefix).to_int()
	return default_value
