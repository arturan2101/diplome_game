class_name RoomTemplate
extends RefCounted
## One room drawn by hand as a text map (res://rooms/*.txt). Holds the tile grid,
## the doors and the slots where the generator may put enemies, cover and items.
## parse() also validates the map; a template with errors must not be used.
## The legend is described in res://rooms/README.md.

enum DoorSide { WEST, EAST, NORTH, SOUTH }

## Width of every door in tiles; tunnels are carved to match.
const DOOR_WIDTH: int = 3
const META_PREFIX: String = ";"
const DOOR: String = "D"
const ENEMY_SLOT: String = "E"
const COVER_SLOT: String = "C"
const ITEM_SLOT: String = "I"
const CHEST_SLOT: String = "T"
const WALL_SYMBOLS: String = "# "
const TREASURE_TAG: StringName = &"treasure"

var name: StringName = &""
var tags: Array[StringName] = []
## Reference time to clear the room, in seconds (the director's T_ref).
var ref_time: float = 10.0
## Tiles of the room; doors and slots are plain floor here.
var grid: LevelGrid = null
## DoorSide -> Array[Vector2i]: the DOOR_WIDTH cells of the door on that side.
var doors: Dictionary = {}
var enemy_slots: Array[Vector2i] = []
var cover_slots: Array[Vector2i] = []
var item_slots: Array[Vector2i] = []
var chest_slots: Array[Vector2i] = []
## Problems found in the map; empty for a usable template.
var errors: PackedStringArray = PackedStringArray()


## Reads a template from text. fallback_name is used when the text has no "; name:" line.
static func parse(text: String, fallback_name: String) -> RoomTemplate:
	var template: RoomTemplate = RoomTemplate.new()
	template.name = StringName(fallback_name)
	var map_lines: PackedStringArray = PackedStringArray()
	for line: String in text.split("\n"):
		line = line.trim_suffix("\r")
		if line.begins_with(META_PREFIX):
			template._read_meta(line.trim_prefix(META_PREFIX))
		elif line.strip_edges() != "" or not map_lines.is_empty():
			map_lines.append(line)
	while not map_lines.is_empty() and map_lines[map_lines.size() - 1].strip_edges() == "":
		map_lines.remove_at(map_lines.size() - 1)
	template._read_map(map_lines)
	return template


func is_valid() -> bool:
	return errors.is_empty()


func has_tag(tag: StringName) -> bool:
	return tag in tags


func has_door(side: DoorSide) -> bool:
	return doors.has(side)


## Middle cell of the door on the given side.
func door_center(side: DoorSide) -> Vector2i:
	var cells: Array = doors[side]
	return cells[cells.size() / 2]


func get_size() -> Vector2i:
	return Vector2i(grid.width, grid.height)


func _read_meta(line: String) -> void:
	var separator: int = line.find(":")
	if separator < 0:
		return
	var key: String = line.substr(0, separator).strip_edges().to_lower()
	var value: String = line.substr(separator + 1).strip_edges()
	match key:
		"name":
			name = StringName(value)
		"tags":
			for tag: String in value.split(",", false):
				tags.append(StringName(tag.strip_edges()))
		"ref_time":
			if value.is_valid_float():
				ref_time = value.to_float()
			else:
				errors.append("ref_time is not a number: %s" % value)


func _read_map(lines: PackedStringArray) -> void:
	if lines.is_empty():
		errors.append("the map is empty")
		grid = LevelGrid.new()
		return
	var width: int = lines[0].length()
	for y in lines.size():
		if lines[y].length() != width:
			errors.append("line %d is %d wide, expected %d" % [y + 1, lines[y].length(), width])
	grid = LevelGrid.from_text("\n".join(lines))
	var door_cells: Dictionary = {}
	for y in lines.size():
		for x in lines[y].length():
			_read_symbol(lines[y][x], Vector2i(x, y), door_cells)
	for side: DoorSide in door_cells:
		_check_door(side, door_cells[side])
	_check_required_doors()
	_check_reachability()


func _read_symbol(symbol: String, cell: Vector2i, door_cells: Dictionary) -> void:
	var on_border: bool = cell.x == 0 or cell.y == 0 or cell.x == grid.width - 1 or cell.y == grid.height - 1
	if symbol == DOOR:
		if not on_border:
			errors.append("door at %s is not on the border" % cell)
			return
		var side: DoorSide = _border_side(cell)
		if not door_cells.has(side):
			door_cells[side] = [] as Array[Vector2i]
		door_cells[side].append(cell)
		return
	if on_border and not WALL_SYMBOLS.contains(symbol):
		errors.append("border cell %s must be a wall or a door, found '%s'" % [cell, symbol])
		return
	match symbol:
		ENEMY_SLOT:
			enemy_slots.append(cell)
		COVER_SLOT:
			cover_slots.append(cell)
		ITEM_SLOT:
			item_slots.append(cell)
		CHEST_SLOT:
			chest_slots.append(cell)
		_:
			if not LevelGrid.TEXT_CELLS.has(symbol):
				errors.append("unknown symbol '%s' at %s" % [symbol, cell])


func _border_side(cell: Vector2i) -> DoorSide:
	if cell.x == 0:
		return DoorSide.WEST
	if cell.x == grid.width - 1:
		return DoorSide.EAST
	if cell.y == 0:
		return DoorSide.NORTH
	return DoorSide.SOUTH


## A door must be exactly DOOR_WIDTH cells in one unbroken run.
func _check_door(side: DoorSide, cells: Array) -> void:
	var side_name: String = DoorSide.keys()[side]
	if cells.size() != DOOR_WIDTH:
		errors.append("%s door is %d tiles wide, expected %d" % [side_name, cells.size(), DOOR_WIDTH])
		return
	for i in range(1, cells.size()):
		var step: Vector2i = cells[i] - cells[i - 1]
		if absi(step.x) + absi(step.y) != 1:
			errors.append("%s door has a gap" % side_name)
			return
	doors[side] = cells


## Ordinary rooms connect left to right; treasure rooms hang above or below a room.
func _check_required_doors() -> void:
	if has_tag(TREASURE_TAG):
		if not (has_door(DoorSide.NORTH) and has_door(DoorSide.SOUTH)):
			errors.append("a treasure room needs NORTH and SOUTH doors")
		if chest_slots.is_empty():
			errors.append("a treasure room needs a chest slot (T)")
	elif not (has_door(DoorSide.WEST) and has_door(DoorSide.EAST)):
		errors.append("a room needs WEST and EAST doors")


## Every door and every slot must be reachable from the first door over plain floor.
func _check_reachability() -> void:
	if doors.is_empty():
		return
	var first_side: DoorSide = doors.keys()[0]
	var reached: Dictionary = grid.reachable_floor(door_center(first_side))
	for side: DoorSide in doors:
		if not reached.has(door_center(side)):
			errors.append("%s door cannot be reached from the other doors" % DoorSide.keys()[side])
	for slot: Vector2i in enemy_slots + cover_slots + item_slots + chest_slots:
		if not reached.has(slot):
			errors.append("slot at %s cannot be reached from the doors" % slot)
