extends TestCase
## Headless test for the exit portal of stage 42 and the art wired in with it: the
## generator puts the exit where the whole portal stands on plain floor inside the room
## (never in a wall), the portal stands dark and lights up when it opens, the boss portal
## rises smoothly out of the floor, the teleport flies over cover but not walls, and
## cover obstacles keep their collision.

const GAME_SCENE: String = "res://main/main.tscn"
const SETTINGS: String = "res://director/director_settings.tres"
const TELEPORT: String = "res://combat/skills/teleport.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const SECTIONS: int = 60
## A gravestone row between the player and floor, a wall further on.
const COVER_MAP: String = """###########
#...%.....#
###########"""


## A row of cover cells under a wall: tall pieces fit there (nothing walks behind them).
const OBSTACLE_MAP: String = """##########
#%%%%%%%%#
#........#
##########"""


func run() -> void:
	_test_exit_spots()
	await _test_portal()
	await _test_boss_portal()
	await _test_teleport_over_cover()
	await _test_cover_obstacles()


## In many built sections the portal's footprint is plain floor and nothing else lies on it.
func _test_exit_spots() -> void:
	var settings: DirectorSettings = load(SETTINGS) as DirectorSettings
	var director: RuleDirector = RuleDirector.new(null, settings)
	var builder: SectionBuilder = SectionBuilder.new()
	var fits: int = 0
	var clear: bool = true
	for i in SECTIONS:
		var state: PlayerState = PlayerState.new()
		state.section_index = i
		state.depth = i % 4
		state.is_depth_end = i % 4 == 3
		state.rng.seed = 900 + i
		var plan: SectionPlan = director.choose_next(state)
		var rng: RandomNumberGenerator = RandomNumberGenerator.new()
		rng.seed = 77 + i
		var layout: SectionLayout = builder.build(plan, rng)
		var ok: bool = true
		for cell: Vector2i in SectionBuilder.gate_footprint(layout.exit):
			if layout.grid.get_cell(cell) != LevelGrid.Cell.FLOOR:
				ok = false
		if ok:
			fits += 1
		for entry: Dictionary in layout.items:
			if entry["cell"] in SectionBuilder.gate_footprint(layout.exit):
				clear = false
	check(fits >= SECTIONS * 9 / 10, "the portal stands on plain floor, never in a wall (%d of %d sections)" % [fits, SECTIONS])
	check(clear, "nothing lies on the portal's cells")


func _test_portal() -> void:
	var gate: Gate = (load("res://level/gate.tscn") as PackedScene).instantiate() as Gate
	add_child(gate)
	await physics_frames(1)
	check(gate.sprite.region_rect.position.x == gate.dark_frame * gate.frame_size.x, "closed: the portal stands dark")
	gate.open()
	await physics_frames(roundi(0.4 * Engine.physics_ticks_per_second))
	check(gate.is_open and gate.get_node_or_null("Loop") != null and not gate.sprite.visible, "open: its runes light up, then the light loops")
	gate.queue_free()
	await physics_frames(1)


func _test_boss_portal() -> void:
	var gate: Gate = (load("res://level/gate.tscn") as PackedScene).instantiate() as Gate
	gate.rises = true
	add_child(gate)
	await physics_frames(1)
	check(gate.sprite.region_rect.position.x == gate.crack_frame * gate.frame_size.x, "before the boss falls: only cracks in the floor")
	gate.open()
	await physics_frames(roundi(gate.rise_time * 0.5 * Engine.physics_ticks_per_second))
	var half: float = gate.sprite.region_rect.size.y
	check(gate.is_rising() and half > 2.0 and half < gate.frame_size.y, "halfway it has risen part of the way (%.0f of %.0f px)" % [half, gate.frame_size.y])
	await physics_frames(roundi((gate.rise_time * 0.5 + 0.5) * Engine.physics_ticks_per_second))
	check(not gate.is_rising() and gate.get_node_or_null("Loop") != null, "then it stands full height and its light loops")
	gate.queue_free()
	await physics_frames(1)


func _test_teleport_over_cover() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(COVER_MAP))
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.global_position = level.cell_center(Vector2i(2, 1))
	player.set_skill(load(TELEPORT) as SkillData)
	await physics_frames(3)
	player.skill.press(Vector2.RIGHT)
	var cell: Vector2i = level.cell_at(player.global_position)
	check(cell.x > 4 and cell.x <= 9 and level.grid.is_floor(cell), "the teleport flies over a gravestone (landed on %s)" % [cell])
	player.queue_free()
	level.queue_free()
	await physics_frames(1)


func _test_cover_obstacles() -> void:
	var level: Level = Level.new()
	add_child(level)
	# A row of cover cells under a wall: tall pieces fit (nothing walks behind them).
	level.build(LevelGrid.from_text(OBSTACLE_MAP))
	await physics_frames(3)
	var pieces: int = 0
	var solid: bool = true
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	for x in range(1, 9):
		var cell: Vector2i = Vector2i(x, 1)
		if level.cover_piece(cell) != null:
			pieces += 1
		var probe: PhysicsPointQueryParameters2D = PhysicsPointQueryParameters2D.new()
		probe.position = level.cell_center(cell)
		probe.collision_mask = 1
		if space.intersect_point(probe).is_empty():
			solid = false
	check(pieces > 0, "some cover cells show obstacles (%d of 8)" % pieces)
	check(solid, "every cover cell stays solid, obstacle or not")
	level.queue_free()
	await physics_frames(1)
