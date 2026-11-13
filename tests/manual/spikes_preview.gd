extends Node
## Manual preview of the spikes: a short corridor drawn by the real Level with static
## spikes and a timed wave of three rows, shown in each phase of the first row
## (hidden, warn, rise, up, retract). Saves one picture with the five frames side by
## side, 3x, and quits. Use it to check new spike sprites. Not part of the test suite.
## Usage: godot --path . res://tests/manual/spikes_preview.tscn -- <out.png>

const MAP: String = """##############
#............#
#..^.........#
#............#
##############"""
const WAVE_X: int = 6
const WAVE_ROWS: int = 3
const SCALE: int = 3
const GAP: int = 4

var _view: SubViewport = null


func _ready() -> void:
	var hazards: HazardData = load("res://level/hazards.tres") as HazardData
	var timed: SpikeTrapData = hazards.timed_spikes
	var grid: LevelGrid = LevelGrid.from_text(MAP)
	for row in WAVE_ROWS:
		for y in range(1, 4):
			grid.set_timed_spikes(Vector2i(WAVE_X + row, y), -row * timed.wave_step)
	_view = SubViewport.new()
	_view.size = Vector2i(grid.width, grid.height) * 16
	_view.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_view)
	var level: Level = Level.new()
	_view.add_child(level)
	level.build(grid)
	level.set_physics_process(false)
	# Middle of each phase of the first row.
	var starts: Array[float] = [0.0, timed.hidden_time, timed.hidden_time + timed.warn_time,
			timed.hidden_time + timed.warn_time + timed.rise_time,
			timed.hidden_time + timed.warn_time + timed.rise_time + timed.up_time]
	var lengths: Array[float] = [timed.hidden_time, timed.warn_time, timed.rise_time, timed.up_time, timed.retract_time]
	var frames: Array[Image] = []
	for i in starts.size():
		level.section_time = starts[i] + lengths[i] * 0.5
		level.timed_spikes.update_look(level.section_time)
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		frames.append(_view.get_texture().get_image())
	var width: int = frames[0].get_width()
	var height: int = frames[0].get_height()
	var sheet: Image = Image.create(width * frames.size() + GAP * (frames.size() - 1), height, false, frames[0].get_format())
	for i in frames.size():
		sheet.blit_rect(frames[i], Rect2i(Vector2i.ZERO, Vector2i(width, height)), Vector2i(i * (width + GAP), 0))
	sheet.resize(sheet.get_width() * SCALE, sheet.get_height() * SCALE, Image.INTERPOLATE_NEAREST)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var out: String = args[0] if args.size() > 0 else "user://spikes_preview.png"
	sheet.save_png(out)
	print("Saved ", out)
	get_tree().quit()
