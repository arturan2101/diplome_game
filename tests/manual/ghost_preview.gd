extends Node
## Manual preview of the ghost (stage 31): it drifts through a wall towards the player
## and strikes. Saves ghost_drift.png (half see-through, in the wall) and
## ghost_strike.png (fully visible, winding up), then quits. Not part of the test suite.
## Usage: godot --path . res://tests/manual/ghost_preview.tscn -- <folder>

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const GHOST: GhostData = preload("res://actors/enemies/ghost.tres")
const FLOOR_MAP: String = """##############################
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
#.............#..............#
##############################"""
const MAX_FRAMES: int = 1200
const SHOT_DELAY_FRAMES: int = 6

var _out_dir: String = "user://ghost_preview"


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
	player.teleport(level.cell_center(Vector2i(17, 7)))
	player.health.max_hp = 100000
	player.health.reset()
	var ghost: Ghost = GHOST.scene.instantiate() as Ghost
	ghost.data = GHOST
	level.add_child(ghost)
	ghost.global_position = level.cell_center(Vector2i(10, 7))
	var drift_saved: bool = false
	for _i in MAX_FRAMES:
		await get_tree().physics_frame
		if not drift_saved and ghost.is_in_wall():
			drift_saved = true
			await _save("ghost_drift.png")
		if ghost.state == Enemy.State.WINDUP:
			for _j in SHOT_DELAY_FRAMES:
				await get_tree().physics_frame
			await _save("ghost_strike.png")
			break
	get_tree().quit()


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))
