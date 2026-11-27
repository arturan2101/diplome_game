extends TestCase
## Headless test for stage 50, part 1: the boss attack patterns. Rays of lashes warn
## first, strike only on their bands, stop at walls (not at pillars), a second volley turns
## into the gaps; the sweeping arms start with the player in a gap and hurt what they
## reach as they turn; a field of cells bursts in waves that light alternate halves;
## the hazards' predictions (threatens) match the real hits; they vanish with their boss;
## a bot finds a safe spot out of a warning, and a bot that reads patterns takes far
## fewer hits than one that ignores them.

const MASK: int = TestFactory.PLAYER_HURTBOX_LAYER
const RAYS: String = "res://actors/enemies/boss_patterns/mother_rays.tres"
const RAYS_DOUBLE: String = "res://actors/enemies/boss_patterns/mother_rays_double.tres"
const SWEEP: String = "res://actors/enemies/boss_patterns/mother_sweep.tres"
const CHECKER: String = "res://actors/enemies/boss_patterns/mother_spore_checker.tres"
const STRIPES: String = "res://actors/enemies/boss_patterns/mother_spore_stripes.tres"
const RINGS: String = "res://actors/enemies/boss_patterns/mother_spore_rings.tres"
const GAME_SCENE: String = "res://main/main.tscn"
const ENEMY_SCENE: String = "res://actors/enemies/enemy.tscn"
const SKELETON: String = "res://actors/enemies/skeleton.tres"
## An open room, 21 x 15 cells like the arena, with one cover cell 4 cells right of the
## centre (C marks the centre).
const ROOM: String = """#####################
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#.........C...%.....#
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#####################"""
const CENTER: Vector2i = Vector2i(10, 7)

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
## How many hazards the reading bot still remembered after the last one was gone.
var _known_left: int = -1


func run() -> void:
	_rng.seed = 50
	await _test_rays()
	await _test_volleys()
	await _test_sweep()
	await _test_field()
	await _test_caster_dies()
	await _test_escape()
	await _test_bot_reads()


func _level() -> Level:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(ROOM.replace("C", ".")))
	return level


func _target(level: Level, at: Vector2) -> Node2D:
	var target: Node2D = TestFactory.player_target(1000)
	level.add_child(target)
	target.global_position = at
	return target


func _hp(target: Node2D) -> int:
	return (target.get_node("Health") as Health).hp


func _cast(path: String, level: Level, origin: Vector2, toward: Vector2, aimed: bool = false) -> Array[BossHazard]:
	var pattern: BossPattern = (load(path) as BossPattern).duplicate() as BossPattern
	if pattern is RaysPattern:
		(pattern as RaysPattern).aim_at_target = aimed
	return pattern.cast(level, origin, toward, null, &"test_boss", 1.0, MASK, _rng)


func _clear(level: Level) -> void:
	level.queue_free()
	await physics_frames(2)


