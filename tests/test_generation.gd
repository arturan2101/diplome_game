extends TestCase
## Headless test for section generation: 100 sections with different seeds and plans
## are passable and contain what the plan asked for; the same seed gives the same
## section; a generated section works as a Level.

const SEED_COUNT: int = 100
const RUN_SEED: int = 777
## Sections must stay small enough for a phone.
const MAX_WIDTH: int = 220
const MAX_HEIGHT: int = 90


func run() -> void:
	_test_many_seeds()
	_test_determinism()
	await _test_level_from_layout()


func _test_many_seeds() -> void:
	var builder: SectionBuilder = SectionBuilder.new()
	var catalog: EnemyCatalog = load(SectionBuilder.CATALOG_PATH) as EnemyCatalog
	var impassable: int = 0
	var wrong_content: int = 0
	var enemies_at_start: int = 0
	var too_big: int = 0
	var retries: int = 0
	var missing_branch: int = 0
	var max_size: Vector2i = Vector2i.ZERO
	for i in SEED_COUNT:
		var plan: SectionPlan = _varied_plan(i)
		var layout: SectionLayout = builder.build(plan, _section_rng(RUN_SEED, i))
		if not SectionBuilder.is_passable(layout):
			impassable += 1
		if layout.attempts > 1:
			retries += 1
		if not _content_matches(layout, plan, catalog):
			wrong_content += 1
		for entry: Dictionary in layout.enemies:
			if layout.room_rects[0].has_point(entry["cell"]):
				enemies_at_start += 1
		if layout.grid.width > MAX_WIDTH or layout.grid.height > MAX_HEIGHT:
			too_big += 1
		if plan.has_side_branch and layout.room_rects.size() != plan.room_count + 1:
			missing_branch += 1
		max_size = Vector2i(maxi(max_size.x, layout.grid.width), maxi(max_size.y, layout.grid.height))
	check(impassable == 0, "all %d sections are passable from the entrance to the gate (%d are not)" % [SEED_COUNT, impassable])
	check(wrong_content == 0, "every section has the enemies, health packs, coins and chest of its plan (%d do not)" % wrong_content)
	check(enemies_at_start == 0, "no enemy stands in the first room (%d do)" % enemies_at_start)
	check(too_big == 0, "sections stay within %dx%d tiles (largest: %s)" % [MAX_WIDTH, MAX_HEIGHT, max_size])
	check(missing_branch == 0, "a planned side branch is always built (%d missing)" % missing_branch)
	check(retries <= SEED_COUNT / 10, "rebuilds are rare (%d of %d)" % [retries, SEED_COUNT])
	print("  generation: largest section %s tiles, %d of %d needed a rebuild" % [max_size, retries, SEED_COUNT])


func _test_determinism() -> void:
	var builder: SectionBuilder = SectionBuilder.new()
	var plan: SectionPlan = _varied_plan(7)
	var first: SectionLayout = builder.build(plan, _section_rng(RUN_SEED, 3))
	var second: SectionLayout = builder.build(plan, _section_rng(RUN_SEED, 3))
	check(first.to_text() == second.to_text(), "the same seed, section index and plan give the same section")
	var other_section: SectionLayout = builder.build(plan, _section_rng(RUN_SEED, 4))
	var other_seed: SectionLayout = builder.build(plan, _section_rng(RUN_SEED + 1, 3))
	check(first.to_text() != other_section.to_text() and first.to_text() != other_seed.to_text(),
			"another section index or another seed gives another section")
	var other_builder: SectionLayout = SectionBuilder.new().build(plan, _section_rng(RUN_SEED, 3))
	check(first.to_text() == other_builder.to_text(), "a fresh builder gives the same section too")


func _test_level_from_layout() -> void:
	var plan: SectionPlan = _varied_plan(5)
	var layout: SectionLayout = SectionBuilder.new().build(plan, _section_rng(RUN_SEED, 5))
	var level: Level = Level.new()
	add_child(level)
	level.build(layout.grid)
	await physics_frames(2)
	var path: PackedVector2Array = level.find_path(level.cell_center(layout.entrance), level.cell_center(layout.exit))
	check(not path.is_empty() and path[path.size() - 1].is_equal_approx(level.cell_center(layout.exit)),
			"the Level built from a section has a walkable path from the entrance to the gate")
	check(layout.reference_time > 0.0 and layout.room_names.size() == layout.room_rects.size(),
			"the layout reports its reference time and room names")
	level.queue_free()
	await physics_frames(2)


## Same derivation as GameManager.make_section_rng().
func _section_rng(run_seed: int, section_index: int) -> RandomNumberGenerator:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([run_seed, section_index])
	return rng


## Plans that cover the range the directors can ask for.
func _varied_plan(i: int) -> SectionPlan:
	var plan: SectionPlan = SectionPlan.new()
	plan.section_index = i
	plan.room_count = 3 + i % 3
	plan.has_side_branch = i % 2 == 0
	plan.has_chest = i % 3 == 0
	plan.corridor_width = 2 + i % 3
	plan.corridor_twist = 0.1 * float(i % 7)
	plan.health_packs = i % 3
	plan.coins = 3 + i % 8
	plan.cover_density = 0.25 * float(i % 5)
	plan.enemy_mix = {&"skeleton": 1 + i % 4, &"archer": i % 3, &"beetle": i % 2}
	if i % 4 == 0:
		plan.preferred_tags = [&"cover"]
	return plan


func _content_matches(layout: SectionLayout, plan: SectionPlan, catalog: EnemyCatalog) -> bool:
	var counts: Dictionary = layout.count_enemies()
	for id: StringName in plan.enemy_mix:
		var data: EnemyData = catalog.get_by_id(id)
		var spawns: int = int(plan.enemy_mix[id])
		var placed: int = int(counts.get(id, 0))
		if placed < spawns * data.pack_min or placed > spawns * data.pack_max:
			return false
	if layout.count_items(SectionLayout.ITEM_HEALTH_PACK) != plan.health_packs:
		return false
	if layout.count_items(SectionLayout.ITEM_COIN) != plan.coins:
		return false
	return layout.count_items(SectionLayout.ITEM_CHEST) == (1 if plan.has_chest else 0)
