extends TestCase
## Headless test for the run loop in the real game scene: a section is built from the
## seed, the gate opens only when all enemies are dead, the gate leads to the next
## section, depth grows every 3-4 sections, and the bot can clear a section.

const GAME_SCENE: String = "res://main/main.tscn"
const RUN_SEED: int = 4242
const HUGE_HP: int = 1_000_000
## The bot gets this much game time to clear one section, in physics frames.
const BOT_FRAME_LIMIT: int = 60 * 240
## How many times faster than real time the bot run is simulated.
const BOT_SPEED: int = 8

var _finished_sections: int = 0


func run() -> void:
	await _test_gate_and_next_section()
	_test_depth_rule()
	await _test_same_seed_same_section()
	await _test_bot_clears_section()


func _test_gate_and_next_section() -> void:
	var game: Game = _start_game(RUN_SEED)
	game.section_finished.connect(func(_plan: SectionPlan, _layout: SectionLayout) -> void: _finished_sections += 1)
	await physics_frames(3)
	var first_layout: SectionLayout = game.layout
	check(first_layout != null and SectionBuilder.is_passable(first_layout), "the game builds a passable first section")
	check(game.player.global_position.distance_to(game.level.cell_center(first_layout.entrance)) < 2.0,
			"the player starts at the entrance")
	check(game.get_enemies().size() == first_layout.enemies.size() and not first_layout.enemies.is_empty(),
			"every enemy of the layout is spawned")
	check(game.get_pickups().size() == first_layout.items.size(), "every item of the layout is spawned")
	check(game.player.weapon != null and game.player.weapon.data == GameManager.starting_weapon
			and game.player.skill != null, "the player gets the loadout from GameManager")

	game.player.teleport(game.gate.global_position)
	await physics_frames(10)
	check(not game.gate.is_open and GameManager.section_index == 0, "the gate stays closed while enemies live")

	var enemy_count: int = game.get_enemies().size()
	for enemy: Enemy in game.get_enemies():
		enemy.hurtbox.receive_hit(DamageInfo.new(HUGE_HP, null, &"test"))
	await physics_frames(2)
	check(game.gate.is_open and GameManager.kills == enemy_count, "killing the last enemy opens the gate; kills are counted")
	await physics_frames(60)
	check(GameManager.section_index == 1 and _finished_sections == 1, "the open gate takes the player to the next section")
	check(game.layout != first_layout and game.layout.to_text() != first_layout.to_text()
			and game.player.global_position.distance_to(game.level.cell_center(game.layout.entrance)) < 2.0,
			"the next section is a new one and the player stands at its entrance")
	check(game.player.is_physics_processing(), "the player can move again after the section change")
	await _stop_game(game)


func _test_depth_rule() -> void:
	var manager: Node = (load("res://autoload/game_manager.gd") as GDScript).new()
	manager.start_run(RUN_SEED)
	var follows_rule: bool = true
	var sections_in_this_depth: int = 0
	for _i in 40:
		var depth_before: int = manager.depth
		var expected_length: int = manager.sections_in_depth(depth_before)
		if expected_length < 3 or expected_length > 4:
			follows_rule = false
		manager.advance_section()
		sections_in_this_depth += 1
		if manager.depth != depth_before:
			if sections_in_this_depth != expected_length or manager.depth != depth_before + 1:
				follows_rule = false
			sections_in_this_depth = 0
	check(follows_rule and manager.depth >= 10 and manager.section_index == 40, "depth grows by one every 3-4 sections")
	manager.free()


func _test_same_seed_same_section() -> void:
	var first: Game = _start_game(RUN_SEED)
	await physics_frames(2)
	var first_text: String = first.layout.to_text()
	await _stop_game(first)
	var second: Game = _start_game(RUN_SEED)
	await physics_frames(2)
	check(second.layout.to_text() == first_text, "the same run seed gives the same first section in the game")
	await _stop_game(second)


func _test_bot_clears_section() -> void:
	var game: Game = _start_game(RUN_SEED)
	game.player.health.max_hp = HUGE_HP
	game.player.health.reset()
	game.add_bot()
	SimulationSpeed.set_factor(BOT_SPEED)
	var frames: int = 0
	var worst_delta: float = 0.0
	while frames < BOT_FRAME_LIMIT and GameManager.section_index < 1:
		await get_tree().physics_frame
		worst_delta = maxf(worst_delta, get_physics_process_delta_time())
		frames += 1
	SimulationSpeed.reset()
	# The engine picks the new speed up on the next rendered frame.
	await get_tree().process_frame
	await get_tree().process_frame
	check(worst_delta < 1.5 / 60.0, "fast-forward keeps the physics step at 1/60 s (largest %.4f)" % worst_delta)
	check(GameManager.section_index >= 1, "the bot clears a section and goes through the gate (%.0f s of game time)" % (frames / 60.0))
	await _stop_game(game)


func _start_game(run_seed: int) -> Game:
	GameManager.start_run(run_seed)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.restart_on_death = false
	add_child(game)
	return game


func _stop_game(game: Game) -> void:
	game.queue_free()
	await physics_frames(3)