func _test_rays() -> void:
	var level: Level = _level()
	var origin: Vector2 = level.cell_center(CENTER)
	# One lash aimed at a target 3 cells up; another stands in a gap.
	var hit_spot: Vector2 = origin + Vector2(0.0, -48.0)
	var gap_spot: Vector2 = origin + Vector2.from_angle(-PI * 0.5 + TAU / 12.0) * 60.0
	var on_line: Node2D = _target(level, hit_spot)
	var in_gap: Node2D = _target(level, gap_spot)
	var pattern: RaysPattern = load(RAYS) as RaysPattern
	var made: Array[BossHazard] = _cast(RAYS, level, origin, hit_spot, true)
	check(made.size() == pattern.count, "the rays make one lash per direction (%d)" % made.size())
	var line: LineHazard = made[0] as LineHazard
	check(line.threatens(hit_spot, 6.0, 0.0, 1.0) and not line.threatens(hit_spot, 6.0, 0.0, pattern.warn_time - 0.1),
			"the aimed lash will hurt the player's spot, but only after its warning")
	var any_gap_threat: bool = false
	for hazard: BossHazard in made:
		any_gap_threat = any_gap_threat or hazard.threatens(gap_spot, 6.0, 0.0, 2.0)
	check(not any_gap_threat, "the wedge between two lashes is safe")
	await physics_frames(roundi((pattern.warn_time - 0.1) * 60.0))
	check(_hp(on_line) == 1000, "nothing is hurt while the warning shows")
	await physics_frames(roundi(0.3 * 60.0))
	check(_hp(on_line) == 1000 - pattern.damage and _hp(in_gap) == 1000,
			"the strike hurts on the lash (%d) and not in the gap (%d)" % [_hp(on_line), _hp(in_gap)])
	await physics_frames(roundi((pattern.hold_time + pattern.retract_time + 0.2) * 60.0))
	check(get_tree().get_nodes_in_group(BossHazard.GROUP).is_empty(), "the lashes are gone when they are done")
	# Aimed right, a lash passes over the pillar 4 cells away and stops at the wall.
	var right: LineHazard = _cast(RAYS, level, origin, origin + Vector2(300.0, 0.0), true)[0] as LineHazard
	var behind: Vector2 = level.cell_center(Vector2i(16, 7))
	var wall: float = level.cell_center(Vector2i(20, 7)).x - 8.0 - origin.x
	check(right.threatens(behind, 6.0, 0.0, 2.0) and right.length <= wall and right.length > wall - 4.1,
			"a lash goes over a pillar and stops at the wall (%.0f of %.0f px)" % [right.length, wall])
	await _clear(level)


func _test_volleys() -> void:
	var level: Level = _level()
	var origin: Vector2 = level.cell_center(CENTER)
	var pattern: RaysPattern = load(RAYS_DOUBLE) as RaysPattern
	var made: Array[BossHazard] = _cast(RAYS_DOUBLE, level, origin, origin + Vector2.RIGHT * 50.0, true)
	var gap: float = TAU / pattern.count
	var first: LineHazard = made[0] as LineHazard
	var second: LineHazard = made[pattern.count] as LineHazard
	check(made.size() == pattern.count * 2 and is_equal_approx(second.start_delay, pattern.warn_time),
			"a second volley waits until the first strikes")
	check(is_equal_approx(angle_difference(first.rotation, second.rotation), gap * pattern.volley_turn),
			"and turns by half a gap, into the wedges that were safe")
	var spot: Vector2 = origin + Vector2.from_angle(first.rotation + gap * 0.5) * 50.0
	check(not first.threatens(spot, 6.0, 0.0, 3.0) and second.threatens(spot, 6.0, 0.0, 3.0),
			"a spot safe from the first volley is hit by the second")
	await _clear(level)


func _test_sweep() -> void:
	var level: Level = _level()
	var origin: Vector2 = level.cell_center(CENTER)
	var player_spot: Vector2 = origin + Vector2(48.0, 0.0)
	var pattern: SweepPattern = load(SWEEP) as SweepPattern
	var sweep: SweepHazard = _cast(SWEEP, level, origin, player_spot)[0] as SweepHazard
	var direction: float = signf(sweep.turn_speed)
	var gap_middle: bool = true
	for i in sweep.arms:
		gap_middle = gap_middle and absf(angle_difference(sweep.arm_angle(i), 0.0)) >= PI / sweep.arms - 0.01
	check(gap_middle and not sweep.threatens(player_spot, 6.0, 0.0, pattern.warn_time + 0.5),
			"the arms start with the player in the middle of a gap, safe for a while")
	# A target a little ahead of the first arm, where it turns.
	var ahead_angle: float = sweep.arm_angle(0) + direction * 0.6
	var ahead: Vector2 = origin + Vector2.from_angle(ahead_angle) * 56.0
	var reached: float = pattern.warn_time + 0.6 / deg_to_rad(pattern.turn_speed_degrees)
	check(not sweep.threatens(ahead, 6.0, 0.0, pattern.warn_time) and sweep.threatens(ahead, 6.0, 0.0, reached + 0.2),
			"nothing turns during the warning; the arm reaches the spot ahead later")
	var target: Node2D = _target(level, ahead)
	await physics_frames(roundi((reached - 0.35) * 60.0))
	check(_hp(target) == 1000, "not hurt before the arm gets there")
	await physics_frames(roundi(0.6 * 60.0))
	check(_hp(target) < 1000, "hurt when the arm sweeps over it")
	var turned: float = absf(angle_difference(sweep.arm_angle_at(0, 0.0), sweep.arm_angle_at(0, 1.0)))
	check(is_equal_approx(turned, deg_to_rad(pattern.turn_speed_degrees)), "the arms turn at the pattern's speed")
	await _clear(level)


