extends TestCase
## Headless test for secret rooms: the generator (behind a wall of a room of the path,
## cut into solid rock, a chest inside, the way through the section never needs it, the
## rest of the section unchanged), the overgrown tile theme, the cracked wall (a sword
## swung right next to it breaks it; from afar or with an arrow nothing happens), and a
## secret found in the game, in the log.

const GAME_SCENE: String = "res://main/main.tscn"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const ARROW_SCENE: String = "res://actors/projectiles/arrow.tscn"
const SECRET: String = "res://generation/secret_room.tres"
const SWORD: String = "res://combat/weapons/sword.tres"
const SEEDS: int = 40
const RUN_SEED: int = 24
## A room whose east wall hides the secret: the crack is (6, 2), its front is west.
const WALL_MAP: String = """###########
#.....#...#
#.....#...#
#.....#...#
###########"""


func run() -> void:
	_test_generation()
	_test_theme()
	await _test_breaking()
	await _test_in_game()


func _test_generation() -> void:
	var data: SecretRoomData = (load(SECRET) as SecretRoomData).duplicate() as SecretRoomData
	data.chance = 1.0
	var builder: SectionBuilder = SectionBuilder.new()
	var placed: int = 0
	var good: int = 0
	var unchanged: int = 0
	var same: bool = true
	for i in SEEDS:
		var plan: SectionPlan = _plan(data)
		var layout: SectionLayout = builder.build(plan, _rng(900 + i))
		var again: SectionLayout = builder.build(_plan(data), _rng(900 + i))
		if again.grid.to_text() != layout.grid.to_text() or again.secret != layout.secret:
			same = false
		var plain: SectionLayout = builder.build(_plan(null), _rng(900 + i))
		if layout.secret.is_empty():
			continue
		placed += 1
		var crack: Vector2i = layout.secret["crack"]
		var front: Vector2i = layout.secret["front"]
		var interior: Rect2i = layout.secret["rect"]
		var reached: Dictionary = layout.grid.reachable_floor(layout.entrance)
		var chest_inside: bool = false
		for item: Dictionary in layout.items:
			if item.get("secret", false) and item["id"] == SectionLayout.ITEM_CHEST and interior.has_point(item["cell"]):
				chest_inside = true
		var themed: bool = false
		for region: Dictionary in layout.grid.theme_regions:
			if (region["rect"] as Rect2i).encloses(interior) and not (region["rect"] as Rect2i).has_point(crack):
				themed = true
		if (layout.grid.get_cell(crack) == LevelGrid.Cell.WALL and layout.grid.is_floor(crack + front)
				and layout.room_rects[int(layout.secret["room"])].has_point(crack + front)
				and not reached.has(interior.position) and reached.has(layout.exit) and chest_inside and themed
				and SectionBuilder.is_passable(layout)):
			good += 1
		if _differs_only_inside(plain.grid, layout.grid, interior):
			unchanged += 1
	check(placed >= SEEDS * 3 / 4, "a secret room finds a place in most sections (%d of %d)" % [placed, SEEDS])
	check(good == placed, "the crack is a wall of a room of the path with floor in front, the room is closed off, holds a chest and has its own theme (%d of %d)" % [good, placed])
	check(unchanged == placed and same, "the secret only carves its own room: the rest of the section is the same, and the same seed gives the same secret")
	var off: SectionLayout = builder.build(_plan(null), _rng(901))
	check(off.secret.is_empty() and off.grid.theme_regions.is_empty(), "without secret rooms in the plan there is none")
	data.merchant_chance = 1.0
	var merchants: int = 0
	for i in SEEDS:
		var layout: SectionLayout = builder.build(_plan(data), _rng(900 + i))
		for item: Dictionary in layout.items:
			if item["id"] == SectionLayout.ITEM_MERCHANT and item.get("secret", false):
				merchants += 1
	check(merchants >= placed * 3 / 4, "with merchant_chance 1 a wandering merchant waits in the secret rooms (%d)" % merchants)


func _test_theme() -> void:
	var grid: LevelGrid = LevelGrid.from_text(WALL_MAP)
	grid.theme_regions.append({"rect": Rect2i(6, 0, 5, 5), "theme": &"nature"})
	var level: Level = Level.new()
	add_child(level)
	level.build(grid)
	var ground: TileMapLayer = level.get_node("Ground") as TileMapLayer
	check(ground.get_cell_source_id(Vector2i(8, 2)) == Level.REGION_SOURCE_BASE and ground.get_cell_source_id(Vector2i(3, 2)) == Level.MAIN_SOURCE,
			"the secret room's region is drawn with the nature theme, the rest with the ruins")
	level.queue_free()


