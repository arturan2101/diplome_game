extends TestCase
## Headless regression test for the determinism fix of stage 42: the section builder
## orders the enemy types of a plan by the text of their names. Before, it used sort()
## on StringNames, which orders them by where they sit in memory, so the same seed could
## place enemies differently depending on what the game had loaded before.

const SEEDS: int = 12


func run() -> void:
	var builder: SectionBuilder = SectionBuilder.new()
	var same: bool = true
	for i in SEEDS:
		var first: SectionPlan = _plan(i, [&"skeleton", &"archer", &"beetle"])
		# New names in between shift where StringNames sit in memory.
		var _noise: Array[StringName] = [StringName("zz_noise_%d" % i), StringName("aa_noise_%d" % i)]
		var second: SectionPlan = _plan(i, [&"beetle", &"skeleton", &"archer"])
		var a: SectionLayout = builder.build(first, _rng(i))
		var b: SectionLayout = builder.build(second, _rng(i))
		if JSON.stringify(a.enemies) != JSON.stringify(b.enemies) or JSON.stringify(a.items) != JSON.stringify(b.items):
			same = false
	check(same, "the same plan places the same enemies, whatever the order of its mix and the names loaded")
	var order: Array = [&"skeleton", &"archer", &"beetle"]
	order.sort_custom(func(a: StringName, b: StringName) -> bool: return String(a) < String(b))
	check(order == [&"archer", &"beetle", &"skeleton"], "enemy types are taken in alphabetical order")


func _plan(index: int, order: Array[StringName]) -> SectionPlan:
	var plan: SectionPlan = SectionPlan.new()
	plan.section_index = index
	plan.depth = index % 3
	plan.enemy_mix = {}
	var counts: Dictionary = {&"skeleton": 2, &"archer": 1, &"beetle": 1}
	for id: StringName in order:
		plan.enemy_mix[id] = counts[id]
	return plan


func _rng(index: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 7700 + index
	return rng
