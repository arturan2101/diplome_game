extends TestCase
## Headless test for room templates: the parser, its validation rules, and every
## real map in res://rooms.

const GOOD_ROOM: String = """; name: test_room
; tags: combat, small
; ref_time: 7.5
#######
#..E..#
D.....D
D..C..D
D.....D
#..I..#
#######"""


func run() -> void:
	_test_parser()
	_test_validation()
	_test_library()
	await _test_level_from_template()


func _test_parser() -> void:
	var room: RoomTemplate = RoomTemplate.parse(GOOD_ROOM, "fallback")
	check(room.is_valid(), "a correct map has no errors: %s" % ", ".join(room.errors))
	check(room.name == &"test_room" and room.tags == ([&"combat", &"small"] as Array[StringName])
			and is_equal_approx(room.ref_time, 7.5), "name, tags and ref_time come from the ';' lines")
	check(room.get_size() == Vector2i(7, 7), "map size is read")
	check(room.has_door(RoomTemplate.DoorSide.WEST) and room.has_door(RoomTemplate.DoorSide.EAST)
			and not room.has_door(RoomTemplate.DoorSide.NORTH), "doors are found by the side of the border")
	check(room.door_center(RoomTemplate.DoorSide.WEST) == Vector2i(0, 3) and room.door_center(RoomTemplate.DoorSide.EAST) == Vector2i(6, 3),
			"door centre is its middle cell")
	check(room.enemy_slots == ([Vector2i(3, 1)] as Array[Vector2i]) and room.cover_slots == ([Vector2i(3, 3)] as Array[Vector2i])
			and room.item_slots == ([Vector2i(3, 5)] as Array[Vector2i]), "slots are collected")
	check(room.grid.is_floor(Vector2i(0, 3)) and room.grid.is_floor(Vector2i(3, 1)) and room.grid.get_cell(Vector2i(0, 0)) == LevelGrid.Cell.WALL,
			"doors and slots are floor in the grid, '#' is wall")
	check(RoomTemplate.parse("#####\nD...D\nD...D\nD...D\n#####", "unnamed").name == &"unnamed", "file name is the fallback name")


func _test_validation() -> void:
	check(_has_error("#####\n#...#\nD...D\nD...D\n#####", "tiles wide"), "a 2-tile door is rejected")
	check(_has_error("#####\nD.D.D\nD...D\nD...D\n#####", "not on the border"), "a door inside the room is rejected")
	check(_has_error("#####\nD...D\nD...D\nD...D\n####", "wide, expected"), "ragged lines are rejected")
	check(_has_error("#####\nD...D\nD...D\nD...D\n#.###", "must be a wall or a door"), "a hole in the border is rejected")
	check(_has_error("#####\nD..?D\nD...D\nD...D\n#####", "unknown symbol"), "unknown symbols are rejected")
	check(_has_error("#####\nD...#\nD...#\nD...#\n#####", "WEST and EAST"), "a room without an east door is rejected")
	check(_has_error("#######\nD.#E#.D\nD.###.D\nD.....D\n#######", "cannot be reached"), "a walled-off slot is rejected")
	check(_has_error("; tags: treasure\n#DDD#\n#...#\n#...#\n#DDD#", "chest slot"), "a treasure room without a chest slot is rejected")


func _test_library() -> void:
	var library: RoomLibrary = RoomLibrary.new()
	library.load_directory(RoomLibrary.ROOMS_DIR)
	check(library.errors.is_empty(), "every map in res://rooms is valid: %s" % ", ".join(library.errors))
	check(library.templates.size() >= 8, "there are at least 8 room templates (%d)" % library.templates.size())
	check(library.filter_by_tag(RoomTemplate.TREASURE_TAG).size() >= 1
			and library.filter_by_tag(RoomTemplate.TREASURE_TAG, false).size() >= 7,
			"there are treasure rooms and ordinary rooms")
	var all_usable: bool = true
	var with_branch_door: int = 0
	for room: RoomTemplate in library.filter_by_tag(RoomTemplate.TREASURE_TAG, false):
		if room.enemy_slots.size() < 2 or room.item_slots.is_empty() or room.ref_time <= 0.0:
			all_usable = false
		if room.has_door(RoomTemplate.DoorSide.NORTH) or room.has_door(RoomTemplate.DoorSide.SOUTH):
			with_branch_door += 1
	check(all_usable, "every ordinary room has at least 2 enemy slots, an item slot and a reference time")
	check(with_branch_door >= 2, "some rooms have a top or bottom door for side branches")
	check(RoomLibrary.get_default() == RoomLibrary.get_default() and RoomLibrary.get_default().get_by_name(&"small_hall") != null,
			"the default library is loaded once and finds rooms by name")


func _test_level_from_template() -> void:
	var room: RoomTemplate = RoomTemplate.parse(GOOD_ROOM, "fallback")
	var level: Level = Level.new()
	add_child(level)
	level.build(room.grid)
	await physics_frames(2)
	var ground: TileMapLayer = level.get_node("Ground") as TileMapLayer
	check(ground.get_used_cells().size() == 49 and level.get_bounds().size == Vector2(112.0, 112.0),
			"a template becomes a TileMapLayer of the same size")
	level.queue_free()
	await physics_frames(2)


func _has_error(map: String, fragment: String) -> bool:
	for problem: String in RoomTemplate.parse(map, "bad").errors:
		if problem.contains(fragment):
			return true
	return false
