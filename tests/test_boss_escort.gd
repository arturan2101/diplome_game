extends TestCase
## Headless test (after stage 49): in a boss arena with ExperimentConfig.boss_escort_on_seal
## only the sleeping boss waits; its escort comes in with spawn warnings as the doors
## seal, away from the player, and the way down opens only after them. Without the
## flag (the clean series) the escort stands in the arena from the start.

const GAME_SCENE: String = "res://main/main.tscn"
const RUN_SEED: int = 4950
## Runs tried until the boss arena of ESCORT_DEPTH has an escort.
const ATTEMPTS: int = 10
const ESCORT_DEPTH: int = 3
const BIG_HP: int = 100000
const ESCORT_BUDGET: float = 26.0


func run() -> void:
	var saved: ExperimentConfig = GameManager.config
	var game: Game = await _escorted_arena()
	check(game != null, "a boss arena with an escort is found")
	if game != null:
		await _test_escort(game)
	GameManager.config = load("res://experiment/clean.tres") as ExperimentConfig
	game = await _escorted_arena()
	if game != null:
		check(game.get_enemies().size() == game.layout.enemies.size(), "without the flag the escort stands there from the start")
		game.queue_free()
		await physics_frames(2)
	GameManager.config = saved


## The full game at the boss arena of ESCORT_DEPTH, in the first run where it has an
## escort; null if none does.
func _escorted_arena() -> Game:
	for attempt in ATTEMPTS:
		GameManager.start_run(RUN_SEED + attempt)
		while not (GameManager.depth == ESCORT_DEPTH and GameManager.is_last_section_of_depth()):
			GameManager.advance_section()
		var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
		game.death_screen_enabled = false
		add_child(game)
		await physics_frames(2)
		# A skilled player's budget leaves room for an escort beside the boss.
		game._director.settings = game._director.settings.duplicate() as DirectorSettings
		game._director.settings.budget_base = ESCORT_BUDGET
		game._start_section()
		await physics_frames(2)
		if game.plan.is_boss and game.layout.enemies.size() > 1:
			return game
		game.queue_free()
		await physics_frames(2)
	return null


func _test_escort(game: Game) -> void:
	game.player.health.max_hp = BIG_HP
	game.player.health.reset()
	var escort: int = game.layout.enemies.size() - 1
	var arena: Rect2i = game.layout.room_rects[game.layout.arena_room]
	await physics_frames(5)
	check(game.get_enemies().size() == 1 and game.get_enemies()[0] is Guardian,
			"before the doors seal only the boss is there (its escort of %d is not)" % escort)
	game.player.teleport(game.level.cell_center(game.level.nearest_floor_cell(arena.get_center() + Vector2i(0, 3))))
	await physics_frames(3)
	var markers: int = 0
	for child: Node in game.level.get_children():
		for node: Node in child.get_children():
			if node is SpawnMarker:
				markers += 1
	check(game.is_arena_sealed() and markers == escort, "the doors seal and warnings show where the escort comes in")
	var tracker: CombatRoomTracker = game.get_combat_rooms()
	# The boss falls before the escort is in: the arena must still wait for it.
	for enemy: Enemy in game.get_enemies():
		enemy.health.take_damage(DamageInfo.new(BIG_HP, null, &"test"))
	await physics_frames(3)
	check(game.is_arena_sealed() and not game.gate.is_open, "with the boss down but the escort still coming the doors stay shut")
	await physics_frames(roundi(tracker.warning_time * Engine.physics_ticks_per_second) + 3)
	var inside: int = 0
	var far: bool = true
	for enemy: Enemy in game.get_enemies():
		if arena.has_point(game.level.cell_at(enemy.global_position)):
			inside += 1
		far = far and enemy.global_position.distance_to(game.player.global_position) >= tracker.min_player_distance - 1.0
	check(inside == escort, "after the warning the escort is in the arena (%d of %d)" % [inside, escort])
	check(far, "never right next to the player")
	for enemy: Enemy in game.get_enemies():
		enemy.health.take_damage(DamageInfo.new(BIG_HP, null, &"test"))
	await physics_frames(3)
	check(game.gate.is_open and not game.is_arena_sealed(), "with the escort gone the way down opens")
	game.queue_free()
	await physics_frames(3)
