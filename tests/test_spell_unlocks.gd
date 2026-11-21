extends TestCase
## Headless test for spell unlocks and the third slot (stage 36): with the progress
## between runs only spells open from the start or unlocked in the camp turn up in a
## run; the shelf unlocks a spell for shards; the clean series keeps the whole pool;
## the camp's skill gives a third spell slot with its own icon, button and key.

const GAME_SCENE: String = "res://main/main.tscn"
const POOL: String = "res://combat/spells/spell_pool.tres"
const RUN_SEED: int = 36

var _pool: SpellPool = null


func run() -> void:
	_pool = load(POOL) as SpellPool
	Progress.from_dictionary({})
	_test_pool()
	await _test_runs()
	await _test_shelf()
	await _test_third_slot()
	Progress.from_dictionary({})


func _test_pool() -> void:
	var open: Array[StringName] = _ids(_pool.unlocked())
	check(open == ([&"fireball"] as Array[StringName]), "at first only the fireball is open (%s)" % [open])
	Progress.unlock_spell(&"whirlwind")
	check(_ids(_pool.unlocked()).has(&"whirlwind") and not _ids(_pool.unlocked()).has(&"water"), "an unlocked spell joins the run's pool")
	Progress.from_dictionary({})


func _test_runs() -> void:
	var game: Game = await _start("full")
	check(_ids(game._run_spells) == ([&"fireball"] as Array[StringName]), "a full-game run offers only unlocked spells")
	await _stop(game)
	game = await _start("clean")
	check(game._run_spells.spells.size() == _pool.spells.size(), "the clean series keeps the whole pool")
	await _stop(game)


func _test_shelf() -> void:
	Progress.from_dictionary({"shards": 10})
	var shelf: SpellShelfScreen = SpellShelfScreen.new()
	add_child(shelf)
	shelf.open(_pool)
	var whirlwind: SpellData = _pool.spells.filter(func(s: SpellData) -> bool: return s.id == &"whirlwind")[0]
	check(shelf.get_spell_button(&"fireball").disabled and not shelf.get_spell_button(&"whirlwind").disabled,
			"the shelf: the fireball is known, the whirlwind can be unlocked")
	shelf.get_spell_button(&"whirlwind").pressed.emit()
	check(Progress.is_spell_unlocked(&"whirlwind") and Progress.shards == 10 - whirlwind.unlock_cost
			and shelf.get_spell_button(&"whirlwind").disabled, "unlocking takes the shards and stays")
	shelf.close()
	shelf.queue_free()
	await physics_frames(2)
	Progress.from_dictionary({})


func _test_third_slot() -> void:
	check(InputMap.has_action(&"spell_3"), "the third slot has its key")
	Progress.from_dictionary({"perks": {"spell_slot": 1}})
	var game: Game = await _start("full")
	var book: SpellBook = game.player.spell_book
	for spell_data: SpellData in _pool.spells:
		book.learn(spell_data)
	await physics_frames(1)
	check(book.slot_count == 3 and book.get_spell(2) != null and not book.has_free_slot(), "the camp's skill gives a third spell slot")
	check(game.hud.spell_icons.size() == 3 and game.hud.spell_icons[2].visible and game.hud.spell_buttons[2].action == &"spell_3",
			"the HUD shows the third slot with its own touch button")
	await _stop(game)
	Progress.from_dictionary({})


func _ids(pool: SpellPool) -> Array[StringName]:
	var ids: Array[StringName] = []
	for spell_data: SpellData in pool.spells:
		ids.append(spell_data.id)
	return ids


func _start(series: String) -> Game:
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config(series)
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	return game


func _stop(game: Game) -> void:
	game.queue_free()
	Telemetry.write_enabled = true
	GameManager.config = GameManager.DEFAULT_CONFIG
	await physics_frames(3)
