extends TestCase
## Headless test for batch 8's weapon levels and critical hits (stage 39): levels in the
## data, critical hits that only touch the random stream when they are possible, the
## player's switch for them, the sure critical hit after a parry, the level marks in the
## HUD and the card of a weapon on the floor. After stage 49 weapons no longer grow with
## a boss: chests and merchants hand them out at a level rolled by depth
## (combat/weapons/level_table.tres), never high on the first floor.

const SWORD: String = "res://combat/weapons/sword.tres"
const BOW: String = "res://combat/weapons/bow.tres"
const RARE: String = "res://combat/weapons/rarity/rare.tres"
const ARCHER_BOW: String = "res://actors/enemies/archer_bow.tres"
const SPEAR: String = "res://combat/weapons/spear.tres"
const PICKUP_SCENE: String = "res://actors/pickups/weapon_pickup.tscn"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const GAME_SCENE: String = "res://main/main.tscn"
const DRAWS: int = 4000
const LEVELS: String = "res://combat/weapons/level_table.tres"
const SHOP: String = "res://shop/shop.tres"
const CHEST_WEAPONS: String = "res://combat/weapons/chest_weapons_arsenal.tres"
const ROLLS: int = 600


func run() -> void:
	_test_data()
	_test_make_hit()
	_test_level_table()
	_test_shop_levels()
	await _test_player_switch()
	await _test_levels_in_game()
	await _test_weapon_card()


func _test_data() -> void:
	var sword: WeaponData = load(SWORD) as WeaponData
	check(sword.level == 1 and is_equal_approx(sword.get_level_multiplier(), 1.0), "a found weapon is level 1")
	var level_two: WeaponData = sword.with_level(2)
	var too_high: WeaponData = sword.with_level(9)
	check(sword.level == 1 and level_two.level == 2 and too_high.level == sword.max_level,
			"with_level makes a copy and stops at the top level")
	check(is_equal_approx(level_two.get_damage_multiplier(), 1.0 + sword.damage_per_level)
			and is_equal_approx(sword.with_level(3).get_damage_multiplier(), 1.0 + 2.0 * sword.damage_per_level),
			"every level adds damage_per_level")
	var rare: WeaponData = sword.with_rarity(load(RARE) as WeaponRarity).with_level(2)
	check(is_equal_approx(rare.get_damage_multiplier(), 1.3 * 1.25), "rarity and level multiply")
	check(rare.get_full_name() == "Rare Sword Lv2" and sword.get_full_name() == "Common Sword",
			"the name shows the level once it has grown")
	check(is_equal_approx(sword.get_crit_chance(), 0.05) and is_equal_approx(rare.get_crit_chance(), 0.08),
			"crit chance: sword 5%%, rare sword 8%%")
	check((load(ARCHER_BOW) as WeaponData).get_crit_chance() == 0.0, "enemy weapons never crit")
	var lines: Array[String] = []
	for line: Dictionary in sword.get_card_stats():
		lines.append(line["name"])
	var expected: Array[String] = ["Damage", "Hits/s", "Reach", "Crit"]
	check(lines == expected, "the sword's card lines: %s" % [lines])


func _test_make_hit() -> void:
	var weapon: Weapon = Weapon.new()
	weapon.setup(load(SWORD) as WeaponData, null)
	weapon.damage_multiplier = 1.5
	weapon.crit_chance = 0.0
	var before: int = GameManager.rng.state
	var plain: DamageInfo = weapon.make_hit(10.0, Vector2(5.0, 0.0))
	check(plain.amount == 15 and not plain.is_critical and plain.knockback == Vector2(5.0, 0.0)
			and plain.source_id == &"sword", "a plain hit: damage times the multiplier")
	check(GameManager.rng.state == before, "a weapon that cannot crit does not draw from the random stream")
	weapon.crit_chance = 1.0
	weapon.crit_multiplier = 2.0
	var critical: DamageInfo = weapon.make_hit(10.0)
	check(critical.amount == 30 and critical.is_critical, "a critical hit doubles the damage")
	weapon.crit_chance = 0.25
	var crits: int = 0
	for _i in DRAWS:
		if weapon.make_hit(10.0).is_critical:
			crits += 1
	check(absf(float(crits) / DRAWS - 0.25) < 0.03, "about a quarter of hits crit at 25%% (%d of %d)" % [crits, DRAWS])
	weapon.free()


func _test_player_switch() -> void:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	await physics_frames(1)
	player.add_weapon(load(SWORD) as WeaponData)
	check(player.weapon.crit_chance == 0.0, "without the switch the player's weapons never crit")
	player.critical_hits = true
	player.add_weapon(load(BOW) as WeaponData)
	player.swap_weapon()
	check(is_equal_approx(player.weapon.crit_chance, 0.05), "with it the bow crits 5%% of the time")
	player.grant_sure_crit(1.0)
	check(player.weapon.make_hit(10.0).is_critical and not player.consume_sure_crit(),
			"after a parry the next hit is a sure critical hit, only once")
	player.grant_sure_crit(0.1)
	await physics_frames(roundi(0.2 * Engine.physics_ticks_per_second))
	check(not player.consume_sure_crit(), "the sure critical hit runs out")
	player.damage_bonus = 1.2
	var changes: Array[int] = [0]
	player.weapon_changed.connect(func(_slot: int, _data: WeaponData) -> void: changes[0] += 1)
	check(player.raise_active_weapon_level() and player.weapon.data.level == 2 and changes[0] == 1
			and is_equal_approx(player.weapon.damage_multiplier, 1.25 * 1.2),
			"a whetstone raises the weapon in hand to level 2 (with the camp's bonus)")
	player.raise_active_weapon_level()
	check(not player.raise_active_weapon_level() and player.weapon.data.level == 3, "level 3 is the top")
	player.queue_free()
	await physics_frames(1)


