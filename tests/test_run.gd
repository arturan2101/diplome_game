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
	await _test_arena()
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
	# A combat room's enemies wait for the player, a secret room's things for the crack to break.
	var waiting: int = 0
	for entry: Dictionary in first_layout.enemies:
		if game.get_combat_rooms().owns(entry):
			waiting += 1
	var hidden: int = 0
	for entry: Dictionary in first_layout.items:
		if entry.get("secret", false):
			hidden += 1
	check(game.get_enemies().size() == first_layout.enemies.size() - waiting and not first_layout.enemies.is_empty(),
			"every enemy of the layout is spawned (but those of a combat room)")
	check(game.get_pickups().size() + game.get_shrines().size() == first_layout.items.size() - hidden,
			"every item of the layout is spawned (pickups and shrines; not those of a secret room)")
	check(game.player.weapon != null and game.player.weapon.data == GameManager.starting_weapon
			and game.player.skill != null, "the player gets the loadout from GameManager")

	check(game.gate.is_open and not game.is_arena(), "in an ordinary section the gate is open from the start")
	var enemy_count: int = game.get_enemies().size()
	for enemy: Enemy in game.get_enemies():
		enemy.hurtbox.receive_hit(DamageInfo.new(HUGE_HP, null, &"test"))
	await physics_frames(2)
	check(GameManager.kills == enemy_count, "kills are counted")
	game.player.teleport(game.gate.global_position)
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


func _test_arena() -> void:
	GameManager.start_run(RUN_SEED)
	while not GameManager.is_last_section_of_depth():
		GameManager.advance_section()
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	game.player.health.max_hp = HUGE_HP
	game.player.health.reset()
	await physics_frames(3)
	check(game.plan.is_arena and game.is_arena() and not game.gate.is_open, "the last section of a depth is an arena with a closed gate")
	var room: Rect2i = game.layout.room_rects[game.layout.arena_room]
	game.player.teleport(game.level.cell_center(game.level.nearest_floor_cell(room.get_center())))
	await physics_frames(3)
	var sealed: bool = game.is_arena_sealed()
	var doors_are_walls: bool = true
	for cell: Vector2i in game.layout.arena_doors:
		if game.level.grid.get_cell(cell) != LevelGrid.Cell.WALL:
			doors_are_walls = false
	check(sealed and doors_are_walls, "walking into the arena seals its doors")
	var waves_seen: int = 0
	for _round in 4:
		var enemies: Array[Enemy] = game.get_enemies()
		if enemies.is_empty():
			break
		waves_seen += 1
		for enemy: Enemy in enemies:
			enemy.hurtbox.receive_hit(DamageInfo.new(HUGE_HP, null, &"test"))
		await physics_frames(3)
	check(waves_seen == game.layout.wave_count(), "the enemies come in %d wave(s), each after the previous one dies" % game.layout.wave_count())
	var doors_open: bool = true
	for cell: Vector2i in game.layout.arena_doors:
		if game.level.grid.get_cell(cell) != LevelGrid.Cell.FLOOR:
			doors_open = false
	check(game.gate.is_open and doors_open and not game.is_arena_sealed(), "after the last wave the doors and the gate open")
	var depth_before: int = GameManager.depth
	game.player.teleport(game.gate.global_position)
	await physics_frames(60)
	check(GameManager.depth == depth_before + 1, "the arena's gate leads to the next depth")
	await _stop_game(game)


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
	check(not Telemetry.history.is_empty() and Telemetry.history[0]["section"] == 0 and Telemetry.history[0]["died"] == false
			and float(Telemetry.history[0]["kills_ratio"]) == 1.0 and FileAccess.file_exists(Telemetry.get_log_path()),
			"the section played by the bot is logged")
	check(GameManager.section_index >= 1, "the bot clears a section and goes through the gate (%.0f s of game time)" % (frames / 60.0))
	await _stop_game(game)


func _start_game(run_seed: int) -> Game:
	GameManager.start_run(run_seed)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	return game


func _stop_game(game: Game) -> void:
	game.queue_free()
	await physics_frames(3)
