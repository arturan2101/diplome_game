extends TestCase
## Headless test for the side walls (after stage 49, batch 17): a wall that runs
## vertically (floor on one side only, wall below) is drawn with the theme's side tile,
## as drawn for a floor on its right and mirrored for a floor on its left, and stays
## solid; walls facing the floor below keep their front, other walls their top.

const THEMES: Array[String] = ["ruins", "fungal", "flooded", "fire", "sand", "glade", "nature"]
## A room with a column of wall in the middle: x = 3 has floor on its left only,
## x = 4 on its right only.
const MAP: String = """########
#..##..#
#..##..#
#..##..#
#......#
########"""


func run() -> void:
	_test_themes()
	await _test_level()


func _test_themes() -> void:
	var ok: bool = true
	for style: String in THEMES:
		var theme: TileTheme = load("res://level/%s_theme.tres" % style) as TileTheme
		ok = ok and theme.wall_side_tile.x >= 0 and (theme.wall_side_tile.x + 1) * theme.tile_size <= theme.texture.get_width()
	check(ok, "every style and the glade name a side tile inside their atlas")


func _test_level() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.set_theme(load("res://level/ruins_theme.tres") as TileTheme)
	level.build(LevelGrid.from_text(MAP))
	await physics_frames(1)
	var ground: TileMapLayer = level.get_node(^"Ground") as TileMapLayer
	var side: Vector2i = level.theme.wall_side_tile
	check(ground.get_cell_atlas_coords(Vector2i(4, 2)) == side and ground.get_cell_alternative_tile(Vector2i(4, 2)) == 0,
			"a wall with the floor on its right shows the side tile as drawn")
	check(ground.get_cell_atlas_coords(Vector2i(3, 2)) == side
			and ground.get_cell_alternative_tile(Vector2i(3, 2)) == Level.MIRRORED_ALTERNATIVE,
			"a wall with the floor on its left shows it mirrored")
	var mirrored: TileData = ground.get_cell_tile_data(Vector2i(3, 2))
	check(mirrored != null and mirrored.flip_h and mirrored.get_collision_polygons_count(0) > 0, "the mirrored one is solid too")
	check(level.theme.wall_tiles.has(ground.get_cell_atlas_coords(Vector2i(3, 3)))
			and level.theme.wall_tiles.has(ground.get_cell_atlas_coords(Vector2i(2, 0))),
			"walls facing the floor below (the column's foot, the wall over the room) keep their front")
	check(ground.get_cell_atlas_coords(Vector2i(0, 2)) == side, "the outer wall on the left runs vertically too")
	check(level.theme.wall_top_tiles.has(ground.get_cell_atlas_coords(Vector2i(3, 0))),
			"a wall touching the floor only at a corner keeps its top")
	level.queue_free()
	await physics_frames(2)
