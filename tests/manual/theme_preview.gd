extends Node2D
## Manual preview of a tile theme: a small room drawn by the real Level code with the
## theme given as the first argument (default: the nature theme), saved 3x.
## Usage: godot --path . res://tests/manual/theme_preview.tscn -- <theme.tres> <out.png>

const MAP: String = """##############
#............#
#...%........#
#.......%....#
#............#
#............#
##############"""
const SCALE: int = 3


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var theme_path: String = args[0] if args.size() > 0 else "res://level/nature_theme.tres"
	var out: String = args[1] if args.size() > 1 else "user://theme_preview.png"
	var grid: LevelGrid = LevelGrid.from_text(MAP)
	var view: SubViewport = SubViewport.new()
	view.size = Vector2i(grid.width, grid.height) * 16
	view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(view)
	var level: Level = Level.new()
	level.theme = load(theme_path) as TileTheme
	view.add_child(level)
	level.build(grid)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = view.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	img.save_png(out)
	print("Saved ", out)
	get_tree().quit()
