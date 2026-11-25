extends TestCase
## Headless test for stage 48, part 1: the fungal catacombs come after the ruins only
## with ExperimentConfig.extra_floor_styles (without it the old order stays), the fungal
## theme has all its art (its own wall light and door rubble), the puffballs go on safe
## cells of a section (the same cells for the same seed, none in an arena), and a
## puffball bursts when the player comes close, its cloud hurts the player, and it grows
## back. The game puts puffballs only on fungal floors.

const FUNGAL: String = "res://level/fungal_theme.tres"
const CLEAN: String = "res://experiment/clean.tres"
const SETTINGS: String = "res://director/director_settings.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const GAME_SCENE: String = "res://main/main.tscn"
const SECTIONS: int = 60
const TIMEOUT_FRAMES: int = 120
const OPEN_MAP: String = """############
#..........#
#..........#
#..........#
#..........#
############"""


func run() -> void:
	_test_config_and_order()
	_test_theme()
	await _test_decor()
	_test_pick_cells()
	await _test_puff()
	await _test_game()


func _test_config_and_order() -> void:
	var saved: ExperimentConfig = GameManager.config
	check(GameManager.config.extra_floor_styles and not (load(CLEAN) as ExperimentConfig).extra_floor_styles,
			"the new floor styles: on in the full game, off in the clean series")
	var styles: Array[StringName] = []
	for depth in 10:
		styles.append(GameManager.floor_style_table().style_at(depth))
	check(styles == ([&"ruins", &"ruins", &"fungal", &"fungal", &"flooded", &"flooded", &"sand", &"sand", &"fire", &"fire"] as Array[StringName]),
			"the fungal catacombs come after the ruins, the sand temple before the fire (stage 49): %s" % [styles])
	var without: ExperimentConfig = GameManager.config.duplicate() as ExperimentConfig
	without.extra_floor_styles = false
	GameManager.config = without
	var old: Array[StringName] = []
	for depth in 6:
		old.append(GameManager.floor_style_table().style_at(depth))
	check(old == ([&"ruins", &"ruins", &"flooded", &"flooded", &"fire", &"fire"] as Array[StringName]),
			"without the flag the styles keep their old depths: %s" % [old])
	check(GameManager.make_director().settings.floor_styles.style_at(2) == &"flooded",
			"and the director sees the same order as the game")
	GameManager.config = saved
	check(GameManager.make_director().settings.floor_styles.style_at(2) == &"fungal",
			"with the flag the director sees the fungal floors")


func _test_theme() -> void:
	var theme: TileTheme = load(FUNGAL) as TileTheme
	var textures: Array = [theme.texture, theme.hazard_texture, theme.floor_decals, theme.wall_details,
			theme.wall_light, theme.door_seal]
	check(not textures.has(null) and theme.cover_pieces.size() == 3 and theme.floor_trap != null,
			"the fungal theme has its tiles, decals, wall details, lamp, door rubble, obstacles and trap")
	check(theme.style_id == &"fungal" and theme.display_name == "The Fungal Catacombs", "its id and name")
	var plates: Texture2D = load("res://assets/art/ui/floor_plates.png") as Texture2D
	check(theme.plate_index >= 0 and (theme.plate_index + 1) * 16 <= plates.get_height(), "its plate is in the plates strip")
	var atlas_slots: int = theme.texture.get_width() / theme.tile_size
	var used: Array[Vector2i] = theme.floor_tiles + theme.wall_tiles + theme.wall_top_tiles
	used.append_array([theme.cover_tile, theme.cracked_wall_tile, theme.cracked_wall_top_tile])
	var inside: bool = true
	for tile: Vector2i in used:
		inside = inside and tile.x < atlas_slots and tile.y == 0
	check(inside, "every tile it names is in its atlas")
	var frames: SpriteFrames = theme.floor_trap.frames
	check(frames.has_animation(&"spore_puff_breathe") and frames.has_animation(&"spore_puff_burst")
			and frames.has_animation(&"spore_cloud") and theme.floor_trap.cloud != null,
			"the puffball and its cloud have their frames")


func _test_decor() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.set_theme(load(FUNGAL) as TileTheme)
	level.build(LevelGrid.from_text(OPEN_MAP))
	await physics_frames(2)
	var decor: LevelDecor = LevelDecor.new()
	level.add_child(decor)
	await physics_frames(2)
	var theme: TileTheme = level.theme
	check(decor._light_strip() == theme.wall_light and decor._light_color() == theme.wall_light_color,
			"the walls carry the style's glowing mushrooms, not torches")
	var ruins: Level = Level.new()
	add_child(ruins)
	ruins.build(LevelGrid.from_text(OPEN_MAP))
	var plain: LevelDecor = LevelDecor.new()
	ruins.add_child(plain)
	await physics_frames(2)
	check(plain._light_strip() == plain.torch, "a style without its own light keeps the torch")
	level.queue_free()
	ruins.queue_free()
	await physics_frames(2)


