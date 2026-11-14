extends Node
## Manual preview of a combat room: the real game in the full series with a combat room
## forced into the first section. Saves two screenshots, the sealed room with the spawn
## warnings (combat_warning.png) and the wave that came, with a shield skeleton and a
## triple-shot archer added (combat_wave.png), then quits. Not part of the test suite.
## Usage: godot --path . res://tests/manual/combat_preview.tscn -- <folder>

const GAME_SCENE: PackedScene = preload("res://main/main.tscn")
const RUN_SEED: int = 23
const SHIELD_SKELETON: EnemyData = preload("res://actors/enemies/skeleton_shield.tres")
const TRIPLE_ARCHER: EnemyData = preload("res://actors/enemies/archer_triple.tres")
const BIG_HP: int = 100000
const SETTLE_FRAMES: int = 6

var _out_dir: String = "user://combat_preview"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config("full")
	GameManager.start_run(RUN_SEED)
	var game: Game = GAME_SCENE.instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await _frames(2)
	game._director.settings = game._director.settings.duplicate() as DirectorSettings
	game._director.settings.combat_room_chance_build = 1.0
	game._director.settings.combat_waves_build = Vector2i(2, 2)
	game._start_section()
	await _frames(2)
	game.player.health.max_hp = BIG_HP
	game.player.health.reset()
	var tracker: CombatRoomTracker = game.get_combat_rooms()
	if tracker.rooms.is_empty():
		print("No combat room in this section")
		get_tree().quit()
		return
	var room: CombatRoom = tracker.rooms[0]
	game.player.teleport(game.level.cell_center(game.level.nearest_floor_cell(room.rect.get_center())))
	await _frames(SETTLE_FRAMES + roundi(tracker.warning_time * Engine.physics_ticks_per_second * 0.5))
	await _save("combat_warning.png")
	await _frames(roundi(tracker.warning_time * Engine.physics_ticks_per_second))
	var center: Vector2i = game.level.cell_at(game.player.global_position)
	for offset: Vector2i in [Vector2i(-4, -2), Vector2i(5, 2)]:
		var cell: Vector2i = game.level.nearest_floor_cell(center + offset)
		game.spawn_enemy(SHIELD_SKELETON if offset.x < 0 else TRIPLE_ARCHER, cell)
	await _frames(SETTLE_FRAMES * 4)
	await _save("combat_wave.png")
	GameManager.config = GameManager.DEFAULT_CONFIG
	get_tree().quit()


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))
