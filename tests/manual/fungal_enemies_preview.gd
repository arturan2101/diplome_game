extends Node
## Manual preview of the fungal enemies (stage 48, part 2): a fungal room with the player
## (invulnerable, standing still), a sporeling, two spore bats behind a pit and a hidden
## vine lurker next to the player. Saves fungal_enemies_<n>.png every SHOT_FRAMES
## frames (the lurker comes out and lashes, the bats fly over the pit and dive), then
## quits. Not part of the test suite.
## Usage: godot --path . res://tests/manual/fungal_enemies_preview.tscn -- <folder>

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const ENEMY_SCENE: PackedScene = preload("res://actors/enemies/enemy.tscn")
const THEME: TileTheme = preload("res://level/fungal_theme.tres")
const SHOTS: int = 4
const SHOT_FRAMES: int = 25
const MAP: String = """##########################
#........................#
#.....~~~................#
#.....~~~................#
#.....~~~................#
#.....~~~................#
#........................#
#........................#
##########################"""

var _out_dir: String = "user://fungal_enemies_preview"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var level: Level = Level.new()
	level.set_theme(THEME)
	add_child(level)
	level.build(LevelGrid.from_text(MAP))
	level.add_child(LevelDecor.new())
	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.position = level.cell_center(Vector2i(12, 4))
	level.add_child(player)
	player.set_physics_process(false)
	player.health.make_invulnerable(60.0)
	_add(level, &"vine_lurker", Vector2i(14, 4))
	_add(level, &"sporeling", Vector2i(16, 6))
	_add(level, &"spore_bat", Vector2i(3, 3))
	_add(level, &"spore_bat", Vector2i(3, 5))
	for i in SHOTS:
		for _f in SHOT_FRAMES:
			await get_tree().physics_frame
		await RenderingServer.frame_post_draw
		var path: String = _out_dir.path_join("fungal_enemies_%d.png" % (i + 1))
		get_viewport().get_texture().get_image().save_png(path)
		print("Saved ", ProjectSettings.globalize_path(path))
	get_tree().quit()


func _add(level: Level, id: StringName, cell: Vector2i) -> void:
	var data: EnemyData = load("res://actors/enemies/%s.tres" % id) as EnemyData
	var enemy: Enemy = (data.scene if data.scene != null else ENEMY_SCENE).instantiate() as Enemy
	enemy.data = data
	enemy.position = level.cell_center(cell)
	level.add_child(enemy)
