extends SceneTree
## Headless test for GameManager seeding. Exit code = number of failed checks.
## Run: godot --headless --path . --script res://tests/test_game_manager.gd

const GameManagerScript: GDScript = preload("res://autoload/game_manager.gd")
const SAMPLE_COUNT: int = 5
const TEST_SEED: int = 12345
const OTHER_SEED: int = 54321

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
	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(_failures)


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
