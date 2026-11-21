extends TestCase
## Headless test for spell levels and fusion (stage 26): every element has a look per
## level; the fusion table (pairs in either order, results never found or sold new);
## the balance rule (a merged spell at level 1 is not weaker than the stronger of its two
## spells at level 3, per cast and per second of cooldown, and grows over its own levels
## 1-3); the spell book's merge (frees a slot); the merchant's fusion offers and level-ups
## of merged spells; the effects showing the level's art; the water's ice form freezing
## enemies (not bosses); buying a merge in the game (log, flash, HUD) and no merging in
## clean. The new system of stage 40: four elements, six pairs, three of the third tier.

const FIREBALL: String = "res://combat/spells/fireball.tres"
const WATER: String = "res://combat/spells/water.tres"
const WHIRLWIND: String = "res://combat/spells/whirlwind.tres"
const STEAM: String = "res://combat/spells/steam.tres"
const FUSIONS: String = "res://combat/spells/fusions.tres"
const POOL: String = "res://combat/spells/spell_pool.tres"
const SHOP: String = "res://shop/shop.tres"
const WEAPONS: String = "res://combat/weapons/chest_weapons.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const GAME_SCENE: String = "res://main/main.tscn"
const MERCHANT_SCENE: String = "res://actors/npc/merchant.tscn"
const FLOOR_MAP: String = """###########
#.........#
#.........#
#.........#
#.........#
#.........#
###########"""
const SEEDS: int = 80
const RUN_SEED: int = 26

var _table: FusionTable = null
var _fireball: SpellData = null
var _water: SpellData = null
var _whirlwind: SpellData = null


func run() -> void:
	_table = load(FUSIONS) as FusionTable
	_fireball = load(FIREBALL) as SpellData
	_water = load(WATER) as SpellData
	_whirlwind = load(WHIRLWIND) as SpellData
	_test_looks()
	_test_table_and_balance()
	await _test_book()
	await _test_shop()
	await _test_effects()
	await _test_freeze()
	await _test_game()
	await _test_clean()


func _test_looks() -> void:
	var ok: bool = true
	for spell_data: SpellData in [_fireball, _whirlwind]:
		var names: Array[StringName] = []
		for level in range(1, SpellData.MAX_LEVEL + 1):
			names.append(spell_data.animation_at(level))
		if names.has(&"") or names[0] == names[1] or names[1] == names[2]:
			ok = false
	check(ok, "the fireball and the whirlwind have their own animation on every level")
	check(_fireball.animation_at(9) == _fireball.animation_at(3), "levels past the table use the top look")


func _test_table_and_balance() -> void:
	var pool: SpellPool = load(POOL) as SpellPool
	var pairs: Dictionary = {}
	var well_formed: bool = _table.recipes.size() == 9
	var balanced: bool = true
	var growing: bool = true
	var looks: bool = true
	var report: Array[String] = []
	for recipe: FusionRecipe in _table.recipes:
		if recipe.first == null or recipe.second == null or recipe.result == null or recipe.first == recipe.second:
			well_formed = false
			continue
		var key: String = ",".join(PackedStringArray([recipe.first.id, recipe.second.id]) if recipe.first.id < recipe.second.id
				else PackedStringArray([recipe.second.id, recipe.first.id]))
		if pairs.has(key) or pool.spells.has(recipe.result) or _table.find(recipe.second.id, recipe.first.id) != recipe:
			well_formed = false
		pairs[key] = true
		var best_power: float = maxf(recipe.first.power_at(3), recipe.second.power_at(3))
		var best_rate: float = maxf(recipe.first.power_at(3) / recipe.first.cooldown_at(3),
				recipe.second.power_at(3) / recipe.second.cooldown_at(3))
		var result: SpellData = recipe.result
		report.append("%s %.0f>=%.0f, %.1f/s>=%.1f/s" % [result.id, result.power_at(1), best_power,
				result.power_at(1) / result.cooldown_at(1), best_rate])
		if result.power_at(1) < best_power or result.power_at(1) / result.cooldown_at(1) < best_rate:
			balanced = false
		if not (result.power_at(1) < result.power_at(2) and result.power_at(2) < result.power_at(3)):
			growing = false
		# The new spells of stage 40 are drawn in code until their art arrives: an icon is enough.
		if result.icon == null:
			looks = false
	check(well_formed, "the table: one recipe per pair, found in either order, results are not in the spell pool")
	check(_table.find(&"fireball", &"fireball") == null and _table.find(&"fireball", &"nothing") == null,
			"no recipe for a pair that is not in the table")
	check(balanced, "a merged spell at level 1 is not weaker than the stronger source at level 3 (%s)" % ", ".join(report))
	check(growing, "merged spells have levels 1-3 that grow")
	check(looks, "merged spells have an icon")
	var pool_ids: Array[StringName] = []
	for spell_data: SpellData in pool.spells:
		pool_ids.append(spell_data.id)
	check(pool_ids == ([&"fireball", &"water", &"whirlwind", &"stone_spikes"] as Array[StringName]),
			"four elements turn up in a run: fire, water, air, earth")
	var made: Dictionary = {}
	for pair: Array in [[&"fireball", &"water", &"steam"], [&"fireball", &"whirlwind", &"plasma"],
			[&"fireball", &"stone_spikes", &"lava"], [&"water", &"whirlwind", &"lightning"],
			[&"water", &"stone_spikes", &"vines"], [&"stone_spikes", &"whirlwind", &"sandstorm"],
			[&"lava", &"lightning", &"volcanic_lightning"], [&"lightning", &"steam", &"storm_cloud"],
			[&"lava", &"sandstorm", &"meteor"]]:
		var found: FusionRecipe = _table.find(pair[1], pair[0])
		made[pair[2]] = found != null and found.result.id == pair[2]
	check(not made.values().has(false), "the agreed table: six pairs and three of the third tier (%s)" % [made])
	check(_table.find(&"steam", &"lava") == null and _table.find(&"sandstorm", &"lightning") == null,
			"other pairs of pairs do not merge")


