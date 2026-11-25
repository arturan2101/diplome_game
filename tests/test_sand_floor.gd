extends TestCase
## Headless test for stage 49, part 1: the buried temple comes between the flooded
## halls and the fire floors only with ExperimentConfig.extra_floor_styles; its theme has
## all its art; the quicksand patches go on safe floor of a section (the same for the
## same seed, none in an arena); a patch slows the player and walking enemies standing
## on it, not fliers; the game lays patches only on sand floors.

const SAND: String = "res://level/sand_theme.tres"
const CLEAN: String = "res://experiment/clean.tres"
const SETTINGS: String = "res://director/director_settings.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const ENEMY_SCENE: String = "res://actors/enemies/enemy.tscn"
const GAME_SCENE: String = "res://main/main.tscn"
const SECTIONS: int = 60
const OPEN_MAP: String = """############
#..........#
#..........#
#..........#
#..........#
#..........#
############"""


func run() -> void:
	_test_order()
	_test_theme()
	_test_pick_patches()
	await _test_slow()
	await _test_game()


func _test_order() -> void:
	var table: FloorStyleTable = GameManager.floor_style_table()
	check(table.style_at(6) == &"sand" and table.style_at(7) == &"sand" and table.style_at(8) == &"fire",
			"the buried temple takes depths 7-8, the fire floors come after it")
	var saved: ExperimentConfig = GameManager.config
	GameManager.config = load(CLEAN) as ExperimentConfig
	var sand_seen: bool = false
	for depth in 12:
		sand_seen = sand_seen or GameManager.floor_style_table().style_at(depth) == &"sand"
	check(not sand_seen, "without the new styles there is no sand floor")
	GameManager.config = saved


func _test_theme() -> void:
	var theme: TileTheme = load(SAND) as TileTheme
	var textures: Array = [theme.texture, theme.hazard_texture, theme.floor_decals, theme.wall_details,
			theme.wall_light, theme.door_seal, theme.backdrop]
	check(not textures.has(null) and theme.cover_pieces.size() == 3 and theme.quicksand != null and theme.floor_trap == null,
			"the sand theme has its tiles, decals, wall details, brazier, door rubble, backdrop, obstacles and quicksand")
	check(theme.style_id == &"sand" and theme.display_name == "The Buried Temple", "its id and name")
	var plates: Texture2D = load("res://assets/art/ui/floor_plates.png") as Texture2D
	check(theme.plate_index >= 0 and (theme.plate_index + 1) * 16 <= plates.get_height(), "its plate is in the plates strip")
	var atlas_slots: int = theme.texture.get_width() / theme.tile_size
	var used: Array[Vector2i] = theme.floor_tiles + theme.wall_tiles + theme.wall_top_tiles
	used.append_array([theme.cover_tile, theme.cracked_wall_tile, theme.cracked_wall_top_tile])
	var inside: bool = true
	for tile: Vector2i in used:
		inside = inside and tile.x < atlas_slots and tile.y == 0
	check(inside, "every tile it names is in its atlas")
	var sand: QuicksandData = theme.quicksand
	check(sand.strip.get_width() == sand.strip_frames * theme.tile_size and Sound.has_music(&"sand_explore")
			and FileAccess.file_exists(Sound.SFX_DIR + String(sand.step_sound) + ".ogg"),
			"the quicksand strip has its frames, the floor its music and the sand its sound")


func _test_pick_patches() -> void:
	var sand: QuicksandData = (load(SAND) as TileTheme).quicksand
	var settings: DirectorSettings = (load(SETTINGS) as DirectorSettings).duplicate() as DirectorSettings
	var director: RuleDirector = RuleDirector.new(null, settings)
	var builder: SectionBuilder = SectionBuilder.new()
	var total: int = 0
	var sections: int = 0
	var ok: bool = true
	var same: bool = true
	var arena_empty: bool = true
	for i in SECTIONS:
		var state: PlayerState = PlayerState.new()
		state.section_index = i
		state.depth = 6
		state.rng.seed = 4900 + i
		var plan: SectionPlan = director.choose_next(state)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 490 + i
		var layout: SectionLayout = builder.build(plan, rng)
		var patch_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		patch_rng.seed = 49 + i
		var patches: Array[Rect2i] = Quicksand.pick_patches(layout, sand, patch_rng)
		patch_rng.seed = 49 + i
		same = same and Quicksand.pick_patches(layout, sand, patch_rng) == patches
		if layout.arena_room >= 0:
			arena_empty = arena_empty and patches.is_empty()
			continue
		sections += 1
		total += patches.size()
		ok = ok and patches.size() <= sand.per_section.y and _patches_safe(layout, patches, sand)
	check(sections > 0 and total >= sections, "most sections get quicksand (%d patches in %d sections)" % [total, sections])
	check(ok, "patches of 2-3 cells a side on plain floor after the first room, off the walls, away from the doors, the portal, items and each other")
	check(same, "the same section and seed give the same patches")
	check(arena_empty, "no quicksand in an arena")


