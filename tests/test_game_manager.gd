extends SceneTree
## Headless test for GameManager seeding. Exit code = number of failed checks.
## Run: godot --headless --path . --script res://tests/test_game_manager.gd

const GameManagerScript: GDScript = preload("res://autoload/game_manager.gd")
const SAMPLE_COUNT: int = 5
const TEST_SEED: int = 12345
const OTHER_SEED: int = 54321
## Temporary level used by the restart check.
const LEVEL_PATH: String = "user://test_restart_level.tscn"
## Extra seconds to wait after the restart delay.
const RESTART_MARGIN: float = 0.3

var _failures: int = 0


func _initialize() -> void:
	var a: Node = GameManagerScript.new()
	var b: Node = GameManagerScript.new()

	a.start_run(TEST_SEED)
	b.start_run(TEST_SEED)
	_check(_sample(a.rng) == _sample(b.rng), "same seed gives same gameplay numbers")
	_check(_sample(a.make_section_rng(3)) == _sample(b.make_section_rng(3)),
			"same seed and section give same section numbers")
	_check(_sample(a.make_section_rng(0)) != _sample(a.make_section_rng(1)),
			"different sections give different numbers")

	var before: Array[int] = _sample(a.make_section_rng(2))
	_sample(a.rng)  # Simulate combat consuming gameplay randomness.
	_check(_sample(a.make_section_rng(2)) == before, "gameplay rng does not change sections")

	b.start_run(OTHER_SEED)
	_check(_sample(a.make_section_rng(0)) != _sample(b.make_section_rng(0)),
			"different seeds give different sections")

	a.start_run(GameManagerScript.RANDOM_SEED)
	_check(a.run_seed >= 0 and a.run_seed < GameManagerScript.MAX_RANDOM_SEED,
			"random seed is in range")

	a.free()
	b.free()

	await _test_restart_after_death()

	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(_failures)


## The player's death goes through the real GameManager autoload: after the delay
## the level is reloaded and a new run with a new seed starts.
func _test_restart_after_death() -> void:
	var manager: Node = root.get_node("GameManager")
	# reload_current_scene() needs a scene loaded from a file.
	var level: PackedScene = PackedScene.new()
	var level_root: Node2D = Node2D.new()
	level.pack(level_root)
	level_root.free()
	ResourceSaver.save(level, LEVEL_PATH)
	change_scene_to_file(LEVEL_PATH)
	await process_frame
	await process_frame
	var first_scene: Node = current_scene
	var first_seed: int = manager.run_seed

	manager.report_player_death(DamageInfo.new(10, null, &"skeleton"))
	manager.report_player_death(DamageInfo.new(10, null, &"skeleton"))
	_check(current_scene == first_scene, "level is not reloaded before the delay")
	await create_timer(GameManagerScript.DEATH_RESTART_DELAY + RESTART_MARGIN).timeout
	await process_frame
	_check(current_scene != null and current_scene != first_scene, "death reloads the level through GameManager")
	_check(manager.run_seed != first_seed, "restart starts a run with a new seed")
	DirAccess.remove_absolute(LEVEL_PATH)


func _sample(generator: RandomNumberGenerator) -> Array[int]:
	var values: Array[int] = []
	for _i in SAMPLE_COUNT:
		values.append(generator.randi())
	return values


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		print("FAIL: ", description)
		_failures += 1
