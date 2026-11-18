extends TestCase
## Headless test for the ghost (stage 31): bought only with the extra enemies on and
## from its depth; drifts straight through a wall towards the player, half see-through,
## never winds up inside a wall; strikes from open ground, fully visible; floats over pits.

const GHOST: String = "res://actors/enemies/ghost.tres"
const SEEDS: int = 300
## A wall column (x = 6) between the ghost (left) and the player (right), a pit at 3,1.
const MAP: String = """############
#..~..#....#
#.....#....#
#.....#....#
#.....#....#
############"""


func run() -> void:
	_test_buying()
	await _test_through_wall()


func _test_buying() -> void:
	var data: GhostData = load(GHOST) as GhostData
	var settings: DirectorSettings = (load("res://director/director_settings.tres") as DirectorSettings).duplicate() as DirectorSettings
	settings.extra_enemies = true
	var on: RuleDirector = RuleDirector.new(null, settings)
	var off: RuleDirector = RuleDirector.new()
	var shallow: int = 0
	var deep: int = 0
	var none: int = 0
	for i in SEEDS:
		shallow += int(on.buy_enemies(30, _rng(i), {}, 1).get(&"ghost", 0))
		deep += int(on.buy_enemies(30, _rng(i), {}, 3).get(&"ghost", 0))
		none += int(off.buy_enemies(30, _rng(i), {}, 3).get(&"ghost", 0))
	check(data != null and data.is_extra and shallow == 0 and none == 0 and deep > 0,
			"ghosts are bought only with the extra enemies on and from the third depth (%d deep)" % deep)


func _test_through_wall() -> void:
	var level: Level = Level.new()
	level.debug_map = MAP
	add_child(level)
	await physics_frames(1)
	var data: GhostData = load(GHOST) as GhostData
	var ghost: Ghost = data.scene.instantiate() as Ghost
	ghost.data = data
	level.add_child(ghost)
	ghost.global_position = level.cell_center(Vector2i(3, 2))
	var target: Node2D = TestFactory.player_target(1000)
	level.add_child(target)
	target.global_position = level.cell_center(Vector2i(9, 2))
	await physics_frames(3)
	check(is_equal_approx(ghost.modulate.a, data.drift_alpha), "a drifting ghost is half see-through")
	var wound_up_in_wall: bool = false
	var was_in_wall: bool = false
	var reached: bool = false
	for _i in 60 * 12:
		await physics_frames(1)
		if ghost.is_in_wall():
			was_in_wall = true
			if ghost.state == Enemy.State.WINDUP:
				wound_up_in_wall = true
		if ghost.state == Enemy.State.WINDUP:
			reached = true
			break
	check(was_in_wall and ghost.global_position.x > level.cell_center(Vector2i(6, 2)).x,
			"the ghost drifts straight through the wall")
	check(not wound_up_in_wall and reached and not ghost.is_in_wall(), "it winds up only from open ground")
	await physics_frames(roundi(data.windup * 60.0) + 2)
	var health: Health = target.get_node("Health") as Health
	check(health.hp < health.max_hp and ghost.modulate.a > 0.95, "it strikes fully visible (%d damage)" % (health.max_hp - health.hp))
	ghost.global_position = level.cell_center(Vector2i(3, 1))
	await physics_frames(5)
	check(ghost.state != Enemy.State.FALLING and is_instance_valid(ghost), "a ghost floats over a pit")
	level.queue_free()
	await physics_frames(2)


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
