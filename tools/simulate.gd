extends Node
## Plays many runs with a bot, without a window and faster than real time, to fill the
## logs for comparing director modes (and later for training the learned one).
## Run:
##   godot --headless --path . res://tools/simulate.tscn -- --bot=mid --mode=rules --runs=30 --seed=100
## Arguments (all optional):
##   --bot=weak|mid|strong   bot profile (default mid)
##   --mode=random|rules|learned
##   --runs=N                number of runs (default 5)
##   --seed=N                seed of the first run; the next runs use N+1, N+2, ...
##   --sections=N            stop a run after N sections (default 30)
##   --speed=N               times faster than real time (default 8)
##   --log-dir=NAME          write the logs to user://sim_logs/NAME instead of user://logs
##   --calibrate             also measure the time the bot spends in each room and in the
##                           tunnels, written to user://calibration/<session>.json
## Each section is written to the usual JSONL log.

const GAME_SCENE: PackedScene = preload("res://main/main.tscn")
const RUNS_ARG: String = "--runs="
const SECTIONS_ARG: String = "--sections="
const SPEED_ARG: String = "--speed="
const SEED_ARG: String = "--seed="
const LOG_DIR_ARG: String = "--log-dir="
const CALIBRATE_ARG: String = "--calibrate"
const SIM_LOGS_ROOT: String = "user://sim_logs"
const CALIBRATION_DIR: String = "user://calibration"
const DEFAULT_RUNS: int = 5
const DEFAULT_SECTIONS: int = 30
const DEFAULT_SPEED: int = 8
const DEFAULT_FIRST_SEED: int = 1
## A run that takes longer than this many seconds of game time is cut off.
const RUN_TIME_LIMIT: float = 3600.0
## A section that takes longer than this is reported as stuck and the run is cut off.
const STUCK_TIME: float = 600.0

var _runs: int = DEFAULT_RUNS
var _max_sections: int = DEFAULT_SECTIONS
var _first_seed: int = DEFAULT_FIRST_SEED
var _profile: BotProfile = null
var _calibrate: bool = false
## Calibration: one entry per finished section {"rooms": {name: [seconds]}, "tunnel": s, "tunnels": n, "time": s}.
var _calibration: Array[Dictionary] = []
var _room_time: Dictionary = {}
var _tunnel_time: float = 0.0
var _section_time: float = 0.0
var _game: Game = null


func _ready() -> void:
	_runs = _int_argument(RUNS_ARG, DEFAULT_RUNS)
	_max_sections = _int_argument(SECTIONS_ARG, DEFAULT_SECTIONS)
	_first_seed = _int_argument(SEED_ARG, DEFAULT_FIRST_SEED)
	_calibrate = CALIBRATE_ARG in OS.get_cmdline_user_args()
	_profile = BotPlayer.profile_from_command_line()
	if _profile == null:
		_profile = BotPlayer.DEFAULT_PROFILE
	var log_dir: String = _string_argument(LOG_DIR_ARG, "")
	if log_dir != "":
		Telemetry.log_directory = SIM_LOGS_ROOT.path_join(log_dir)
	SimulationSpeed.set_factor(_int_argument(SPEED_ARG, DEFAULT_SPEED))
	print("Simulating %d runs, bot %s, mode %s, log %s" % [_runs, _profile.id, GameManager.get_mode_name(), Telemetry.get_log_path()])
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
	if _calibrate:
		_write_calibration()
	print("Done: %d runs, %.1f sections per run on average, %d deaths" % [
			_runs, float(total_sections) / float(maxi(_runs, 1)), deaths])
	get_tree().quit()


func _physics_process(delta: float) -> void:
	if not _calibrate or _game == null or _game.layout == null or GameManager.is_run_over:
		return
	_section_time += delta
	var cell: Vector2i = _game.level.cell_at(_game.player.global_position)
	for i in _game.layout.room_rects.size():
		if _game.layout.room_rects[i].has_point(cell):
			_room_time[i] = float(_room_time.get(i, 0.0)) + delta
			return
	_tunnel_time += delta


