extends Node
## Manual check of the walls in the real game: plays main.tscn with a fixed seed and
## saves two screenshots, the player pressed against a brick wall in an ordinary room
## (room.png) and the first arena right after its doors sealed (arena_sealed.png).
## It also prints every wall cell whose tile differs from what Level.build() would draw
## for the same grid (there should be none). Not part of the test suite.
## Run it with visible collision shapes (the same as Debug > Visible Collision Shapes):
##   godot --path . res://tests/manual/level_shots.tscn --debug-collisions -- <folder>

const GAME_SCENE: PackedScene = preload("res://main/main.tscn")
const RUN_SEED: int = 5000
## How many sections to walk through while looking for the first arena.
const MAX_SECTIONS: int = 6
## Physics frames to wait after moving the player: the camera and the tiles settle.
const SETTLE_FRAMES: int = 20
const INVULNERABLE_SECONDS: float = 3600.0
## How far inside the arena (in cells) the player stands for the sealed-door shot.
const DOOR_SHOT_DEPTH: int = 3

var _game: Game = null
var _out_dir: String = "user://level_shots"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Telemetry.write_enabled = false
	GameManager.start_run(RUN_SEED)
	_game = GAME_SCENE.instantiate() as Game
	_game.death_screen_enabled = false
	add_child(_game)
	await _frames(SETTLE_FRAMES)
	_freeze_enemies()
	_game.player.health.make_invulnerable(INVULNERABLE_SECONDS)
	# The collision circle (radius 6) touches the bottom edge of the wall above.
	_game.player.teleport(_game.level.cell_center(_cell_below_brick_wall()) + Vector2(0.0, -2.0))
	await _frames(SETTLE_FRAMES)
	await _save("room.png")
	_report_tiles("room")

	while not _game.is_arena() and GameManager.section_index < MAX_SECTIONS:
		await _game._on_gate_entered(_game.player)
		await _frames(SETTLE_FRAMES)
	if not _game.is_arena():
		print("No arena in the first %d sections" % MAX_SECTIONS)
		get_tree().quit()
		return
	_freeze_enemies()
	_game.player.health.make_invulnerable(INVULNERABLE_SECONDS)
	var room: Rect2i = _game.layout.room_rects[_game.layout.arena_room]
	_game.player.teleport(_game.level.cell_center(_game.level.nearest_floor_cell(room.get_center())))
	await _frames(SETTLE_FRAMES)
	print("arena sealed: %s, doors %s" % [_game.is_arena_sealed(), _game.layout.arena_doors])
	_freeze_enemies()
	_game.player.teleport(_game.level.cell_center(_cell_inside_door(room)))
	await _frames(SETTLE_FRAMES)
	await _save("arena_sealed.png")
	_report_tiles("sealed arena")
	get_tree().quit()


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var image: Image = get_viewport().get_texture().get_image()
	var path: String = _out_dir.path_join(file_name)
	image.save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))


## Enemies stand still, so they do not crowd the shots.
func _freeze_enemies() -> void:
	for enemy: Enemy in _game.get_enemies():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED


## The floor cell under a wall (a wall with a brick front) nearest to the player.
func _cell_below_brick_wall() -> Vector2i:
	var level: Level = _game.level
	var start: Vector2i = level.cell_at(_game.player.global_position)
	var best: Vector2i = start
	var best_distance: int = -1
	for y in level.grid.height:
		for x in level.grid.width:
			var cell: Vector2i = Vector2i(x, y)
			if not level.grid.is_floor(cell) or level.grid.get_cell(cell + Vector2i.UP) != LevelGrid.Cell.WALL:
				continue
			# Not right next to a side wall: the shot should show a plain stretch of wall.
			if not level.grid.is_floor(cell + Vector2i.LEFT) or not level.grid.is_floor(cell + Vector2i.RIGHT):
				continue
			var distance: int = (cell - start).length_squared()
			if best_distance < 0 or distance < best_distance:
				best = cell
				best_distance = distance
	return best


## A floor cell a few steps inside the arena from its first door.
func _cell_inside_door(room: Rect2i) -> Vector2i:
	var door: Vector2i = _game.layout.arena_doors[0]
	var step: Vector2i = (room.get_center() - door).sign()
	step = Vector2i(step.x, 0) if absi(room.get_center().x - door.x) > absi(room.get_center().y - door.y) else Vector2i(0, step.y)
	return _game.level.nearest_floor_cell(door + step * DOOR_SHOT_DEPTH)


## Prints the wall cells drawn differently from a fresh build of the same grid.
func _report_tiles(label: String) -> void:
	var level: Level = _game.level
	var ground: TileMapLayer = level.get_node("Ground") as TileMapLayer
	var fresh: Level = Level.new()
	add_child(fresh)
	fresh.visible = false
	fresh.build(level.grid)
	var fresh_ground: TileMapLayer = fresh.get_node("Ground") as TileMapLayer
	var wrong: Array[String] = []
	for y in level.grid.height:
		for x in level.grid.width:
			var cell: Vector2i = Vector2i(x, y)
			if ground.get_cell_atlas_coords(cell) != fresh_ground.get_cell_atlas_coords(cell) \
					or ground.get_cell_source_id(cell) != fresh_ground.get_cell_source_id(cell):
				wrong.append("%s: %s instead of %s" % [cell, ground.get_cell_atlas_coords(cell),
						fresh_ground.get_cell_atlas_coords(cell)])
	fresh.queue_free()
	print("%s: %d cells drawn differently from a fresh build %s" % [label, wrong.size(), wrong])
