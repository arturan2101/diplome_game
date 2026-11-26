extends TestCase
## Headless test for the level backdrop (batch 16): every floor style and the merchant's
## glade have their own seamless backdrop; the level repeats it under all its tiles over
## the grid and a margin around it; a region theme over the whole grid (the glade) gives
## its own backdrop; a theme without one leaves the plain clear colour.

const STYLES: Array[String] = ["ruins", "fungal", "flooded", "fire", "glade"]
const MAP: String = """######
#....#
#....#
######"""


func run() -> void:
	_test_themes()
	await _test_level()
	await _test_glade_and_none()


func _test_themes() -> void:
	var ok: bool = true
	for style: String in STYLES:
		var theme: TileTheme = load("res://level/%s_theme.tres" % style) as TileTheme
		ok = ok and theme.backdrop != null and theme.backdrop.get_width() == theme.backdrop.get_height() 				and theme.backdrop.get_width() % theme.tile_size == 0
	check(ok, "the floor styles and the glade have a square backdrop (64 or 128 pixels, glade v2 of batch 17)")


func _test_level() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.set_theme(load("res://level/fungal_theme.tres") as TileTheme)
	level.build(LevelGrid.from_text(MAP))
	await physics_frames(1)
	var backdrop: Sprite2D = level.get_backdrop()
	check(backdrop.visible and backdrop.texture == level.theme.backdrop and level.get_child(0) == backdrop,
			"the level draws its theme's backdrop first, under the tiles")
	var size: int = level.theme.tile_size
	var margin: float = level.backdrop_margin * size
	var covered: Rect2 = Rect2(level.to_global(backdrop.position), backdrop.region_rect.size)
	check(backdrop.texture_repeat == CanvasItem.TEXTURE_REPEAT_ENABLED and covered.encloses(level.get_bounds().grow(margin - 0.5)),
			"repeated over the grid and %d cells around it: %s" % [level.backdrop_margin, covered])
	level.queue_free()
	await physics_frames(2)


func _test_glade_and_none() -> void:
	var level: Level = Level.new()
	add_child(level)
	var grid: LevelGrid = LevelGrid.from_text(MAP)
	grid.theme_regions.append({"rect": Rect2i(Vector2i.ZERO, Vector2i(grid.width, grid.height)), "theme": &"glade"})
	level.build(grid)
	await physics_frames(1)
	check(level.get_backdrop().texture == (load("res://level/glade_theme.tres") as TileTheme).backdrop,
			"the merchant's glade (a glade region over the whole grid) gets the glade backdrop")
	var bare: TileTheme = (load("res://level/ruins_theme.tres") as TileTheme).duplicate() as TileTheme
	bare.backdrop = null
	level.set_theme(bare)
	level.build(LevelGrid.from_text(MAP))
	await physics_frames(1)
	check(not level.get_backdrop().visible, "a theme without a backdrop leaves the clear colour")
	level.queue_free()
	await physics_frames(2)
