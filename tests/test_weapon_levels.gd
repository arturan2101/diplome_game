extends TestCase
## Headless test for batch 8's weapon levels and critical hits (stage 39): levels in the
## data, critical hits that only touch the random stream when they are possible, the
## player's switch for them, levels after a boss, the sure critical hit after a parry
## the level marks in the HUD and the card of a weapon on the floor.

const SWORD: String = "res://combat/weapons/sword.tres"
const BOW: String = "res://combat/weapons/bow.tres"
const RARE: String = "res://combat/weapons/rarity/rare.tres"
const ARCHER_BOW: String = "res://actors/enemies/archer_bow.tres"
const SPEAR: String = "res://combat/weapons/spear.tres"
const PICKUP_SCENE: String = "res://actors/pickups/weapon_pickup.tscn"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const GAME_SCENE: String = "res://main/main.tscn"
const DRAWS: int = 4000


func run() -> void:
	_test_data()
	_test_make_hit()
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
	var raised: int = player.raise_weapon_levels()
	check(raised == 2 and player.weapon.data.level == 2 and changes[0] == 1
			and is_equal_approx(player.weapon.damage_multiplier, 1.25 * 1.2),
			"after a boss both weapons are level 2 and hit harder (with the camp's bonus)")
	player.raise_weapon_levels()
	check(player.raise_weapon_levels() == 0 and player.weapon.data.level == 3, "level 3 is the top")
	player.queue_free()
	await physics_frames(1)


## In the full game (the tests' default config) a boss raises the carried weapons and the
## HUD shows level marks under them.
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
	check(game.player.weapon.data.level == 2 and (pips.texture as AtlasTexture).region.position.x == game.hud.level_pip_size.x,
			"after the boss the weapon is level 2 and shows two marks")
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