func _test_field() -> void:
	var level: Level = _level()
	var origin: Vector2 = level.cell_center(CENTER)
	var pattern: FieldPattern = load(CHECKER) as FieldPattern
	var field: FieldHazard = _cast(CHECKER, level, origin, origin)[0] as FieldHazard
	var disjoint: bool = true
	var covered: bool = true
	var first_cell: Vector2i = Vector2i(-1, -1)
	var second_cell: Vector2i = Vector2i(-1, -1)
	for y in range(1, 14):
		for x in range(1, 20):
			var cell: Vector2i = Vector2i(x, y)
			if level.cell_center(cell).distance_to(origin) > pattern.area_radius or not level.grid.is_walkable(cell):
				continue
			var a: bool = field.is_lit(0, cell)
			var b: bool = field.is_lit(1, cell)
			disjoint = disjoint and not (a and b)
			covered = covered and (a or b)
			if a and first_cell.x < 0 and level.cell_center(cell).distance_to(origin) > 40.0:
				first_cell = cell
			if b and second_cell.x < 0 and level.cell_center(cell).distance_to(origin) > 40.0:
				second_cell = cell
	check(field.wave_count() == pattern.waves and disjoint and covered,
			"the chequerboard's waves light alternate halves of the floor around the boss")
	var on_first: Node2D = _target(level, level.cell_center(first_cell))
	var on_second: Node2D = _target(level, level.cell_center(second_cell))
	check(field.threatens(level.cell_center(first_cell), 4.0, 0.0, pattern.warn_time + 0.05)
			and not field.threatens(level.cell_center(second_cell), 4.0, 0.0, pattern.warn_time + 0.05),
			"the first wave threatens only its own cells")
	await physics_frames(roundi((pattern.warn_time + 0.08) * 60.0))
	check(_hp(on_first) < 1000 and _hp(on_second) == 1000, "the first burst hurts on its cells only")
	await physics_frames(roundi(pattern.warn_time * 60.0))
	check(_hp(on_second) < 1000, "the second wave bursts on the cells the first left dark")
	# Stripes and rings light about half the floor each.
	for path: String in [STRIPES, RINGS]:
		var other: FieldHazard = _cast(path, level, origin, origin)[0] as FieldHazard
		var lit: int = 0
		var total: int = 0
		for y in range(1, 14):
			for x in range(1, 20):
				var cell: Vector2i = Vector2i(x, y)
				if level.cell_center(cell).distance_to(origin) <= (load(path) as FieldPattern).area_radius 						and level.grid.is_walkable(cell):
					total += 1
					lit += 1 if other.is_lit(0, cell) else 0
		check(lit > total / 4 and lit < total * 3 / 4, "%s lights part of the floor (%d of %d)" % [path.get_file(), lit, total])
	await _clear(level)


func _test_caster_dies() -> void:
	var level: Level = _level()
	var boss: Enemy = TestFactory.enemy(TestFactory.melee_enemy_data(&"skeleton"))
	level.add_child(boss)
	boss.global_position = level.cell_center(CENTER)
	await physics_frames(2)
	var pattern: BossPattern = load(SWEEP) as BossPattern
	pattern.cast(level, boss.global_position, boss.global_position + Vector2.RIGHT, boss, &"skeleton", 1.0, MASK, _rng)
	await physics_frames(5)
	check(not get_tree().get_nodes_in_group(BossHazard.GROUP).is_empty(), "the sweep is on the floor")
	boss.health.take_damage(DamageInfo.new(100000, null, &"test"))
	await physics_frames(3)
	check(get_tree().get_nodes_in_group(BossHazard.GROUP).is_empty(), "when its boss dies the pattern vanishes")
	await _clear(level)


