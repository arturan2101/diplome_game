extends TestCase
## Headless test for GameManager seeding.

const GameManagerScript: GDScript = preload("res://autoload/game_manager.gd")
const SAMPLE_COUNT: int = 5
const TEST_SEED: int = 12345
const OTHER_SEED: int = 54321


func run() -> void:
	var a: Node = GameManagerScript.new()
	var b: Node = GameManagerScript.new()

	a.start_run(TEST_SEED)
	b.start_run(TEST_SEED)
	check(_sample(a.rng) == _sample(b.rng), "same seed gives same gameplay numbers")
	check(_sample(a.make_section_rng(3)) == _sample(b.make_section_rng(3)),
			"same seed and section give same section numbers")
	check(_sample(a.make_section_rng(0)) != _sample(a.make_section_rng(1)),
			"different sections give different numbers")

	var before: Array[int] = _sample(a.make_section_rng(2))
	_sample(a.rng)  # Simulate combat consuming gameplay randomness.
	check(_sample(a.make_section_rng(2)) == before, "gameplay rng does not change sections")

	b.start_run(OTHER_SEED)
	check(_sample(a.make_section_rng(0)) != _sample(b.make_section_rng(0)),
			"different seeds give different sections")

	a.start_run(GameManagerScript.RANDOM_SEED)
	check(a.run_seed >= 0 and a.run_seed < GameManagerScript.MAX_RANDOM_SEED,
			"random seed is in range")

	a.free()
	b.free()


func _sample(generator: RandomNumberGenerator) -> Array[int]:
	var values: Array[int] = []
	for _i in SAMPLE_COUNT:
		values.append(generator.randi())
	return values
