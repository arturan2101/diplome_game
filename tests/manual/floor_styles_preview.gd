extends Node
## Manual preview of the floor styles (stage 42): the real full game at the first section
## of depths 1, 3, 5 and 7 (ruins, fungal catacombs since stage 48, flooded halls,
## burning depths), the player next to a pit
## if the section has one. Saves style_<depth>.png for each, then quits. Not part of the
## test suite.
## Usage: godot --path . res://tests/manual/floor_styles_preview.tscn -- <folder>

const GAME_SCENE: PackedScene = preload("res://main/main.tscn")
const RUN_SEED: int = 5003
const DEPTHS: Array[int] = [0, 2, 4, 6]
const SETTLE_FRAMES: int = 20
## Sections tried per depth until one has a pit to show.
const TRIES: int = 6

var _out_dir: String = "user://floor_styles_preview"


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
	await _frames(SETTLE_FRAMES)
	for depth: int in DEPTHS:
		GameManager.depth = depth
		var pit: Vector2i = Vector2i(-1, -1)
		for i in TRIES:
			GameManager.section_index = depth * 10 + i
			game._start_section()
			await _frames(2)
			pit = _first_pit(game.level.grid)
			if pit.x >= 0:
				break
		for enemy: Enemy in game.get_enemies():
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
		game.player.health.make_invulnerable(60.0)
		if pit.x >= 0:
			game.player.teleport(game.level.cell_center(game.level.nearest_floor_cell(pit + Vector2i(0, 3))))
		await _frames(SETTLE_FRAMES)
		await RenderingServer.frame_post_draw
		var path: String = _out_dir.path_join("style_%d.png" % (depth + 1))
		get_viewport().get_texture().get_image().save_png(path)
		print("Saved ", ProjectSettings.globalize_path(path))
	get_tree().quit()


func _first_pit(grid: LevelGrid) -> Vector2i:
	for y in grid.height:
		for x in grid.width:
			if grid.get_cell(Vector2i(x, y)) == LevelGrid.Cell.PIT:
				return Vector2i(x, y)
	return Vector2i(-1, -1)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
