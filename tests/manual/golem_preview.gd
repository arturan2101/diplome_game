extends Node
## Manual preview of the stone golem (stage 29) next to the player on an open floor:
## saves golem_idle.png, golem_windup.png (the warning circle) and golem_slam.png, then
## quits. Not part of the test suite.
## Usage: godot --path . res://tests/manual/golem_preview.tscn -- <folder>

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const GOLEM: GolemData = preload("res://actors/enemies/golem.tres")
const FLOOR_MAP: String = """##############################
#............................#
#............................#
#............................#
#............................#
#............................#
#............................#
#............................#
#............................#
#............................#
#............................#
#............................#
#............................#
#............................#
#............................#
##############################"""
const SETTLE_FRAMES: int = 20
## Frames after the slam when it is saved (the shockwave has spread by then).
const SLAM_SHOT_FRAMES: int = 12

var _out_dir: String = "user://golem_preview"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var level: Level = Level.new()
	level.debug_map = FLOOR_MAP
	add_child(level)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.teleport(level.cell_center(Vector2i(10, 7)))
	player.health.max_hp = 100000
	player.health.reset()
	var golem: Golem = GOLEM.scene.instantiate() as Golem
	golem.data = GOLEM
	level.add_child(golem)
	golem.global_position = level.cell_center(Vector2i(16, 7))
	await _frames(SETTLE_FRAMES)
	await _save("golem_idle.png")
	player.teleport(golem.global_position + Vector2(-26.0, 0.0))
	while golem.get_windup_progress() < 0.6:
		await _frames(1)
	await _save("golem_windup.png")
	while golem.state == Enemy.State.WINDUP:
		await _frames(1)
	await _frames(SLAM_SHOT_FRAMES)
	await _save("golem_slam.png")
	get_tree().quit()


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))