func _test_pick_cells() -> void:
	var trap: SporeTrapData = (load(FUNGAL) as TileTheme).floor_trap
	var settings: DirectorSettings = (load(SETTINGS) as DirectorSettings).duplicate() as DirectorSettings
	var director: RuleDirector = RuleDirector.new(null, settings)
	var builder: SectionBuilder = SectionBuilder.new()
	var total: int = 0
	var sections: int = 0
	var safe: bool = true
	var counts_ok: bool = true
	var same: bool = true
	var arena_empty: bool = true
	for i in SECTIONS:
		var state: PlayerState = PlayerState.new()
		state.section_index = i
		state.depth = 2
		state.rng.seed = 4800 + i
		var plan: SectionPlan = director.choose_next(state)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 480 + i
		var layout: SectionLayout = builder.build(plan, rng)
		var trap_rng: RandomNumberGenerator = RandomNumberGenerator.new()
		trap_rng.seed = 48 + i
		var cells: Array[Vector2i] = SporePuff.pick_cells(layout, trap, trap_rng)
		trap_rng.seed = 48 + i
		same = same and SporePuff.pick_cells(layout, trap, trap_rng) == cells
		if layout.arena_room >= 0:
			arena_empty = arena_empty and cells.is_empty()
			continue
		sections += 1
		total += cells.size()
		counts_ok = counts_ok and cells.size() <= trap.per_section.y
		safe = safe and _cells_safe(layout, cells, trap)
	check(sections > 0 and total >= sections * trap.per_section.x * 3 / 4,
			"most sections get their puffballs (%d in %d sections)" % [total, sections])
	check(counts_ok and safe, "on plain floor of the rooms after the first, away from walls, doors, the portal, items, enemies and each other")
	check(same, "the same section and seed give the same cells")
	check(arena_empty, "no puffballs in an arena")


func _cells_safe(layout: SectionLayout, cells: Array[Vector2i], trap: SporeTrapData) -> bool:
	var keep_away: Array[Vector2i] = [layout.entrance]
	keep_away.append_array(SectionBuilder.gate_footprint(layout.exit))
	for entry: Dictionary in layout.items + layout.enemies:
		keep_away.append(entry["cell"])
	for cell: Vector2i in cells:
		if layout.room_rects[0].has_point(cell):
			return false
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if not layout.grid.is_floor(cell + Vector2i(dx, dy)):
					return false
		for other: Vector2i in keep_away:
			if maxi(absi(other.x - cell.x), absi(other.y - cell.y)) <= trap.clearance:
				return false
		for other: Vector2i in cells:
			if other != cell and maxi(absi(other.x - cell.x), absi(other.y - cell.y)) < trap.min_spacing:
				return false
	return true


func _test_puff() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(OPEN_MAP))
	var trap: SporeTrapData = (load(FUNGAL) as TileTheme).floor_trap.duplicate() as SporeTrapData
	trap.regrow_time = 0.3
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = level.cell_center(Vector2i(9, 3))
	add_child(player)
	var hits: Array[DamageInfo] = []
	player.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	var puff: SporePuff = SporePuff.spawn(level, level.cell_center(Vector2i(3, 3)), trap)
	await physics_frames(10)
	check(puff.state == SporePuff.State.BREATHING and level.floor_effects.get_child_count() == 0,
			"far from the player it only breathes")
	player.global_position = puff.global_position + Vector2(10.0, 0.0)
	var frames: int = 0
	while level.floor_effects.get_child_count() == 0 and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
	check(level.floor_effects.get_child_count() == 1 and level.floor_effects.get_child(0) is SpellZone,
			"the player close by makes it burst into a spore cloud")
	frames = 0
	while hits.is_empty() and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
	check(not hits.is_empty() and hits[0].source_id == &"spore_trap", "the cloud hurts the player (source spore_trap)")
	frames = 0
	while puff.state != SporePuff.State.SPENT and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
	check(puff.state == SporePuff.State.SPENT, "after the burst it lies flat")
	player.global_position = level.cell_center(Vector2i(9, 3))
	frames = 0
	while puff.state != SporePuff.State.BREATHING and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
	check(puff.state == SporePuff.State.BREATHING, "and grows back")
	player.queue_free()
	level.queue_free()
	await physics_frames(2)


func _test_game() -> void:
	var saved: ExperimentConfig = GameManager.config
	var trap: SporeTrapData = (load(FUNGAL) as TileTheme).floor_trap
	for config: ExperimentConfig in [saved, load(CLEAN) as ExperimentConfig]:
		GameManager.config = config
		GameManager.start_run(4810)
		var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
		game.death_screen_enabled = false
		add_child(game)
		await physics_frames(2)
		GameManager.depth = 2
		GameManager.section_index = 10
		game._start_section()
		await physics_frames(2)
		var cells: Array[Vector2i] = []
		for child: Node in game._contents.get_children():
			if child is SporePuff:
				cells.append(game.level.cell_at((child as SporePuff).global_position))
		if config == saved:
			var expected: Array[Vector2i] = SporePuff.pick_cells(game.layout, trap, GameManager.make_hazard_rng(10))
			check(game.level.theme == load(FUNGAL), "the full game draws the third depth as the fungal catacombs")
			check(not cells.is_empty() and cells == expected,
					"its section has the puffballs picked from the run's hazard stream: %s" % [cells])
		else:
			check(cells.is_empty(), "the clean series has none")
		game.queue_free()
		await physics_frames(2)
	GameManager.config = saved