## Plays one run with the bot. Returns how many sections were cleared.
func _play_run(run_seed: int) -> int:
	GameManager.start_run(run_seed)
	_game = GAME_SCENE.instantiate() as Game
	_game.death_screen_enabled = false
	_game.section_started.connect(_on_section_started)
	_game.section_finished.connect(_on_section_finished)
	add_child(_game)
	_game.add_bot(_profile)
	var time_left: float = RUN_TIME_LIMIT
	var section_seen: int = -1
	var section_time: float = 0.0
	while time_left > 0.0 and not GameManager.is_run_over and GameManager.section_index < _max_sections:
		await get_tree().physics_frame
		var delta: float = get_physics_process_delta_time()
		time_left -= delta
		if GameManager.section_index != section_seen:
			section_seen = GameManager.section_index
			section_time = 0.0
		section_time += delta
		if section_time > STUCK_TIME:
			_report_stuck()
			break
	var cleared: int = GameManager.section_index
	_game.queue_free()
	_game = null
	await get_tree().physics_frame
	await get_tree().physics_frame
	return cleared


## Prints what the bot was doing when a section took far too long.
func _report_stuck() -> void:
	var player: Player = _game.player
	var enemies: PackedStringArray = PackedStringArray()
	for enemy: Enemy in _game.get_enemies():
		enemies.append("%s@%s(%s, path %d)" % [enemy.data.id, _game.level.cell_at(enemy.global_position),
				Enemy.State.keys()[enemy.state], _game.level.find_path(player.global_position, enemy.global_position).size()])
	print("STUCK in section %d (seed %d): player at %s hp %d (moving %s, velocity %s, input %s), gate %s at %s (path %d), arena sealed %s, enemies: %s" % [
			GameManager.section_index, GameManager.run_seed, _game.level.cell_at(player.global_position), player.health.hp,
			player.is_physics_processing(), player.velocity.round(),
			Input.get_vector("move_left", "move_right", "move_up", "move_down").snapped(Vector2(0.01, 0.01)),
			"open" if _game.gate.is_open else "closed", _game.level.cell_at(_game.gate.global_position),
			_game.level.find_path(player.global_position, _game.gate.global_position).size(),
			_game.is_arena_sealed(), ", ".join(enemies)])


func _on_section_started(_plan: SectionPlan, _layout: SectionLayout) -> void:
	_room_time.clear()
	_tunnel_time = 0.0
	_section_time = 0.0


func _on_section_finished(plan: SectionPlan, layout: SectionLayout) -> void:
	if not _calibrate:
		return
	var rooms: Dictionary = {}
	for i: int in _room_time:
		rooms[String(layout.room_names[i])] = snappedf(float(_room_time[i]), 0.01)
	_calibration.append({
		"rooms": rooms,
		"tunnel": snappedf(_tunnel_time, 0.01),
		"tunnels": layout.room_rects.size() - 1,
		"time": snappedf(_section_time, 0.01),
		"arena": plan.is_arena,
	})


func _write_calibration() -> void:
	DirAccess.make_dir_recursive_absolute(CALIBRATION_DIR)
	var path: String = CALIBRATION_DIR.path_join("%s.json" % Telemetry.session_id)
	var file: FileAccess = FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify({"bot": String(_profile.id), "sections": _calibration}))
	file.close()
	print("Calibration data: %s (%d sections)" % [ProjectSettings.globalize_path(path), _calibration.size()])


func _int_argument(prefix: String, default_value: int) -> int:
	var value: String = _string_argument(prefix, "")
	return value.to_int() if value.is_valid_int() else default_value


func _string_argument(prefix: String, default_value: String) -> String:
	for arg: String in OS.get_cmdline_user_args():
		if arg.begins_with(prefix):
			return arg.trim_prefix(prefix)
	return default_value
