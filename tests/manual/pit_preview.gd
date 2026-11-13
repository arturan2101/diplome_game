extends Node2D
## Manual preview of the pits: a room with two pits drawn by the real Level code plus
## PitDecor, saved as a 3x screenshot (several frames, for a GIF). Not part of the tests.
## Usage: godot --path . res://tests/manual/pit_preview.tscn -- <out folder>

const MAP: String = """##############
#............#
#..~~~~......#
#..~~~~~.....#
#..~~~~~..~~.#
#...~~~...~~.#
#............#
##############"""
const SCALE: int = 3
const FRAMES: int = 8
const FRAME_STEP: int = 6

var _view: SubViewport


func _ready() -> void:
	var grid: LevelGrid = LevelGrid.from_text(MAP)
	_view = SubViewport.new()
	_view.size = Vector2i(grid.width, grid.height) * 16
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var level: Level = Level.new()
	_view.add_child(level)
	level.add_child(PitDecor.new())
	level.build(grid)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://pit_preview"
	DirAccess.make_dir_recursive_absolute(out)
	for i in FRAMES:
		for _f in FRAME_STEP:
			await RenderingServer.frame_post_draw
		var img: Image = _view.get_texture().get_image()
		img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
		img.save_png(out.path_join("pit_%d.png" % i))
	print("Saved ", out)
	get_tree().quit()