func _test_escape() -> void:
	var level: Level = _level()
	var origin: Vector2 = level.cell_center(CENTER)
	var standing: Vector2 = origin + Vector2(0.0, -40.0)
	var made: Array[BossHazard] = _cast(RAYS, level, origin, standing, true)
	await physics_frames(1)
	var spot: Vector2 = HazardEscape.find_spot(level, get_tree(), standing, 90.0, 8.0, made)
	var safe: bool = spot != Vector2.INF and not BossHazard.threat_at(get_tree(), spot, 8.0, 0.0, 2.0, made)
	check(safe and standing.distance_to(spot) <= 26.0 and level.cell_type_at(spot) == LevelGrid.Cell.FLOOR,
			"from a lash's warning the bot finds a near safe spot (%.0f px)" % standing.distance_to(spot))
	var sweep: Array[BossHazard] = _cast(SWEEP, level, origin, origin + Vector2(60.0, 0.0))
	var arm: SweepHazard = sweep[0] as SweepHazard
	var in_way: Vector2 = origin + Vector2.from_angle(arm.arm_angle(0) + signf(arm.turn_speed) * 0.3) * 50.0
	var away: Vector2 = HazardEscape.find_spot(level, get_tree(), in_way, 90.0, 8.0, sweep)
	var walk: float = in_way.distance_to(away) / 90.0
	check(away != Vector2.INF and not arm.threatens(away, 8.0, walk, walk + HazardEscape.DEFAULT_HORIZON),
			"in the way of a sweeping arm it finds a spot the arm does not reach soon")
	await _clear(level)


## A bot in a real game with patterns cast at it again and again: reading them saves it.
func _test_bot_reads() -> void:
	var reading: int = await _bot_hits(1.0)
	var blind: int = await _bot_hits(0.0)
	check(blind > 0 and reading * 3 <= blind, "a bot that reads patterns is hit far less (%d) than one that does not (%d)"
			% [reading, blind])
	check(_known_left == 0, "the bot forgets hazards once they are gone, even freed unseen (%d left)" % _known_left)


func _bot_hits(read_chance: float) -> int:
	GameManager.start_run(5000)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	game.player.health.max_hp = 100000
	game.player.health.reset()
	var enemies: Array[Enemy] = game.get_enemies()
	var contents: Node = enemies[0].get_parent()
	for enemy: Enemy in enemies:
		enemy.queue_free()
	# One harmless enemy far away keeps the bot in the section (and walking).
	var keep: Enemy = (load(ENEMY_SCENE) as PackedScene).instantiate() as Enemy
	keep.data = load(SKELETON) as EnemyData
	contents.add_child(keep)
	await physics_frames(2)
	keep.set_physics_process(false)
	keep.health.max_hp = 100000
	keep.health.reset()
	var profile: BotProfile = (BotPlayer.load_profile("strong")).duplicate() as BotProfile
	profile.pattern_read_chance = read_chance
	profile.dodge_chance = 0.0
	var bot: BotPlayer = game.add_bot(profile)
	var hits: Array[int] = [0]
	game.player.health.damaged.connect(func(info: DamageInfo) -> void:
		if info.source_id == &"test_boss":
			hits[0] += 1)
	var patterns: Array[String] = [RAYS, CHECKER, RAYS, STRIPES]
	for i in patterns.size():
		# Cast from a little beside the player, aimed at it.
		var at: Vector2 = game.player.global_position
		var origin: Vector2 = at + Vector2.from_angle(_rng.randf() * TAU) * 24.0
		if game.level.cell_type_at(origin) != LevelGrid.Cell.FLOOR:
			origin = at
		_cast(patterns[i], game.level, origin, at, true)
		await physics_frames(roundi(2.2 * 60.0))
	if read_chance > 0.0:
		while not get_tree().get_nodes_in_group(BossHazard.GROUP).is_empty():
			await physics_frames(1)
		await physics_frames(2)
		# One freed while the bot was not looking (a section change): it must go too.
		var gone: LineHazard = LineHazard.new()
		bot._hazard_known.append(gone)
		gone.free()
		bot._read_hazards(0.0)
		_known_left = bot._hazard_known.size()
	game.queue_free()
	await physics_frames(3)
	return hits[0]
