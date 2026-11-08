extends Node
## Global run state, registered as the autoload "GameManager".
## Owns the run seed and every random number generator, so a run can be replayed:
## the same seed and the same director decisions produce the same tunnel.

## Launch argument that fixes the seed, e.g. `--seed=12345`.
const SEED_ARG_PREFIX: String = "--seed="
## Pass this to start_run() to pick a random seed.
const RANDOM_SEED: int = -1
## Random seeds are picked below this value, so they stay short to type and log.
const MAX_RANDOM_SEED: int = 1_000_000_000

## Seed of the current run. Always written to the log.
var run_seed: int = 0
## Randomness during play (damage spread, drops).
## Section generation must use make_section_rng() instead.
var rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	start_run(_seed_from_command_line())


## Starts a new run. With RANDOM_SEED a random seed is chosen.
func start_run(new_seed: int = RANDOM_SEED) -> void:
	if new_seed == RANDOM_SEED:
		var seeder: RandomNumberGenerator = RandomNumberGenerator.new()
		seeder.randomize()
		new_seed = seeder.randi_range(0, MAX_RANDOM_SEED - 1)
	run_seed = new_seed
	rng.seed = run_seed
	print("Run seed: %d" % run_seed)


## Returns a new generator for building one section. It depends only on the run seed
## and the section index, so randomness used in combat never changes a section.
func make_section_rng(section_index: int) -> RandomNumberGenerator:
	var section_rng: RandomNumberGenerator = RandomNumberGenerator.new()
	section_rng.seed = hash([run_seed, section_index])
	return section_rng


## Reads --seed=N from the launch arguments, or returns RANDOM_SEED if it is absent.
func _seed_from_command_line() -> int:
	for arg: String in OS.get_cmdline_user_args() + OS.get_cmdline_args():
		if not arg.begins_with(SEED_ARG_PREFIX):
			continue
		var value: String = arg.trim_prefix(SEED_ARG_PREFIX)
		if value.is_valid_int():
			return value.to_int()
		push_warning("Ignoring invalid seed argument: %s" % arg)
	return RANDOM_SEED
