extends TestCase
## Headless test for the stone golem (stage 29): bought by the director only with the
## extra enemies on and from its depth; slow, not pushed back; the slam after the windup
## hurts what stands in its circle (with the golem's id as the source) and nothing
## outside it; the bot is told to leave the whole circle; the blizzard freezes it.

const GOLEM: String = "res://actors/enemies/golem.tres"
const SEEDS: int = 300
const START: Vector2 = Vector2(300.0, 300.0)
const NEAR: float = 24.0

var _hits: Array[DamageInfo] = []


func run() -> void:
	_test_buying()
	await _test_slam_hits_inside()
	await _test_slam_misses_outside()
	await _test_heavy_and_frozen()


func _test_buying() -> void:
	var data: GolemData = load(GOLEM) as GolemData
	var catalog: EnemyCatalog = load(Director.CATALOG_PATH) as EnemyCatalog
	check(data != null and catalog.get_by_id(&"golem") == data and data.is_extra and data.min_depth == 1,
			"the golem is in the catalog as an extra enemy from the second depth")
	var off: RuleDirector = RuleDirector.new()
	var settings: DirectorSettings = off.settings.duplicate() as DirectorSettings
	settings.extra_enemies = true
	var on: RuleDirector = RuleDirector.new(null, settings)
	var bought_off: int = 0
	var bought_shallow: int = 0
	var bought_deep: int = 0
	for i in SEEDS:
		bought_off += int(off.buy_enemies(30, _rng(i), {}, 3).get(&"golem", 0))
		bought_shallow += int(on.buy_enemies(30, _rng(i), {}, 0).get(&"golem", 0))
		bought_deep += int(on.buy_enemies(30, _rng(i), {}, 3).get(&"golem", 0))
	check(bought_off == 0 and bought_shallow == 0 and bought_deep > 0,
			"golems are bought only with the extra enemies on and from their depth (%d deep)" % bought_deep)
	var same: bool = true
	for i in SEEDS:
		var with_golem_in_catalog: Dictionary = off.buy_enemies(20, _rng(i), {}, 2)
		var plain: RuleDirector = RuleDirector.new()
		plain.catalog = catalog.duplicate() as EnemyCatalog
		plain.catalog.enemies = plain.catalog.enemies.filter(func(e: EnemyData) -> bool: return not e.is_extra)
		if plain.buy_enemies(20, _rng(i), {}, 2) != with_golem_in_catalog:
			same = false
	check(same, "with the extra enemies off a golem in the catalog changes nothing")


func _test_slam_hits_inside() -> void:
	var golem: Golem = _add_golem()
	var target: Node2D = _add_target(START + Vector2(NEAR, 0.0))
	await physics_frames(3)
	var x: float = golem.global_position.x
	check(golem.state == Enemy.State.WINDUP, "a player close by makes the golem wind up its slam")
	golem.apply_knockback(Vector2(-300.0, 0.0))
	await physics_frames(2)
	check(golem.state == Enemy.State.WINDUP and is_equal_approx(golem.global_position.x, x),
			"hits do not push the golem or break its windup")
	check(is_equal_approx(golem.get_windup_reach(), golem.data.slam_radius), "the bot is told to leave the whole circle")
	await physics_frames(roundi(golem.data.windup * 60.0) + 2)
	var health: Health = target.get_node("Health") as Health
	var expected: int = roundi(golem.data.slam_damage * golem.damage_multiplier)
	check(health.hp == health.max_hp - expected and _hits.size() == 1 and _hits[0].source_id == &"golem"
			and _hits[0].knockback.x > 0.0, "the slam hurts the player in its circle and pushes them away (%d)" % (health.max_hp - health.hp))
	check(golem.state == Enemy.State.RECOVER, "after the slam the golem recovers")
	await _clear([golem, target])


func _test_slam_misses_outside() -> void:
	var golem: Golem = _add_golem()
	var target: Node2D = _add_target(START + Vector2(NEAR, 0.0))
	await physics_frames(3)
	target.global_position = START + Vector2(golem.data.slam_radius + 20.0, 0.0)
	await physics_frames(roundi(golem.data.windup * 60.0) + 2)
	var health: Health = target.get_node("Health") as Health
	check(health.hp == health.max_hp, "a player who steps out of the circle in time takes nothing")
	await _clear([golem, target])


func _test_heavy_and_frozen() -> void:
	var golem: Golem = _add_golem()
	await physics_frames(2)
	check(golem.health.max_hp == (load(GOLEM) as GolemData).max_hp and golem.data.move_speed < 30.0,
			"the golem is tough (%d HP) and slow" % golem.health.max_hp)
	golem.freeze(0.5)
	check(golem.is_frozen(), "the blizzard freezes a golem too")
	await _clear([golem])


func _add_golem() -> Golem:
	var data: GolemData = load(GOLEM) as GolemData
	var golem: Golem = data.scene.instantiate() as Golem
	golem.data = data
	add_child(golem)
	golem.global_position = START
	return golem


func _add_target(at: Vector2) -> Node2D:
	_hits.clear()
	var target: Node2D = TestFactory.player_target(1000)
	add_child(target)
	target.global_position = at
	(target.get_node("Hurtbox") as Hurtbox).hit_received.connect(func(info: DamageInfo) -> void: _hits.append(info))
	return target


func _clear(nodes: Array) -> void:
	for node: Node in nodes:
		node.queue_free()
	await physics_frames(2)


func _rng(rng_seed: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = rng_seed
	return rng