func _test_book() -> void:
	var player: Player = _add_player(Vector2(100.0, 100.0))
	await physics_frames(2)
	var book: SpellBook = player.spell_book
	var recipe: FusionRecipe = _table.find(&"fireball", &"whirlwind")
	_learn(book, _fireball, 3)
	_learn(book, _whirlwind, 2)
	check(not book.can_fuse(recipe) and not book.fuse(recipe) and book.level_of(&"whirlwind") == 2,
			"no merge while one of the two is below the top level")
	check(_table.available(book).is_empty(), "the table offers nothing then")
	_learn(book, _whirlwind, 1)
	var fused: Array[FusionRecipe] = []
	book.spell_fused.connect(func(done: FusionRecipe) -> void: fused.append(done))
	check(_table.available(book) == [recipe] and book.fuse(recipe), "two spells at level 3 merge")
	check(book.get_spell(0) != null and book.get_spell(0).data == recipe.result and book.get_spell(0).level == 1
			and book.get_spell(1) == null and book.has_free_slot(), "the result comes at level 1 into one slot, the other slot is free")
	check(book.level_of(&"fireball") == 0 and book.level_of(&"whirlwind") == 0 and fused == [recipe],
			"both sources are gone, spell_fused was sent")
	check(not book.can_fuse(recipe), "the same merge cannot be done twice")
	book.learn(recipe.result)
	check(book.level_of(recipe.result.id) == 2, "a merged spell levels up like any other")
	player.queue_free()
	await physics_frames(2)


func _test_shop() -> void:
	var data: ShopData = load(SHOP) as ShopData
	var weapons: WeaponPool = load(WEAPONS) as WeaponPool
	var pool: SpellPool = load(POOL) as SpellPool
	var player: Player = _add_player(Vector2(100.0, 100.0))
	await physics_frames(2)
	var book: SpellBook = player.spell_book
	_learn(book, _fireball, 3)
	_learn(book, _water, 3)
	var offers: Array[ShopOffer] = ShopStock.make_offers(data, 1, _rng(1), weapons, null, pool, book, false, _table)
	var steam: FusionRecipe = _table.find(&"fireball", &"water")
	check(offers.size() >= data.min_offers + 1 and offers[0].kind == ShopOffer.Kind.FUSION and offers[0].recipe == steam
			and offers[0].get_id() == "fuse_steam" and offers[0].price == data.price_for(data.fusion_price, 1, false)
			and offers[0].is_available(book), "a merge the player can do comes first, priced by depth")
	var plain: Array[ShopOffer] = ShopStock.make_offers(data, 1, _rng(1), weapons, null, pool, book, false)
	var same_rest: bool = plain.size() == offers.size() - 1
	for i in plain.size():
		if same_rest and (plain[i].kind != offers[i + 1].kind or plain[i].price != offers[i + 1].price):
			same_rest = false
	check(same_rest, "the merge draws nothing: the other offers are the same as without fusion")
	var none: bool = true
	for i in SEEDS:
		for offer: ShopOffer in ShopStock.make_offers(data, 1, _rng(i), weapons, null, pool, book, false):
			if offer.kind == ShopOffer.Kind.FUSION:
				none = false
	check(none, "without a fusion table there are no merge offers")
	book.fuse(steam)
	var raised: bool = false
	var sold_new: bool = false
	for i in SEEDS:
		for offer: ShopOffer in ShopStock.make_offers(data, 1, _rng(i), weapons, null, pool, book, false, _table):
			if offer.spell == steam.result and offer.kind == ShopOffer.Kind.SPELL_LEVEL and offer.spell_level == 2:
				raised = true
			if offer.kind == ShopOffer.Kind.SPELL and _table.results().has(offer.spell):
				sold_new = true
	check(raised and not sold_new, "a merged spell is offered its next level, merged spells are never sold new")
	_learn(book, _whirlwind, 1)
	var fresh: ShopOffer = ShopOffer.new()
	fresh.kind = ShopOffer.Kind.SPELL
	fresh.spell = _fireball
	check(fresh.is_available(book) and not offers[0].is_available(book),
			"a new spell with both slots full can still be taken (as a swap); a merge already done is off")
	player.queue_free()
	await physics_frames(2)


