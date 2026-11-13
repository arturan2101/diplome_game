extends Node2D
## Manual art preview: builds a small room with the real Level code (ruins theme,
## wall tops, floor variants, cover, pit), puts the player and skeleton animations
## in it, saves a 3x screenshot and quits. Not part of the test suite.
## Usage: godot --path . res://tests/manual/art_preview.tscn -- <out.png>

const PLAYER_FRAMES: SpriteFrames = preload("res://assets/art/characters/player_frames.tres")
const SKELETON_FRAMES: SpriteFrames = preload("res://assets/art/enemies/skeleton_frames.tres")
const MAP: String = """############
#..........#
#..........#
#...%...~~.#
#.......~~.#
#..........#
#..........#
############"""
const SCALE: int = 3

var _view: SubViewport


func _ready() -> void:
	var grid: LevelGrid = LevelGrid.from_text(MAP)
	# Own SubViewport at 1:1 pixels, independent of the project's stretch settings.
	_view = SubViewport.new()
	_view.size = Vector2i(grid.width, grid.height) * 16
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var level: Level = Level.new()
	_view.add_child(level)
	level.build(grid)
	_add_actor(level, PLAYER_FRAMES, Vector2i(3, 5), &"idle_right")
	_add_actor(level, SKELETON_FRAMES, Vector2i(6, 5), &"idle_left")
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var img: Image = _view.get_texture().get_image()
	img.resize(img.get_width() * SCALE, img.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://room_ingame.png"
	img.save_png(out)
	print("Saved ", out)
	get_tree().quit()


## Places an animated sprite at a cell centre with the same offset as the actor scenes.
func _add_actor(level: Level, frames: SpriteFrames, cell: Vector2i, anim: StringName) -> void:
	var s: AnimatedSprite2D = AnimatedSprite2D.new()
	s.sprite_frames = frames
	s.animation = anim
	s.offset = Vector2(0, -4)
	s.position = level.cell_center(cell)
	_view.add_child(s)
