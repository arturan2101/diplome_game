extends TestCase
## Headless test for the merchant's glade between depths: the generator (one open
## clearing, merchant, sunlit patch, props, the same for the same seed), the way through
## the game (the arena's gate leads to the glade of the next depth, without enemies; its
## gate leads on to the first section of that depth), the glade's line in the log with
## what was bought, the director seeing it, no glade in the clean series, and where
## spell scrolls may still lie.

const GAME_SCENE: String = "res://main/main.tscn"
const GLADE: String = "res://generation/glade.tres"
const RUN_SEED: int = 25
const SEEDS: int = 20
const MAX_GATES: int = 6

var _glade_lines: Array[Dictionary] = []


func run() -> void:
	_test_builder()
	await _test_flow()
	await _test_clean_has_no_glade()


func _test_builder() -> void:
	var data: GladeData = load(GLADE) as GladeData
	var builder: SectionBuilder = SectionBuilder.new()
	var good: int = 0
	var same: bool = true
	for i in SEEDS:
		var layout: SectionLayout = builder.build_glade(data, _rng(i))
		var again: SectionLayout = builder.build_glade(data, _rng(i))
		if again.grid.to_text() != layout.grid.to_text() or again.decor != layout.decor or again.grid.sunlit != layout.grid.sunlit:
			same = false
		var reached: Dictionary = layout.grid.reachable_floor(layout.entrance)
		var merchant: Dictionary = {}
		for item: Dictionary in layout.items:
			if item["id"] == SectionLayout.ITEM_MERCHANT:
				merchant = item
		var props_ok: bool = layout.decor.size() == data.prop_count
		for entry: Dictionary in layout.decor:
			if not layout.grid.is_floor(entry["cell"]):
				props_ok = false
		if (reached.has(layout.exit) and not merchant.is_empty() and reached.has(merchant["cell"]) and layout.enemies.is_empty()
				and not layout.grid.sunlit.is_empty() and props_ok and layout.grid.theme_regions.size() == 1
				and layout.grid.theme_regions[0]["theme"] == data.theme):
			good += 1
	check(good == SEEDS, "the glade is one open clearing from entrance to gate, with the merchant, a sunlit patch and props, no enemies (%d of %d)" % [good, SEEDS])
	check(same, "the same seed gives the same glade")


func _test_flow() -> void:
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	Telemetry.glade_logged.connect(_on_glade_logged)
	GameManager.config = GameManager.load_config("full")
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	game.player.health.max_hp = 100000
	game.player.health.reset()
	for _gate in MAX_GATES:
		if game.is_in_glade():
			break
		await game._on_gate_entered(game.player)
	var merchants: Array[Node] = game.level.find_children("*", "Merchant", true, false)
	check(game.is_in_glade() and GameManager.depth == 1 and game.get_enemies().is_empty() and merchants.size() == 1
			and game.gate.is_open, "after the first arena comes the glade of the next depth: the merchant, an open gate, no enemies")
	var section_before: int = GameManager.section_index
	var bought: Array[String] = []
	if merchants.size() == 1:
		var merchant: Merchant = merchants[0] as Merchant
		GameManager.add_coins(500)
		merchant.interact(game.player)
		for button: Button in game.shop_screen.get_offer_buttons():
			if not button.disabled:
				button.pressed.emit()
				break
		for offer: ShopOffer in merchant.offers:
			if offer.sold:
				bought.append(offer.get_id())
		game.shop_screen.close()
	await game._on_gate_entered(game.player)
	var line: Dictionary = _glade_lines.back() if not _glade_lines.is_empty() else {}
	check(not game.is_in_glade() and GameManager.section_index == section_before and game.layout.arena_room < 0
			and not game.get_enemies().is_empty(), "the glade's gate leads on to the first section of the depth")
	check(line.get("type") == "glade" and line.get("depth") == 1 and line.get("purchases") == bought and bought.size() == 1
			and int(line.get("coins_spent", 0)) > 0, "the glade gets its own log line with what was bought and the coins spent")
	var state: PlayerState = game._make_player_state()
	check(state.glade_purchases == bought and state.glade_coins_spent == int(line.get("coins_spent", -1)) and state.coins == GameManager.coins,
			"the director sees the coins and what was bought at the last glade")
	check(is_zero_approx(game._chest_spell_chance({})) and is_equal_approx(game._chest_spell_chance({"secret": true}), game.secret_chest_spell_chance),
			"with the glade only a secret room's chest may hold a spell scroll")
	game.queue_free()
	Telemetry.glade_logged.disconnect(_on_glade_logged)
	Telemetry.write_enabled = write_was
	GameManager.config = GameManager.DEFAULT_CONFIG
	await physics_frames(3)


func _test_clean_has_no_glade() -> void:
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config("clean")
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	var glades: int = 0
	for _gate in MAX_GATES:
		await game._on_gate_entered(game.player)
		if game.is_in_glade():
			glades += 1
	check(glades == 0 and GameManager.depth >= 1 and is_equal_approx(game._chest_spell_chance({}), game.chest_spell_chance),
			"the clean series has no glade between depths")
	game.queue_free()
	Telemetry.write_enabled = write_was
	GameManager.config = GameManager.DEFAULT_CONFIG
	await physics_frames(3)


func _on_glade_logged(record: Dictionary) -> void:
	_glade_lines.append(record)


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