func _test_effects() -> void:
	var level: Level = Level.new()
	level.debug_map = FLOOR_MAP
	add_child(level)
	var player: Player = _add_player(level.cell_center(Vector2i(2, 3)))
	await physics_frames(2)
	var book: SpellBook = player.spell_book
	_learn(book, _fireball, 2)
	book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(2)
	var ball: Fireball = _first_child_of(level, "Fireball") as Fireball
	check(ball != null and ball.get_look() != null and ball.get_look().animation == &"fire_l2" and ball.get_look().is_playing(),
			"a level 2 fireball flies with the level 2 animation")
	await physics_frames(60)
	_learn(book, _fireball, 1)
	book.get_spell(0).cancel()
	await physics_frames(int(_fireball.cooldown_at(3) * 60.0) + 5)
	book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(12)
	check(not _children_of(level, "EffectSprite").is_empty(), "a level 3 fireball leaves a trail of burning ground")
	await physics_frames(60)
	book.replace(0, _whirlwind)
	_learn(book, _whirlwind, 2)
	var wind: WhirlwindSpell = book.get_spell(0) as WhirlwindSpell
	wind.try_cast(Vector2.RIGHT)
	await physics_frames(2)
	var look: AnimatedSprite2D = wind.get_look()
	var radius: float = SpellData.float_at((_whirlwind as WhirlwindData).radius, 3)
	check(look != null and look.visible and look.animation == &"wind_l3"
			and is_equal_approx(look.scale.x, radius * 2.0 / SpellData.frame_size(_whirlwind.frames, &"wind_l3").x),
			"a level 3 whirlwind shows the level 3 ring stretched to its radius")
	wind.cancel()
	check(not look.visible, "the ring goes when the wind ends")
	var steam: FireballData = load(STEAM) as FireballData
	book.replace(1, steam)
	book.get_spell(1).try_cast(Vector2.RIGHT)
	await physics_frames(2)
	var cloud: Fireball = null
	for node: Node in _children_of(level, "Fireball"):
		var candidate: Fireball = node as Fireball
		if candidate.get_look() != null and candidate.get_look().animation == &"steam_l1":
			cloud = candidate
	check(cloud != null and is_zero_approx(cloud.get_look().rotation) and is_equal_approx(cloud.get_look().scale.x, steam.look_scale),
			"the steam flies as a small cloud that does not turn")
	for _i in 120:
		if cloud == null or not is_instance_valid(cloud) or cloud.is_exploding():
			break
		await physics_frames(1)
	await physics_frames(int(steam.blast_time * 30.0))
	var grown: bool = is_instance_valid(cloud) and cloud.is_exploding() and cloud.get_look().visible \
			and cloud.get_look().scale.x > steam.look_scale * 2.0
	check(grown, "at the blast the cloud grows to the blast's size")
	player.queue_free()
	level.queue_free()
	await physics_frames(2)


