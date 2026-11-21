extends TestCase
## Headless test for stage 43: until the first boss falls a legendary weapon stays rare in
## chests and shops whatever the chest luck; the fallen boss leaves a larger chest with a
## rare or legendary weapon; the clean series has neither. Also the crossbow's numbers.

const TABLE: String = "res://combat/weapons/rarity_table.tres"
const BOSS_TABLE: String = "res://combat/weapons/boss_rarity_table.tres"
const CLEAN: String = "res://experiment/clean.tres"
const GAME_SCENE: String = "res://main/main.tscn"
const CROSSBOW: String = "res://combat/weapons/crossbow.tres"
const LEGENDARY: int = 2
const EPSILON: float = 0.0001


func run() -> void:
	_test_limited_table()
	_test_boss_table()
	_test_crossbow_numbers()
	await _test_in_game()
	await _test_clean_series()


func _test_limited_table() -> void:
	var table: RarityTable = load(TABLE) as RarityTable
	var before: float = table.chance(LEGENDARY, 3)
	var limited: RarityTable = table.limited(&"legendary", 0.01)
	var capped: bool = true
	for depth in table.weights_by_depth.size():
		if limited.chance(LEGENDARY, depth) > 0.01 + EPSILON:
			capped = false
	check(capped, "with the cap a legendary is at most 1% at every depth (chest luck included)")
	check(is_equal_approx(limited.chance(LEGENDARY, 0), table.chance(LEGENDARY, 0)), "the first floor's 1% stays as it is")
	var ratio_before: float = table.chance(1, 4) / table.chance(0, 4)
	var ratio_after: float = limited.chance(1, 4) / limited.chance(0, 4)
	check(is_equal_approx(ratio_before, ratio_after), "rare and common keep their proportion")
	check(is_equal_approx(table.chance(LEGENDARY, 3), before), "the table itself is not changed")


func _test_boss_table() -> void:
	var table: RarityTable = load(BOSS_TABLE) as RarityTable
	check(table.chance(0, 0) == 0.0 and is_equal_approx(table.chance(LEGENDARY, 0), 0.25),
			"the boss chest: never common, a legendary in a quarter of them")


func _test_crossbow_numbers() -> void:
	var crossbow: CrossbowWeaponData = load(CROSSBOW) as CrossbowWeaponData
	check(crossbow.damage == 20 and is_equal_approx(crossbow.crit_chance, 0.08) and is_equal_approx(crossbow.crit_multiplier, 2.0),
			"the crossbow: 20 damage, 8% crits for x2")


## In the full game (the tests' default config).
func _test_in_game() -> void:
	check(GameManager.config.boss_chest, "the default config has the boss chest on")
	var game: Game = await _make_game(4300)
	var early: RarityTable = game.current_rarity_table()
	check(early != game.rarity_table and early.chance(LEGENDARY, 4) <= 0.01 + EPSILON,
			"before the first boss a legendary is at most 1% even four depths of luck ahead")
	var chests_before: int = _count_chests(game)
	game._on_boss_defeated(game.player)
	await physics_frames(2)
	check(game.current_rarity_table() == game.rarity_table, "after the boss the usual table is back")
	var boss_chest: Chest = null
	for chest: Chest in _chests(game):
		if chest.scale.x > 1.0:
			boss_chest = chest
	check(_count_chests(game) == chests_before + 1 and boss_chest != null, "the fallen boss leaves a larger chest")
	if boss_chest != null:
		var rarity: StringName = boss_chest.loot_weapon.get_rarity().id
		check(rarity == &"rare" or rarity == &"legendary", "with a rare or legendary weapon (%s)" % rarity)
		check(boss_chest.loot_coins >= game.chest_coins_min * 2, "and more coins (%d)" % boss_chest.loot_coins)
		var cell: Vector2i = game.level.cell_at(boss_chest.global_position)
		check(game.level.grid.is_floor(cell) and not cell in SectionBuilder.gate_footprint(game.layout.exit),
				"it stands on floor, not on the portal's cells")
	game.queue_free()
	await physics_frames(2)


func _test_clean_series() -> void:
	var saved: ExperimentConfig = GameManager.config
	GameManager.config = load(CLEAN) as ExperimentConfig
	check(not GameManager.config.boss_chest, "the clean series has no boss chest")
	var game: Game = await _make_game(4301)
	check(game.current_rarity_table() == game.rarity_table, "and no cap on the rarity table")
	game.queue_free()
	await physics_frames(2)
	GameManager.config = saved


func _make_game(run_seed: int) -> Game:
	GameManager.start_run(run_seed)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	return game


func _chests(game: Game) -> Array[Chest]:
	var found: Array[Chest] = []
	for child: Node in game._contents.get_children():
		if child is Chest:
			found.append(child as Chest)
	return found


func _count_chests(game: Game) -> int:
	return _chests(game).size()
