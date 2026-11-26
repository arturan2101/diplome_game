extends TestCase
## Headless test for the fixes of stage 47: obstacles on cover cells break under sword
## blows and leave floor (gravestones stay; the pictures around do not change), a secret
## room's crack never has the exit portal in front of it, the merchant wins over a weapon
## at his feet, and floor patches (the magma beetle's lava) lie under the actors.

const SETTINGS: String = "res://director/director_settings.tres"
const SECRET_ROOM: String = "res://generation/secret_room.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const MERCHANT_SCENE: String = "res://actors/npc/merchant.tscn"
const WEAPON_PICKUP_SCENE: String = "res://actors/pickups/weapon_pickup.tscn"
const SWORD: String = "res://combat/weapons/sword.tres"
const LAVA: String = "res://combat/spells/lava.tres"
const CLEAN: String = "res://experiment/clean.tres"
const SECTIONS: int = 80
## A row of cover cells under a wall (obstacles fit there), floor below.
const COVER_MAP: String = """############
#%%%%%%%%%%#
#..........#
#..........#
############"""


func run() -> void:
	_test_config()
	await _test_obstacles_break()
	_test_secret_clear_of_gate()
	await _test_merchant_first()
	await _test_floor_effects()


func _test_config() -> void:
	check(GameManager.config.breakable_cover and not (load(CLEAN) as ExperimentConfig).breakable_cover,
			"breakable obstacles: on in the full game, off in the clean series")


func _test_obstacles_break() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(COVER_MAP))
	await physics_frames(3)
	var obstacles: Array[Dictionary] = level.obstacles()
	var cover_cells: int = 0
	for x in range(1, 11):
		if level.grid.get_cell(Vector2i(x, 1)) == LevelGrid.Cell.COVER:
			cover_cells += 1
	check(not obstacles.is_empty(), "the row shows obstacles (%d)" % obstacles.size())
	# The obstacle to break and the pictures of the others before.
	var target: Dictionary = obstacles[0]
	var before: Dictionary = {}
	for obstacle: Dictionary in obstacles.slice(1):
		before[obstacle["cells"][0]] = obstacle["piece"]
	var cells: Array[Vector2i] = target["cells"]
	var tile: float = float(level.theme.tile_size)
	var cover: BreakableCover = BreakableCover.new()
	cover.setup(cells, Rect2(level.to_global(Vector2(cells[0]) * tile), Vector2(tile * cells.size(), tile)), level.theme.cover_piece_hp)
	cover.broken.connect(func(broken: BreakableCover) -> void: level.set_cells.call_deferred(broken.cells, LevelGrid.Cell.FLOOR))
	level.add_child(cover)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.add_weapon(load(SWORD) as WeaponData)
	player.global_position = level.cell_center(cells[0] + Vector2i.DOWN)
	await physics_frames(3)
	var blows: int = 0
	while is_instance_valid(cover) and not cover.is_broken() and blows < 6:
		player.weapon.try_attack(Vector2.UP)
		player.weapon.release_attack(Vector2.UP)
		blows += 1
		await physics_frames(roundi(0.7 * Engine.physics_ticks_per_second))
	check(blows == 2, "a sword breaks an obstacle in two blows (%d)" % blows)
	await physics_frames(2)
	var floor_now: bool = true
	for cell: Vector2i in cells:
		if level.grid.get_cell(cell) != LevelGrid.Cell.FLOOR:
			floor_now = false
	check(floor_now, "its cells are floor now")
	var same: bool = true
	for cell: Vector2i in before:
		if level.cover_piece(cell) != before[cell]:
			same = false
	check(same, "the obstacles around keep their pictures")
	player.queue_free()
	level.queue_free()
	await physics_frames(2)


## With a secret room in every section that fits one, its crack never has the portal
## right in front of it.
func _test_secret_clear_of_gate() -> void:
	var settings: DirectorSettings = (load(SETTINGS) as DirectorSettings).duplicate() as DirectorSettings
	var secret: SecretRoomData = (load(SECRET_ROOM) as SecretRoomData).duplicate() as SecretRoomData
	secret.chance = 1.0
	settings.secret_room = secret
	var director: RuleDirector = RuleDirector.new(null, settings)
	var builder: SectionBuilder = SectionBuilder.new()
	var placed: int = 0
	var clear: bool = true
	for i in SECTIONS:
		var state: PlayerState = PlayerState.new()
		state.section_index = i
		state.depth = i % 3
		state.rng.seed = 4700 + i
		var plan: SectionPlan = director.choose_next(state)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 470 + i
		var layout: SectionLayout = builder.build(plan, rng)
		if layout.secret.is_empty():
			continue
		placed += 1
		var front: Vector2i = layout.secret["crack"] + Vector2i(layout.secret["front"])
		for cell: Vector2i in SectionBuilder.gate_footprint(layout.exit):
			if absi(cell.x - front.x) <= SectionBuilder.SECRET_GATE_CLEARANCE and absi(cell.y - front.y) <= SectionBuilder.SECRET_GATE_CLEARANCE:
				clear = false
	check(placed > SECTIONS / 3, "secret rooms are placed (%d of %d)" % [placed, SECTIONS])
	check(clear, "no secret room's crack has the portal in front of it")


func _test_merchant_first() -> void:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.global_position = Vector2(200.0, 200.0)
	var merchant: Merchant = (load(MERCHANT_SCENE) as PackedScene).instantiate() as Merchant
	add_child(merchant)
	merchant.global_position = Vector2(200.0, 186.0)
	merchant.offers = [ShopOffer.new()] as Array[ShopOffer]
	var pickup: WeaponPickup = (load(WEAPON_PICKUP_SCENE) as PackedScene).instantiate() as WeaponPickup
	pickup.weapon_data = load(SWORD) as WeaponData
	add_child(pickup)
	pickup.global_position = Vector2(210.0, 200.0)
	await physics_frames(2)
	player._update_interaction()
	check(player.interaction_target == merchant, "a weapon lying a little closer does not hide the merchant")
	# After stage 49: a spell lying next to him could never be taken; the priority is
	# only a head start now.
	player.global_position = pickup.global_position
	player._update_interaction()
	check(player.interaction_target == pickup, "standing on the weapon next to him, it can be taken")
	player.global_position = Vector2(222.0, 212.0)
	player._update_interaction()
	check(player.interaction_target == pickup, "and stepping away from him too")
	for node: Node in [player, merchant, pickup]:
		node.queue_free()
	await physics_frames(2)


## A patch spawned next to the actors goes on the level's floor layer, under them.
func _test_floor_effects() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(COVER_MAP))
	var contents: Node2D = Node2D.new()
	level.add_child(contents)
	await physics_frames(1)
	var zone: SpellZone = SpellZone.spawn(contents, level.cell_center(Vector2i(3, 2)), load(LAVA) as ZoneData, 1, null, &"magma_beetle", 8, 1)
	check(zone.get_parent() == level.floor_effects and level.floor_effects.get_index() < contents.get_index(),
			"the lava lies on the floor layer, drawn under the actors")
	level.queue_free()
	await physics_frames(2)
