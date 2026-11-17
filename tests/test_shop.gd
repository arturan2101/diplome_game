extends TestCase
## Headless test for the shop: the stock (3-4 offers from the generator, the same for the
## same seed, prices growing with depth, cheaper at a wandering merchant, spell offers
## that raise a known spell or bring a new one), buying in the game (coins taken, the
## goods handed, sold out, unaffordable offers off, the log), and bots never trading.

const GAME_SCENE: String = "res://main/main.tscn"
const MERCHANT_SCENE: String = "res://actors/npc/merchant.tscn"
const SHOP: String = "res://shop/shop.tres"
const WEAPONS: String = "res://combat/weapons/chest_weapons.tres"
const RARITY: String = "res://combat/weapons/rarity_table.tres"
const SPELLS: String = "res://combat/spells/spell_pool.tres"
const FIREBALL: String = "res://combat/spells/fireball.tres"
const RUN_SEED: int = 31
const SEEDS: int = 60


func run() -> void:
	_test_stock()
	await _test_buying()


func _test_stock() -> void:
	var data: ShopData = load(SHOP) as ShopData
	var weapons: WeaponPool = load(WEAPONS) as WeaponPool
	var rarity: RarityTable = load(RARITY) as RarityTable
	var spells: SpellPool = load(SPELLS) as SpellPool
	var sizes_ok: bool = true
	var same: bool = true
	var dearer: bool = true
	var cheaper: bool = true
	var kinds: Dictionary = {}
	for i in SEEDS:
		var offers: Array[ShopOffer] = ShopStock.make_offers(data, 0, _rng(i), weapons, rarity, spells, null, false)
		var again: Array[ShopOffer] = ShopStock.make_offers(data, 0, _rng(i), weapons, rarity, spells, null, false)
		var deep: Array[ShopOffer] = ShopStock.make_offers(data, 3, _rng(i), weapons, rarity, spells, null, false)
		var wandering: Array[ShopOffer] = ShopStock.make_offers(data, 0, _rng(i), weapons, rarity, spells, null, true)
		if offers.size() < data.min_offers or offers.size() > data.max_offers:
			sizes_ok = false
		for k in offers.size():
			kinds[offers[k].kind] = true
			if again[k].get_id() != offers[k].get_id() or again[k].price != offers[k].price:
				same = false
			if deep[k].get_id() == offers[k].get_id() and deep[k].price <= offers[k].price:
				dearer = false
			if wandering[k].price > offers[k].price or (offers[k].price > 3 and wandering[k].price >= offers[k].price):
				cheaper = false
	check(sizes_ok and kinds.size() == 3, "a merchant offers 3-4 things: healing, weapons and spells")
	check(same, "the same generator gives the same stock")
	check(dearer and cheaper, "prices grow with depth, and a wandering merchant sells cheaper")
	var book: SpellBook = SpellBook.new()
	add_child(book)
	book.learn(load(FIREBALL) as SpellData)
	var raises: int = 0
	var new_first: int = 0
	for i in SEEDS:
		var raised: bool = false
		for offer: ShopOffer in ShopStock.make_offers(data, 0, _rng(i), weapons, rarity, spells, book, false):
			if offer.kind == ShopOffer.Kind.SPELL_LEVEL and offer.spell.id == &"fireball" and offer.spell_level == 2:
				raises += 1
				raised = true
			elif offer.kind == ShopOffer.Kind.SPELL and not raised:
				new_first += 1
	check(raises > 0 and new_first == 0, "a known spell is offered at its next level before any new one")
	var no_spells: bool = true
	for i in SEEDS:
		for offer: ShopOffer in ShopStock.make_offers(data, 0, _rng(i), weapons, rarity, null, null, false):
			if offer.kind == ShopOffer.Kind.SPELL or offer.kind == ShopOffer.Kind.SPELL_LEVEL:
				no_spells = false
	check(no_spells, "without spells in the series the shop sells none")
	book.queue_free()


