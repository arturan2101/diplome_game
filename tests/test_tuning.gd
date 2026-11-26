extends TestCase
## Headless test for the full game's tuning after the playtest (stage 38): fewer health
## packs and coins, cover off its template slots and never touching other cover, a
## chest that stays shut next to enemies chasing the player, a secret wall that waits
## for its room's fight; none of it in the clean series.

const GAME_SCENE: String = "res://main/main.tscn"
const CHEST_SCENE: String = "res://actors/pickups/chest.tscn"
const SEEDS: int = 120
const RUN_SEED: int = 38


func run() -> void:
	_test_plans()
	_test_cover()
	await _test_chest()
	await _test_secret_lock()


func _tuned_settings() -> DirectorSettings:
	var settings: DirectorSettings = (load("res://director/director_settings.tres") as DirectorSettings).duplicate() as DirectorSettings
	settings.health_packs_fewer = GameManager.FULL_GAME_FEWER_PACKS
	settings.coin_scale = GameManager.FULL_GAME_COIN_SCALE
	settings.cover_jitter = true
	return settings


func _test_plans() -> void:
	var plain: RuleDirector = RuleDirector.new()
	var tuned: RuleDirector = RuleDirector.new(null, _tuned_settings())
	var packs: Array[int] = [0, 0]
	var coins: Array[int] = [0, 0]
	for i in SEEDS:
		for k in 2:
			var state: PlayerState = PlayerState.new()
			state.section_index = 3
			state.rng = RandomNumberGenerator.new()
			state.rng.seed = i
			state.hp_fraction = 0.2 if i % 3 == 0 else 0.9
			var plan: SectionPlan = (plain if k == 0 else tuned).choose_next(state)
			packs[k] += plan.health_packs
			coins[k] += plan.coins
	check(packs[1] < packs[0] and coins[1] * 3 < coins[0] * 2, "the full game has fewer health packs (%d vs %d) and coins (%d vs %d)"
			% [packs[1], packs[0], coins[1], coins[0]])


func _test_cover() -> void:
	var builder: SectionBuilder = SectionBuilder.new()
	var moved: int = 0
	var touching: int = 0
	for i in SEEDS / 4:
		var plan: SectionPlan = SectionPlan.new()
		plan.room_count = 4
		plan.cover_density = 1.0
		plan.enemy_mix = {&"skeleton": 2}
		var straight: SectionLayout = builder.build(plan, _rng(i))
		plan.cover_jitter = true
		var jittered: SectionLayout = builder.build(plan, _rng(i))
		if jittered.grid.to_text() != straight.grid.to_text():
			moved += 1
		for y in jittered.grid.height:
			for x in jittered.grid.width:
				if jittered.grid.get_cell(Vector2i(x, y)) != LevelGrid.Cell.COVER:
					continue
				for d: Vector2i in [Vector2i.RIGHT, Vector2i.DOWN, Vector2i(1, 1), Vector2i(-1, 1)]:
					if jittered.grid.get_cell(Vector2i(x, y) + d) == LevelGrid.Cell.COVER:
						touching += 1
	check(moved > SEEDS / 8, "cover leaves its neat template slots (%d sections changed)" % moved)
	check(touching <= SEEDS / 8, "moved cover rarely touches other cover (%d pairs, only where a slot could not move)" % touching)


func _test_chest() -> void:
	var game: Game = await _start("full")
	var chest: Chest = (load(CHEST_SCENE) as PackedScene).instantiate() as Chest
	chest.lock_check = game._enemies_chasing_near
	var cell: Vector2i = game.level.nearest_floor_cell(game.level.cell_at(game.player.global_position + Vector2(48.0, 0.0)))
	game.add_section_node(chest)
	chest.global_position = game.level.cell_center(cell)
	var enemy: Enemy = game.spawn_enemy(game.get_enemy_data(&"skeleton"), game.level.nearest_floor_cell(cell + Vector2i(1, 0)))
	await physics_frames(2)
	enemy._enter(Enemy.State.CHASE)
	game.player.teleport(chest.global_position)
	await physics_frames(3)
	check(not chest.is_open, "a chest stays shut while an enemy chasing the player is near")
	enemy.health.take_damage(DamageInfo.new(100000, null, &"test"))
	await physics_frames(4)
	check(chest.is_open, "it opens once the enemy is gone, with the player still on it")
	await _stop(game)


func _test_secret_lock() -> void:
	var game: Game = await _start("full")
	var arena_room: int = game.layout.arena_room
	check(game._is_fight_room(-1) == false, "a secret outside any room never waits")
	if arena_room >= 0:
		check(game._is_fight_room(arena_room), "the arena counts as a fight room")
	# After stage 49: a secret room already open (a rune key) in a room whose doors seal.
	var hole: Vector2i = game.level.nearest_floor_cell(game.layout.room_rects[0].get_center() + Vector2i(2, 0))
	game.layout.secret = {"crack": hole, "room": 0}
	game._secret_open = true
	var room: CombatRoom = CombatRoom.new()
	room.index = 0
	game._on_combat_room_sealed(room)
	check(game.level.grid.get_cell(hole) == LevelGrid.Cell.WALL, "an open secret room is walled up while its room fights")
	game._unlock_secret_wall(0)
	check(game.level.grid.get_cell(hole) == LevelGrid.Cell.FLOOR, "and open again when the fight is over")
	await _stop(game)


func _start(series: String) -> Game:
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config(series)
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	game.player.health.max_hp = 100000
	game.player.health.reset()
	for enemy: Enemy in game.get_enemies():
		enemy.queue_free()
	await physics_frames(1)
	return game


func _stop(game: Game) -> void:
	game.queue_free()
	Telemetry.write_enabled = true
	GameManager.config = GameManager.DEFAULT_CONFIG
	await physics_frames(3)


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