func _patches_safe(layout: SectionLayout, patches: Array[Rect2i], sand: QuicksandData) -> bool:
	var gates: Array[Vector2i] = [layout.entrance]
	gates.append_array(SectionBuilder.gate_footprint(layout.exit))
	for rect: Rect2i in patches:
		if rect.size.x < sand.patch_size.x or rect.size.x > sand.patch_size.y or rect.size.y < sand.patch_size.x 				or rect.size.y > sand.patch_size.y or layout.room_rects[0].intersects(rect):
			return false
		for cell: Vector2i in Quicksand.rect_cells(rect):
			if not layout.grid.is_floor(cell):
				return false
		for cell: Vector2i in Quicksand.rect_cells(rect.grow(1)):
			if layout.grid.get_cell(cell) == LevelGrid.Cell.WALL:
				return false
		for other: Vector2i in gates:
			if rect.grow(sand.clearance).has_point(other):
				return false
		for entry: Dictionary in layout.items:
			if rect.grow(sand.item_clearance).has_point(entry["cell"]):
				return false
		for other: Rect2i in patches:
			if other != rect and rect.grow(sand.min_spacing).intersects(other):
				return false
	return true


func _test_slow() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(OPEN_MAP))
	var contents: Node2D = Node2D.new()
	level.add_child(contents)
	var sand: QuicksandData = (load(SAND) as TileTheme).quicksand
	var patch_cells: Array[Vector2i] = Quicksand.rect_cells(Rect2i(Vector2i(2, 2), Vector2i(3, 2)))
	var patch: Quicksand = Quicksand.spawn(contents, level, patch_cells, sand)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = level.cell_center(Vector2i(9, 4))
	add_child(player)
	var walker: Enemy = _enemy(&"skeleton", level.cell_center(Vector2i(3, 3)), contents)
	var bat: Enemy = _enemy(&"spore_bat", level.cell_center(Vector2i(4, 2)), contents)
	await physics_frames(3)
	check(patch.get_child_count() == patch_cells.size() and patch.get_child(0) is StripSprite, "each cell is drawn with swirling sand")
	check(not player.is_slowed(), "off the sand the player walks at full speed")
	check(walker.is_slowed() and not bat.is_slowed(), "a skeleton on the sand is slowed, a flying bat is not")
	player.global_position = level.cell_center(Vector2i(2, 2))
	await physics_frames(2)
	check(player.is_slowed() and is_equal_approx(player._slow_multiplier, sand.slow_multiplier),
			"on the sand the player walks at half speed")
	player.global_position = level.cell_center(Vector2i(9, 4))
	await physics_frames(roundi((sand.slow_linger + 0.1) * Engine.physics_ticks_per_second))
	check(not player.is_slowed(), "and soon after stepping off at full speed again")
	player.queue_free()
	level.queue_free()
	await physics_frames(2)


func _enemy(id: StringName, at: Vector2, parent: Node) -> Enemy:
	var data: EnemyData = load("res://actors/enemies/%s.tres" % id) as EnemyData
	var scene: PackedScene = data.scene if data.scene != null else load(ENEMY_SCENE) as PackedScene
	var enemy: Enemy = scene.instantiate() as Enemy
	enemy.data = data
	enemy.position = at
	enemy.is_dormant = true
	parent.add_child(enemy)
	return enemy


func _test_game() -> void:
	var saved: ExperimentConfig = GameManager.config
	var sand: QuicksandData = (load(SAND) as TileTheme).quicksand
	for config: ExperimentConfig in [saved, load(CLEAN) as ExperimentConfig]:
		GameManager.config = config
		GameManager.start_run(4910)
		var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
		game.death_screen_enabled = false
		add_child(game)
		await physics_frames(2)
		GameManager.depth = 6
		GameManager.section_index = 20
		game._start_section()
		await physics_frames(2)
		var patches: Array[Array] = []
		for child: Node in game._contents.get_children():
			if child is Quicksand:
				patches.append((child as Quicksand).cells)
		if config == saved:
			var expected: Array[Array] = []
			for rect: Rect2i in Quicksand.pick_patches(game.layout, sand, GameManager.make_hazard_rng(20)):
				expected.append(Quicksand.rect_cells(rect))
			check(game.level.theme == load(SAND), "the full game draws the seventh depth as the buried temple")
			check(patches == expected and not patches.is_empty(),
					"its section has the quicksand picked from the run's hazard stream (%d patches)" % patches.size())
		else:
			check(patches.is_empty(), "the clean series has none")
		game.queue_free()
		await physics_frames(2)
	GameManager.config = saved
