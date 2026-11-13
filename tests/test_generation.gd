extends TestCase
## Headless test for section generation: 100 sections with different seeds and plans
## are passable and contain what the plan asked for; the same seed gives the same
## section; a generated section works as a Level.

const SEED_COUNT: int = 100
const RUN_SEED: int = 777
## Ordinary sections must stay small enough to clear in 1-2 minutes (about 80x60 tiles
## plus the margin); arenas may be larger.
const MAX_WIDTH: int = 90
const MAX_HEIGHT: int = 66
const MAX_ARENA_WIDTH: int = 116
const MAX_ARENA_HEIGHT: int = 66


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
	var empty_rooms: int = 0
	var enemies_outside: int = 0
	var bad_arenas: int = 0
	var directions: Dictionary = {}
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
			if int(entry["room"]) == 0:
				enemies_at_start += 1
			if not layout.room_rects[int(entry["room"])].grow(-1).has_point(entry["cell"]):
				enemies_outside += 1
		var limit: Vector2i = Vector2i(MAX_ARENA_WIDTH, MAX_ARENA_HEIGHT) if plan.is_arena else Vector2i(MAX_WIDTH, MAX_HEIGHT)
		if layout.grid.width > limit.x or layout.grid.height > limit.y:
			too_big += 1
		if layout.room_rects.size() != plan.room_count + plan.side_branches:
			missing_branch += 1
		for room in range(1, layout.path_room_count):
			directions[_direction(layout.room_rects[room - 1], layout.room_rects[room])] = true
		if not plan.is_arena:
			empty_rooms += _count_empty_rooms(layout)
		elif not _arena_ok(layout, plan):
			bad_arenas += 1
		max_size = Vector2i(maxi(max_size.x, layout.grid.width), maxi(max_size.y, layout.grid.height))
	check(impassable == 0, "all %d sections are passable from the entrance to the gate (%d are not)" % [SEED_COUNT, impassable])
	check(wrong_content == 0, "every section has the enemies, health packs, coins and chest of its plan (%d do not)" % wrong_content)
	check(enemies_at_start == 0, "no enemy stands in the first room (%d do)" % enemies_at_start)
	check(enemies_outside == 0, "every enemy starts inside its room, not in a doorway or tunnel (%d do not)" % enemies_outside)
	check(too_big == 0, "ordinary sections stay within %dx%d tiles, arenas within %dx%d (largest: %s)" % [MAX_WIDTH, MAX_HEIGHT, MAX_ARENA_WIDTH, MAX_ARENA_HEIGHT, max_size])
	check(missing_branch == 0, "every planned side branch is built (%d sections miss one)" % missing_branch)
	check(directions.size() == 4, "sections run in all four directions (%s)" % [directions.keys()])
	check(empty_rooms == 0, "every room but the first has enemies, an item or hazards (%d empty)" % empty_rooms)
	check(bad_arenas == 0, "arena sections keep all enemies in the last room, in waves, with its doors listed (%d bad)" % bad_arenas)
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
	plan.chests = i % 3
	plan.side_branches = mini(plan.chests, i % 2 + 1) if plan.chests > 0 else 0
	plan.is_arena = i % 5 == 4
	plan.waves = 2 if plan.is_arena else 1
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
	if layout.count_items(SectionLayout.ITEM_COIN) < plan.coins:
		return false
	return layout.count_items(SectionLayout.ITEM_CHEST) == plan.chests


## Direction of a step between two neighbouring rooms of the path.
func _direction(from: Rect2i, to: Rect2i) -> String:
	var step: Vector2 = Vector2(to.get_center() - from.get_center())
	if absf(step.x) > absf(step.y):
		return "right" if step.x > 0.0 else "left"
	return "down" if step.y > 0.0 else "up"


## Rooms of the path (not the first) with no enemy, no item and no hazard tiles.
func _count_empty_rooms(layout: SectionLayout) -> int:
	var empty: int = 0
	for i in range(1, layout.path_room_count):
		var busy: bool = false
		for entry: Dictionary in layout.enemies + layout.items:
			if int(entry["room"]) == i:
				busy = true
		var rect: Rect2i = layout.room_rects[i]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell: LevelGrid.Cell = layout.grid.get_cell(Vector2i(x, y))
				if cell == LevelGrid.Cell.PIT or cell == LevelGrid.Cell.SPIKES:
					busy = true
		if not busy:
			empty += 1
	return empty


func _arena_ok(layout: SectionLayout, plan: SectionPlan) -> bool:
	if layout.arena_room != layout.path_room_count - 1 or layout.arena_doors.is_empty():
		return false
	for entry: Dictionary in layout.enemies:
		if int(entry["room"]) != layout.arena_room:
			return false
	return layout.wave_count() == mini(plan.waves, plan.get_spawn_count())
