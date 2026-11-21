extends TestCase
## Headless test for the merchant's goods of stage 42: without goods the stock is the
## same as before (the same draws), with them goods turn up and the dice come last;
## in the game each good does its thing (whetstone, heart elixir, lucky charm, dice,
## rune key) and the clean series sells none.

const SHOP: String = "res://shop/shop.tres"
const WEAPONS: String = "res://combat/weapons/chest_weapons.tres"
const GAME_SCENE: String = "res://main/main.tscn"
const MERCHANT_SCENE: String = "res://actors/npc/merchant.tscn"
const SEEDS: int = 60
const RUN_SEED: int = 24


func run() -> void:
	_test_stock()
	await _test_in_game()
	await _test_rune_key()
	await _test_clean()


func _test_stock() -> void:
	var data: ShopData = load(SHOP) as ShopData
	var weapons: WeaponPool = load(WEAPONS) as WeaponPool
	var same: bool = true
	for i in SEEDS:
		var plain: Array[ShopOffer] = ShopStock.make_offers(data, 1, _rng(i), weapons, null, null, null, false)
		var empty: Array[ShopOffer] = ShopStock.make_offers(data, 1, _rng(i), weapons, null, null, null, false, null, [])
		if plain.size() != empty.size():
			same = false
			continue
		for j in plain.size():
			if plain[j].get_id() != empty[j].get_id() or plain[j].price != empty[j].price:
				same = false
	check(same, "without goods the stock is exactly what it was")
	var seen: Dictionary = {}
	var dice_last: bool = true
	var drawn: bool = true
	for i in SEEDS:
		var offers: Array[ShopOffer] = ShopStock.make_offers(data, 1, _rng(i), weapons, null, null, null, false, null, data.goods)
		dice_last = dice_last and offers.back().goods == &"dice"
		for offer: ShopOffer in offers:
			if offer.kind == ShopOffer.Kind.GOODS:
				seen[offer.goods] = true
				drawn = drawn and offer.get_icon() != null and offer.get_title() != "" and offer.price > 0
	check(dice_last, "the dice always come last")
	check(seen.size() == 5 and drawn, "all goods turn up, each with an icon, a title and a price: %s" % [seen.keys()])


func _test_in_game() -> void:
	var game: Game = await _start("full", RUN_SEED)
	var data: ShopData = game.shop_data
	var merchant: Merchant = (load(MERCHANT_SCENE) as PackedScene).instantiate() as Merchant
	game._contents.add_child(merchant)
	merchant.global_position = game.player.global_position + Vector2(16.0, 0.0)
	GameManager.add_coins(1000)
	var offers: Array[ShopOffer] = []
	for good: StringName in [&"whetstone", &"elixir", &"charm", &"dice"]:
		var offer: ShopOffer = ShopOffer.new()
		ShopStock._make_goods(offer, good, data)
		offer.price = 1
		offers.append(offer)
	merchant.offers = offers
	game._check_goods(merchant.offers)
	game.shop_screen.open(merchant, GameManager.coins, game.player.spell_book)
	var max_hp: int = game.player.health.max_hp
	var luck: int = game._chest_luck()
	game._on_shop_bought(offers[0])
	game._on_shop_bought(offers[1])
	game._on_shop_bought(offers[2])
	check(game.player.weapon.data.level == 2, "the whetstone raises the weapon in hand to level 2")
	check(game.player.health.max_hp == max_hp + data.elixir_max_hp, "the heart elixir adds %d max HP" % data.elixir_max_hp)
	check(game._chest_luck() == luck + 1, "the lucky charm rolls chest rarity one depth ahead")
	game.player.raise_active_weapon_level()
	var stone: ShopOffer = ShopOffer.new()
	ShopStock._make_goods(stone, &"whetstone", data)
	game._check_goods([stone] as Array[ShopOffer])
	check(not stone.is_available(game.player.spell_book), "no whetstone for a weapon at its top level")
	var before: Array[ShopOffer] = merchant.offers
	game._on_shop_bought(offers[3])
	check(merchant.offers != before and not merchant.offers.is_empty() and merchant.offers.back().goods == &"dice",
			"the dice bring new goods (with new dice at the end)")
	check(Telemetry._purchases.has("whetstone") and Telemetry._purchases.has("dice"), "the log names the goods bought")
	game.shop_screen.close()
	await _stop(game)


## A rune key bought earlier breaks the next hidden room's wall as soon as it appears.
func _test_rune_key() -> void:
	var opened: bool = false
	for attempt in 6:
		var game: Game = await _start("full", RUN_SEED + attempt)
		var settings: DirectorSettings = game._director.settings.duplicate() as DirectorSettings
		var data: SecretRoomData = settings.secret_room.duplicate() as SecretRoomData
		data.chance = 1.0
		settings.secret_room = data
		game._director.settings = settings
		game._rune_keys = 1
		game._start_section()
		await physics_frames(4)
		if not game.layout.secret.is_empty():
			opened = game._rune_keys == 0 and game.level.grid.is_floor(game.layout.secret["crack"])
			await _stop(game)
			break
		await _stop(game)
	check(opened, "the rune key is used up and the hidden room opens by itself")


func _test_clean() -> void:
	var game: Game = await _start("clean", RUN_SEED)
	check(game.get_shop_goods().is_empty(), "the clean series sells no goods")
	await _stop(game)


func _start(series: String, run_seed: int) -> Game:
	GameManager.config = GameManager.load_config(series)
	GameManager.start_run(run_seed)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	return game


func _stop(game: Game) -> void:
	game.queue_free()
	GameManager.config = GameManager.DEFAULT_CONFIG
	await physics_frames(2)


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