func _test_freeze() -> void:
	var player: Player = _add_player(Vector2(300.0, 300.0))
	var enemy: Enemy = TestFactory.enemy(TestFactory.melee_enemy_data(&"frozen_test"))
	enemy.data.max_hp = 1000
	add_child(enemy)
	enemy.global_position = Vector2(330.0, 300.0)
	var boss_data: EnemyData = TestFactory.melee_enemy_data(&"boss_test")
	boss_data.is_boss = true
	boss_data.max_hp = 1000
	var boss: Enemy = TestFactory.enemy(boss_data)
	add_child(boss)
	boss.global_position = Vector2(326.0, 318.0)
	await physics_frames(2)
	var water: WaveData = _water as WaveData
	_learn(player.spell_book, water, 3)
	player.spell_book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(3)
	var at: Vector2 = enemy.global_position
	check(enemy.is_frozen() and enemy.visual.modulate == enemy.frozen_color, "the water's ice form (level 3) freezes an enemy it hits")
	check(not boss.is_frozen(), "a boss does not freeze")
	await physics_frames(30)
	check(enemy.global_position.is_equal_approx(at) and enemy.is_frozen(), "a frozen enemy does not move")
	enemy.apply_knockback(Vector2(300.0, 0.0))
	await physics_frames(2)
	check(enemy.global_position.is_equal_approx(at), "a frozen enemy is not pushed")
	var frames: int = 33
	while enemy.is_frozen() and frames < 240:
		await physics_frames(1)
		frames += 1
	check(not enemy.is_frozen() and frames <= int(water.freeze_time * 60.0) + 2
			and enemy.state == Enemy.State.CHASE and enemy.visual.modulate == Color.WHITE,
			"the ice melts after its time (%d frames) and the enemy goes on" % frames)
	for node: Node in [player, enemy, boss]:
		node.queue_free()
	await physics_frames(2)


func _test_game() -> void:
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config("full")
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	var book: SpellBook = game.player.spell_book
	_learn(book, _whirlwind, 3)
	_learn(book, _water, 3)
	var recipe: FusionRecipe = _table.find(&"water", &"whirlwind")
	var offer: ShopOffer = ShopOffer.new()
	offer.kind = ShopOffer.Kind.FUSION
	offer.recipe = recipe
	offer.price = 30
	GameManager.add_coins(100)
	var coins: int = GameManager.coins
	check(game.get_shop_fusions() == game.fusion_table, "the full game merges spells at the merchant")
	var merchant: Merchant = (load(MERCHANT_SCENE) as PackedScene).instantiate() as Merchant
	merchant.offers = [offer] as Array[ShopOffer]
	game.add_child(merchant)
	game.shop_screen.open(merchant, GameManager.coins, book)
	var buttons: Array[Button] = game.shop_screen.get_offer_buttons()
	check(buttons.size() == 1 and not buttons[0].disabled, "the shop shows the merge and it can be bought")
	buttons[0].pressed.emit()
	check(offer.sold and GameManager.coins == coins - offer.price and book.level_of(&"lightning") == 1 and book.has_free_slot(),
			"buying the merge takes the coins and gives the lightning at level 1 with a slot free")
	check(Telemetry._purchases.has("fuse_lightning"), "the log names the merge: fuse_lightning")
	var slot: int = 0 if book.get_spell(0) != null else 1
	var pips: TextureRect = game.hud.get_spell_pips(slot)
	check(pips != null and pips.visible and is_zero_approx((pips.texture as AtlasTexture).region.position.x)
			and not game.hud.get_spell_pips(1 - slot).visible, "the HUD shows the level mark of the merged spell, the free slot has none")
	check(_children_of(game, "EffectSprite").is_empty() and game.shop_screen.get_offer_buttons()[0].disabled,
			"no flash while the shop is open; the merge is sold")
	game.shop_screen.close()
	check(not _children_of(game, "EffectSprite").is_empty(), "the merge flash plays when the shop closes")
	game.queue_free()
	Telemetry.write_enabled = write_was
	GameManager.config = GameManager.DEFAULT_CONFIG
	await physics_frames(3)


func _test_clean() -> void:
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config("clean_soft")
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	check(game.get_shop_fusions() == null, "no merging in the clean series and the playtest")
	game.queue_free()
	Telemetry.write_enabled = write_was
	GameManager.config = GameManager.DEFAULT_CONFIG
	await physics_frames(3)


func _learn(book: SpellBook, spell_data: SpellData, times: int) -> void:
	for _i in times:
		book.learn(spell_data)


func _add_player(at: Vector2) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.global_position = at
	return player


func _children_of(root: Node, type_name: String) -> Array[Node]:
	return root.find_children("*", type_name, true, false)


func _first_child_of(root: Node, type_name: String) -> Node:
	var found: Array[Node] = _children_of(root, type_name)
	return found[0] if not found.is_empty() else null


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
