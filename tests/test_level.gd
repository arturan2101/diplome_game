extends TestCase
## Headless test for LevelGrid, Level (tiles, wall collision, pathfinding) and
## HazardReceiver (spikes, pits) for a plain body and for an enemy.

const TILE: float = 16.0
const MAP: String = """##########
#........#
#..~~....#
#..~~..^.#
#........#
#...#....#
#...#....#
##########"""
const ENEMY_MAP: String = """############
#..........#
#....~~....#
#....~~....#
#....~~....#
#..........#
############"""

## A room with a door in a side wall (5, 3-4) and one in the bottom wall (2-3, 6).
const DOOR_MAP: String = """##########
#....#...#
#....#...#
#........#
#........#
#....#...#
##..######
#........#
##########"""
const DOOR_MAP_SEALED: String = """##########
#....#...#
#....#...#
#....#...#
#....#...#
#....#...#
##########
#........#
##########"""

var _damage_sources: Array[StringName] = []
var _fall_events: Array[String] = []


func run() -> void:
	_test_grid()
	await _test_level()
	await _test_changed_cells()
	await _test_spikes()
	await _test_pit()
	await _test_enemy_on_level()


func _test_grid() -> void:
	var grid: LevelGrid = LevelGrid.from_text(MAP)
	check(grid.width == 10 and grid.height == 8, "grid size comes from the text")
	check(grid.get_cell(Vector2i(0, 0)) == LevelGrid.Cell.WALL and grid.get_cell(Vector2i(1, 1)) == LevelGrid.Cell.FLOOR
			and grid.get_cell(Vector2i(3, 2)) == LevelGrid.Cell.PIT and grid.get_cell(Vector2i(7, 3)) == LevelGrid.Cell.SPIKES,
			"text symbols map to cell types")
	check(grid.get_cell(Vector2i(-1, 3)) == LevelGrid.Cell.WALL, "cells outside the grid are walls")
	check(grid.to_text() == MAP, "grid converts back to the same text")
	var reached: Dictionary = grid.reachable_floor(Vector2i(1, 1))
	check(reached.has(Vector2i(8, 6)) and not reached.has(Vector2i(3, 2)) and not reached.has(Vector2i(7, 3)),
			"flood fill walks over floor only")


func _test_level() -> void:
	var level: Level = _add_level(MAP)
	await physics_frames(3)
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	var into_wall: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			_center(2, 1), _center(-1, 1), TestFactory.WORLD_LAYER)
	check(not space.intersect_ray(into_wall).is_empty(), "walls have collision on the world layer")
	var over_pit: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			_center(1, 2), _center(8, 2), TestFactory.WORLD_LAYER)
	check(space.intersect_ray(over_pit).is_empty(), "pits and floor have no collision")
	check(level.cell_type_at(_center(3, 3)) == LevelGrid.Cell.PIT and level.cell_at(_center(7, 3)) == Vector2i(7, 3),
			"world positions map to cells")

	var path: PackedVector2Array = level.find_path(_center(1, 3), _center(8, 3))
	var path_is_safe: bool = not path.is_empty()
	for point: Vector2 in path:
		if level.cell_type_at(point) != LevelGrid.Cell.FLOOR:
			path_is_safe = false
	check(path_is_safe and path[path.size() - 1].is_equal_approx(_center(8, 3)),
			"path reaches the goal over plain floor, around pit and spikes")
	check(level.nearest_safe_position(_center(3, 2)).distance_to(_center(3, 2)) <= TILE * 1.5
			and level.cell_type_at(level.nearest_safe_position(_center(3, 2))) == LevelGrid.Cell.FLOOR,
			"nearest safe position is a floor cell next to the pit")
	level.build(LevelGrid.from_text("#####\n#.#.#\n#####"))
	check(level.find_path(_center(1, 1), _center(3, 1)).is_empty(), "no path between separated rooms")
	level.queue_free()
	await physics_frames(2)


func _test_spikes() -> void:
	var level: Level = _add_level(MAP)
	var body: CharacterBody2D = TestFactory.hazard_body(100)
	var health: Health = body.get_node("Health")
	var hazards: HazardReceiver = body.get_node("HazardReceiver")
	health.damaged.connect(func(info: DamageInfo) -> void: _damage_sources.append(info.source_id))
	body.position = _center(6, 3)
	add_child(body)
	await physics_frames(3)
	check(health.hp == 100, "plain floor does no damage")

	body.position = _center(7, 3)
	await physics_frames(2)
	check(health.hp == 92 and _damage_sources == ([&"spikes"] as Array[StringName]),
			"spikes hurt at once when stepped on, with source spikes")
	await physics_frames(32)
	check(health.hp == 84, "spikes hurt again after the interval")
	hazards.suspended = true
	await physics_frames(40)
	check(health.hp == 84, "an airborne body (dash) ignores spikes")
	body.queue_free()
	level.queue_free()
	await physics_frames(2)


