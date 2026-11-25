extends TestCase
## Headless test for the floor styles of stage 42: the style by depth, the level drawing
## with another theme (walls keep their collision, the fire ruins' pits are animated
## lava), the style's floor decals, the full game switching styles and the clean series
## keeping the ruins.

const RUINS: String = "res://level/ruins_theme.tres"
const FLOODED: String = "res://level/flooded_theme.tres"
const FIRE: String = "res://level/fire_theme.tres"
const GAME_SCENE: String = "res://main/main.tscn"
const CLEAN: String = "res://experiment/clean.tres"
const MAP: String = """########
#......#
#..~~..#
#..~~..#
#......#
########"""


func run() -> void:
	await _test_level_themes()
	await _test_game()


func _test_level_themes() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(MAP))
	var ground: TileMapLayer = level.get_node("Ground") as TileMapLayer
	check(ground.get_cell_source_id(Vector2i(3, 2)) == Level.HAZARD_SOURCE, "the ruins draw still pit tiles")
	level.set_theme(load(FIRE) as TileTheme)
	level.build(LevelGrid.from_text(MAP))
	# Tile collision is built over the next frames.
	await physics_frames(3)
	var lava: TileSetAtlasSource = ground.tile_set.get_source(Level.LAVA_SOURCE) as TileSetAtlasSource
	check(ground.get_cell_source_id(Vector2i(3, 2)) == Level.LAVA_SOURCE and ground.get_cell_atlas_coords(Vector2i(3, 2)) == Vector2i(0, 0)
			and ground.get_cell_atlas_coords(Vector2i(3, 3)) == Vector2i(0, 1), "the fire ruins' pits are lava: edge on top, inside below")
	check(lava != null and lava.get_tile_animation_frames_count(Vector2i(0, 0)) == 4, "the lava runs through four frames")
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(level.cell_center(Vector2i(1, 1)),
			level.cell_center(Vector2i(1, 1)) + Vector2(0.0, -40.0), 1)
	check(not space.intersect_ray(ray).is_empty(), "the fire ruins' walls still stop things")
	var decor: LevelDecor = LevelDecor.new()
	level.add_child(decor)
	await physics_frames(1)
	decor._grid = level.grid
	decor._rebuild()
	check(decor._decals == (load(FIRE) as TileTheme).floor_decals, "the decor scatters the style's own decals")
	level.queue_free()
	await physics_frames(2)


func _test_game() -> void:
	var saved: ExperimentConfig = GameManager.config
	GameManager.start_run(4200)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	var styles: Array[String] = []
	for depth in 9:
		styles.append(game.floor_theme_for(depth).display_name)
	check(styles == (["The Ruins", "The Ruins", "The Fungal Catacombs", "The Fungal Catacombs", "The Flooded Halls",
			"The Flooded Halls", "The Burning Depths", "The Burning Depths", "The Ruins"] as Array[String]),
			"two depths per style, then round again: %s" % [styles])
	check(game.level.theme == load(RUINS), "a run starts in the ruins")
	GameManager.depth = 4
	game._start_section()
	await physics_frames(2)
	check(game.level.theme == load(FLOODED) and game.hud.banner.visible and game.hud.banner.text == "The Flooded Halls",
			"the fifth depth is flooded, and its name is shown")
	game.queue_free()
	await physics_frames(2)

	GameManager.config = load(CLEAN) as ExperimentConfig
	GameManager.start_run(4200)
	game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	GameManager.depth = 4
	game._start_section()
	await physics_frames(2)
	check(game.level.theme == load(RUINS), "the clean series stays in the ruins")
	game.queue_free()
	GameManager.config = saved
	await physics_frames(2)
