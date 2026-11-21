extends Node
## Manual preview of the gates (stage 42): the real full game; for a few sections it
## stands the player next to the gate and saves gate_<n>_closed.png and, after opening
## it, gate_<n>_open.png; then the same for a boss arena. Not part of the test suite.
## Usage: godot --path . res://tests/manual/gate_preview.tscn -- <folder>

const GAME_SCENE: PackedScene = preload("res://main/main.tscn")
const RUN_SEED: int = 5003
const SECTIONS: int = 4
const SETTLE_FRAMES: int = 20
const OPEN_FRAMES: int = 50
## Depth of the boss arena (the boss sleeps on the arena of every second depth).
const BOSS_DEPTH: int = 1

var _out_dir: String = "user://gate_preview"
var _game: Game = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config("full")
	GameManager.start_run(RUN_SEED)
	_game = GAME_SCENE.instantiate() as Game
	_game.death_screen_enabled = false
	add_child(_game)
	await _frames(SETTLE_FRAMES)
	for i in SECTIONS:
		GameManager.section_index = i
		_game._start_section()
		await _shoot("gate_%d" % i)
	# A boss arena: the last section of the boss's depth.
	var settings: DirectorSettings = _game._director.settings
	for i in 12:
		GameManager.depth = BOSS_DEPTH
		GameManager.section_index = 20 + i
		var state: PlayerState = _game._make_player_state()
		state.is_depth_end = true
		state.depth = BOSS_DEPTH
		_game.plan = _game._director.choose_next(state)
		if _game.plan.is_boss:
			break
	print("boss plan: ", _game.plan.is_boss, " every ", settings.boss_every_depths)
	_game.layout = _game._builder.build(_game.plan, GameManager.make_section_rng(GameManager.section_index))
	_game._clear_section()
	_game.level.build(_game.layout.grid)
	_game._contents = Node2D.new()
	_game.level.add_child(_game._contents)
	_game._spawn_gate()
	await _shoot("boss_gate", 0.8)
	get_tree().quit()


func _shoot(name: String, rising_shot: float = 0.0) -> void:
	for enemy: Enemy in _game.get_enemies():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	_game.player.health.make_invulnerable(60.0)
	var exit: Vector2i = _game.layout.exit
	var stand: Vector2i = _game.level.nearest_floor_cell(exit + Vector2i(0, 2))
	_game.player.teleport(_game.level.cell_center(stand))
	await _frames(SETTLE_FRAMES)
	await _save(name + "_closed.png")
	_game.gate.open()
	if rising_shot > 0.0:
		# Halfway out of the floor.
		await _frames(roundi(rising_shot * Engine.physics_ticks_per_second))
		await _save(name + "_rising.png")
	await _frames(OPEN_FRAMES * 2 if rising_shot > 0.0 else OPEN_FRAMES)
	await _save(name + "_open.png")


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