func _test_pit() -> void:
	var level: Level = _add_level(MAP)
	var body: CharacterBody2D = TestFactory.hazard_body(100, 0.5)
	var health: Health = body.get_node("Health")
	var hazards: HazardReceiver = body.get_node("HazardReceiver")
	hazards.fall_started.connect(func() -> void: _fall_events.append("started"))
	hazards.fall_ended.connect(func() -> void: _fall_events.append("ended"))
	_damage_sources.clear()
	health.damaged.connect(func(info: DamageInfo) -> void: _damage_sources.append(info.source_id))
	body.position = _center(5, 2)
	add_child(body)
	await physics_frames(3)

	# Airborne over the pit: nothing happens until the dash ends.
	hazards.suspended = true
	body.position = _center(3, 2)
	await physics_frames(5)
	check(health.hp == 100 and not hazards.is_falling(), "an airborne body does not fall")
	health.make_invulnerable(5.0)
	hazards.suspended = false
	await physics_frames(2)
	check(hazards.is_falling() and health.hp == 70 and _damage_sources == ([&"pit"] as Array[StringName]),
			"ending over a pit means falling: -30% max HP even while invulnerable, source pit")
	check(_fall_events == (["started"] as Array[String]), "fall_started is emitted")
	await physics_frames(40)
	check(not hazards.is_falling() and body.position.is_equal_approx(_center(5, 2)),
			"after the delay the body is back on the last safe tile")
	check(_fall_events == (["started", "ended"] as Array[String]) and health.is_invulnerable(),
			"fall_ended is emitted and the body is invulnerable after the return")
	body.queue_free()
	level.queue_free()
	await physics_frames(2)


func _test_enemy_on_level() -> void:
	var level: Level = _add_level(ENEMY_MAP)
	var target: Node2D = TestFactory.player_target(1000)
	target.position = _center(9, 3)
	add_child(target)
	var enemy: Enemy = TestFactory.enemy(TestFactory.melee_enemy_data(&"skeleton"), true)
	enemy.position = _center(2, 3)
	add_child(enemy)
	await physics_frames(3)

	var fell: bool = false
	for _i in 400:
		if enemy.state == Enemy.State.WINDUP:
			break
		if enemy.state == Enemy.State.FALLING:
			fell = true
		await get_tree().physics_frame
	check(enemy.state == Enemy.State.WINDUP and not fell and enemy.health.hp == enemy.data.max_hp,
			"enemy walks around the pit to reach the player")

	# Knocked into the pit: it falls like the player and comes back.
	enemy.position = _center(4, 3)
	enemy.apply_knockback(Vector2(150.0, 0.0))
	var entered_fall: bool = false
	for _i in 60:
		if enemy.state == Enemy.State.FALLING:
			entered_fall = true
			break
		await get_tree().physics_frame
	check(entered_fall and enemy.health.hp == enemy.data.max_hp - ceili(enemy.data.max_hp * 0.3),
			"enemy knocked into a pit falls and loses 30% of max HP")
	await physics_frames(45)
	check(enemy.state != Enemy.State.FALLING and level.cell_type_at(enemy.global_position) == LevelGrid.Cell.FLOOR,
			"fallen enemy returns to a safe tile and acts again")
	enemy.queue_free()
	target.queue_free()
	level.queue_free()
	await physics_frames(2)


## Sealing doors (Level.set_cells, as an arena does) must draw the walls exactly as a
## level built with those walls: a side door is a column of cells, so the wall above it
## and the upper door cells lose their brick front; opening the doors brings it back.
func _test_changed_cells() -> void:
	var level: Level = _add_level(DOOR_MAP)
	var doors: Array[Vector2i] = [Vector2i(5, 3), Vector2i(5, 4), Vector2i(2, 6), Vector2i(3, 6)]
	level.set_cells(doors, LevelGrid.Cell.WALL)
	var sealed: Level = _add_level(DOOR_MAP_SEALED)
	check(_same_tiles(level, sealed), "sealed doors are drawn like walls built that way (wall tops above, no stale bricks)")
	await physics_frames(2)
	var space: PhysicsDirectSpaceState2D = level.get_world_2d().direct_space_state
	var through_door: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			_center(4, 3), _center(6, 3), TestFactory.WORLD_LAYER)
	check(not space.intersect_ray(through_door).is_empty(), "a sealed door has wall collision")
	level.set_cells(doors, LevelGrid.Cell.FLOOR)
	var opened: Level = _add_level(DOOR_MAP)
	check(_same_tiles(level, opened), "opened doors are drawn like the level before sealing")
	for node: Level in [level, sealed, opened]:
		node.queue_free()
	await physics_frames(2)


## True if both levels show the same tile in every cell of both layers.
func _same_tiles(a: Level, b: Level) -> bool:
	for layer_name: String in ["Ground", "Props"]:
		var layer_a: TileMapLayer = a.get_node(layer_name) as TileMapLayer
		var layer_b: TileMapLayer = b.get_node(layer_name) as TileMapLayer
		for y in a.grid.height:
			for x in a.grid.width:
				var cell: Vector2i = Vector2i(x, y)
				if layer_a.get_cell_source_id(cell) != layer_b.get_cell_source_id(cell) \
						or layer_a.get_cell_atlas_coords(cell) != layer_b.get_cell_atlas_coords(cell):
					return false
	return true


func _add_level(map: String) -> Level:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(map))
	return level


func _center(x: int, y: int) -> Vector2:
	return Vector2(x + 0.5, y + 0.5) * TILE