func _test_breaking() -> void:
	var near: Dictionary = await _swing_at_crack(Vector2i(5, 2), false)
	check(near["broken"], "a sword swung right in front of the crack breaks it")
	var far: Dictionary = await _swing_at_crack(Vector2i(2, 2), false)
	check(not far["broken"], "a sword swung from a few steps away does not")
	var arrow: Dictionary = await _swing_at_crack(Vector2i(3, 2), true)
	check(not arrow["broken"], "an arrow does not break it either")


## A player at `cell` attacks the crack at (6, 2): with the sword, or by shooting an arrow.
func _swing_at_crack(cell: Vector2i, shoot: bool) -> Dictionary:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(WALL_MAP))
	var wall: BreakableWall = BreakableWall.new()
	wall.setup(Vector2i(6, 2), Vector2i.LEFT)
	level.add_child(wall)
	wall.global_position = level.cell_center(Vector2i(6, 2))
	var broken: Array[bool] = [false]
	wall.broken.connect(func(_wall: BreakableWall) -> void: broken[0] = true)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.add_weapon(load(SWORD) as WeaponData)
	player.global_position = level.cell_center(cell)
	await physics_frames(3)
	if shoot:
		var arrow: Arrow = (load(ARROW_SCENE) as PackedScene).instantiate() as Arrow
		arrow.setup(DamageInfo.new(20, player, &"bow"), Vector2.RIGHT, 300.0, 200.0)
		add_child(arrow)
		arrow.global_position = player.global_position
		await physics_frames(30)
	else:
		player.weapon.try_attack(Vector2.RIGHT)
		await physics_frames(30)
	var result: Dictionary = {"broken": broken[0]}
	for node: Node in [player, level]:
		node.queue_free()
	await physics_frames(2)
	return result


func _test_in_game() -> void:
	GameManager.config = GameManager.load_config("full")
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	var game: Game = null
	for attempt in 6:
		GameManager.start_run(RUN_SEED + attempt)
		game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
		game.death_screen_enabled = false
		add_child(game)
		await physics_frames(2)
		var settings: DirectorSettings = game._director.settings.duplicate() as DirectorSettings
		var data: SecretRoomData = settings.secret_room.duplicate() as SecretRoomData
		data.chance = 1.0
		data.merchant_chance = 1.0
		settings.secret_room = data
		game._director.settings = settings
		game._start_section()
		await physics_frames(2)
		if not game.layout.secret.is_empty():
			break
		game.queue_free()
		await physics_frames(2)
		game = null
	check(game != null, "a section of the full game gets a secret room when its chance is 1")
	if game == null:
		GameManager.config = GameManager.DEFAULT_CONFIG
		Telemetry.write_enabled = write_was
		return
	var crack: Vector2i = game.layout.secret["crack"]
	var front: Vector2i = game.layout.secret["front"]
	var room: Rect2i = game.layout.secret["rect"]
	check(not game.level.grid.is_floor(room.position) and game.level.find_children("*", "Merchant", true, false).is_empty(),
			"before the crack is broken the room is rock and nothing of it is there")
	game.player.health.max_hp = 100000
	game.player.health.reset()
	game.player.teleport(game.level.cell_center(crack + front))
	await physics_frames(2)
	game.player.weapon.try_attack(Vector2(-front))
	await physics_frames(30)
	var record: Dictionary = Telemetry.end_section(false)
	check(game.level.grid.is_floor(crack) and game.level.grid.is_floor(room.position) and record.get("secret") == true
			and record.get("secret_found") == true,
			"breaking the crack opens the room, and the log says the section had a secret and it was found")
	check(game.level.find_children("*", "Merchant", true, false).size() == 1, "the wandering merchant appears in the opened room")
	game.queue_free()
	GameManager.config = GameManager.DEFAULT_CONFIG
	Telemetry.write_enabled = write_was
	await physics_frames(3)


func _plan(data: SecretRoomData) -> SectionPlan:
	var plan: SectionPlan = SectionPlan.new()
	plan.room_count = 4
	plan.enemy_mix = {&"skeleton": 2, &"archer": 1}
	plan.secret_room = data
	return plan


## True if the two grids differ only inside the given rect.
func _differs_only_inside(before: LevelGrid, after: LevelGrid, inside: Rect2i) -> bool:
	if before.width != after.width or before.height != after.height:
		return false
	for y in before.height:
		for x in before.width:
			var cell: Vector2i = Vector2i(x, y)
			if before.get_cell(cell) != after.get_cell(cell) and not inside.has_point(cell):
				return false
	return true


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