## In the full game (the tests' default config) the HUD shows level marks under the
## weapon; a boss no longer raises it (after stage 49).
func _test_levels_in_game() -> void:
	check(GameManager.config.arsenal, "the default config has batch 8 on")
	GameManager.start_run(4242)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	var pips: TextureRect = game.hud.get_weapon_pips(0)
	check(pips != null and pips.visible and (pips.texture as AtlasTexture).region.position.x == 0.0,
			"one level mark under the weapon in hand")
	check(game.player.critical_hits and game.player.weapon.crit_chance > 0.0, "the game switches critical hits on")
	game._on_boss_defeated(game.player)
	check(game.player.weapon.data.level == 1, "beating a boss does not raise the weapon")
	game.player.raise_active_weapon_level()
	check((pips.texture as AtlasTexture).region.position.x == game.hud.level_pip_size.x, "level 2 shows two marks")
	var first_floor: bool = true
	GameManager.depth = 0
	for _i in ROLLS:
		var found: WeaponData = game._roll_chest_weapon()
		first_floor = first_floor and found.level < 3
	check(first_floor, "a chest on the first floor never holds a level 3 weapon")
	var deep_levels: Dictionary = {}
	GameManager.depth = 6
	for _i in ROLLS:
		deep_levels[game._roll_chest_weapon().level] = true
	check(deep_levels.has(2) and deep_levels.has(3), "deeper chests hold level 2 and 3 weapons too")
	GameManager.depth = 0
	game.queue_free()
	await physics_frames(2)


## The card of a weapon on the floor: its name and numbers against the weapon in hand,
## refreshed when the player swaps weapons in place.
func _test_weapon_card() -> void:
	GameManager.start_run(4243)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	var card: WeaponCard = game.hud.weapon_card
	check(card != null and not card.visible, "no card while no weapon is near")
	var pickup: WeaponPickup = (load(PICKUP_SCENE) as PackedScene).instantiate() as WeaponPickup
	pickup.weapon_data = (load(BOW) as WeaponData).with_rarity(load(RARE) as WeaponRarity)
	game.add_child(pickup)
	await physics_frames(1)
	game.hud._on_interaction_changed(pickup)
	var rows: Array[PackedStringArray] = card.get_rows()
	var names: Array[String] = []
	for row: PackedStringArray in rows:
		names.append(row[0])
	check(card.visible and card.get_title() == "Rare Bow", "the card names the rare bow")
	check(names.has("Damage") and names.has("Draw") and names.has("Hits/s") and names.has("Crit"),
			"bow lines, the sword's own lines and crit: %s" % [names])
	var holder: Control = card.get_parent() as Control
	check(not Rect2(card.position, card.size).has_point(holder.size * 0.5) and card.position.x + card.size.x <= holder.size.x,
			"the card sits on the right, away from the player in the middle")
	game.player.add_weapon(load(SPEAR) as WeaponData)
	pickup.interact(game.player)
	await physics_frames(2)
	check(card.visible and card.get_title() == "Common Sword", "after a swap in place the card shows the sword left on the floor")
	game.hud._on_interaction_changed(null)
	check(not card.visible, "the card hides when the player walks away")
	game.queue_free()
	await physics_frames(2)


func _test_level_table() -> void:
	var table: WeaponLevelTable = load(LEVELS) as WeaponLevelTable
	check(table.chance(3, 0) == 0.0 and table.chance(1, 0) >= 0.85, "on the first floor almost every weapon is level 1, none level 3")
	var rising: bool = true
	for depth in range(1, 6):
		rising = rising and table.chance(3, depth) >= table.chance(3, depth - 1) and table.chance(1, depth) <= table.chance(1, depth - 1)
	check(rising, "higher levels come gradually deeper down")
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 49
	var counts: Dictionary = {}
	for _i in DRAWS:
		var level: int = table.pick(2, rng)
		counts[level] = int(counts.get(level, 0)) + 1
	check(absf(float(counts.get(3, 0)) / DRAWS - table.chance(3, 2)) < 0.03, "rolls follow the table (%s)" % [counts])


func _test_shop_levels() -> void:
	var data: ShopData = load(SHOP) as ShopData
	var weapons: WeaponPool = load(CHEST_WEAPONS) as WeaponPool
	var table: WeaponLevelTable = load(LEVELS) as WeaponLevelTable
	var priced: bool = true
	var levels_seen: Dictionary = {}
	var plain_levels: bool = true
	for i in 80:
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 4900 + i
		for offer: ShopOffer in ShopStock.make_offers(data, 5, rng, weapons, null, null, null, false, null, [], table):
			if offer.kind != ShopOffer.Kind.WEAPON:
				continue
			levels_seen[offer.weapon.level] = true
			var base: float = data.weapon_price * (1.0 + data.weapon_level_price * float(offer.weapon.level - 1))
			priced = priced and offer.price == data.price_for(base, 5, false)
		rng.seed = 4900 + i
		for offer: ShopOffer in ShopStock.make_offers(data, 5, rng, weapons, null, null, null, false):
			plain_levels = plain_levels and (offer.kind != ShopOffer.Kind.WEAPON or offer.weapon.level == 1)
	check(levels_seen.size() >= 2 and priced, "merchants sell weapons of several levels, each level adding to the price")
	check(plain_levels, "without a level table every weapon is level 1")