func _test_buying() -> void:
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config("full")
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	var merchant: Merchant = (load(MERCHANT_SCENE) as PackedScene).instantiate() as Merchant
	var heal: ShopOffer = ShopOffer.new()
	heal.kind = ShopOffer.Kind.HEAL
	heal.heal_amount = 40
	heal.price = 5
	var dear: ShopOffer = ShopOffer.new()
	dear.kind = ShopOffer.Kind.HEAL
	dear.heal_amount = 40
	dear.price = 1000
	merchant.offers = [heal, dear] as Array[ShopOffer]
	merchant.shop_requested.connect(game._on_shop_requested)
	game.add_section_node(merchant)
	merchant.global_position = game.player.global_position + Vector2(16.0, 0.0)
	GameManager.add_coins(12 - GameManager.coins)
	game.player.health.take_damage(DamageInfo.new(50, null, &"test"))
	merchant.interact(game.player)
	var screen: ShopScreen = game.shop_screen
	var buttons: Array[Button] = screen.get_offer_buttons()
	check(screen.is_open() and get_tree().paused and buttons.size() == 2 and not buttons[0].disabled and buttons[1].disabled,
			"talking to the merchant opens the shop and pauses the game; what the player cannot pay for is off")
	buttons[0].pressed.emit()
	check(GameManager.coins == 7 and game.player.health.hp == 90 and heal.sold and screen.get_offer_buttons()[0].disabled,
			"buying takes the coins and hands the goods once")
	screen.close()
	check(not screen.is_open() and not get_tree().paused, "leaving the shop goes on with the game")
	var record: Dictionary = Telemetry.end_section(false)
	check(record.get("purchases") == ["heal"] and record.get("coins_spent") == 5, "the log lists the purchases and the coins spent")
	await _test_swap(game, merchant)
	game.add_bot(BotPlayer.load_profile("mid"))
	merchant.interact(game.player)
	check(not screen.is_open(), "a bot does not trade (the shop would pause its run)")
	game.queue_free()
	GameManager.config = GameManager.DEFAULT_CONFIG
	Telemetry.write_enabled = write_was
	await physics_frames(3)


## Both spell slots full: a new spell is still sold ("swap"); buying it asks which spell
## to forget, and it is paid only when a slot is chosen; then the shop opens again.
func _test_swap(game: Game, merchant: Merchant) -> void:
	var book: SpellBook = game.player.spell_book
	var spells: SpellPool = load(SPELLS) as SpellPool
	book.learn(spells.spells[0])
	book.learn(spells.spells[1])
	var fresh: SpellData = spells.spells[2]
	var stock: Array[ShopOffer] = []
	for i in SEEDS:
		stock.append_array(ShopStock.make_offers(load(SHOP) as ShopData, 0, _rng(i), null, null, spells, book, false))
	var swaps: bool = false
	for offer: ShopOffer in stock:
		if offer.kind == ShopOffer.Kind.SPELL and offer.replaces and offer.spell == fresh:
			swaps = true
	check(swaps, "with both slots full the merchant still sells a new spell, as a swap")
	var swap: ShopOffer = ShopOffer.new()
	swap.kind = ShopOffer.Kind.SPELL
	swap.spell = fresh
	swap.replaces = true
	swap.price = 3
	merchant.offers = [swap] as Array[ShopOffer]
	var coins: int = GameManager.coins
	Telemetry.begin_section(game.plan, game.layout, game.player)
	merchant.interact(game.player)
	var screen: ShopScreen = game.shop_screen
	check(not screen.get_offer_buttons()[0].disabled and swap.get_title().ends_with("(swap)"), "the swap can be bought")
	screen.get_offer_buttons()[0].pressed.emit()
	check(not screen.is_open() and game.spell_choice.is_open() and GameManager.coins == coins,
			"buying it asks which spell to forget, nothing is paid yet")
	game.spell_choice.back_button.pressed.emit()
	check(screen.is_open() and not swap.sold and GameManager.coins == coins and book.level_of(fresh.id) == 0,
			"keeping the old spells costs nothing and goes back to the shop")
	screen.get_offer_buttons()[0].pressed.emit()
	var slots: Array[Button] = []
	for child: Node in game.spell_choice.choices.get_children():
		if child is Button and not child.is_queued_for_deletion():
			slots.append(child)
	slots[0].pressed.emit()
	check(book.get_spell(0).data == fresh and swap.sold and GameManager.coins == coins - swap.price and screen.is_open(),
			"choosing a slot swaps the spell and takes the coins; the shop opens again")
	screen.close()
	var record: Dictionary = Telemetry.end_section(false)
	check(record.get("purchases") == [swap.get_id()], "the swap is logged as a purchase (%s)" % [record.get("purchases")])


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
