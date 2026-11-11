class_name PlacedRoom
extends RefCounted
## A room template put at a position of the section grid, with the doors that are
## actually connected to tunnels. Used by SectionBuilder while it builds a section.

var template: RoomTemplate = null
## Top-left cell of the room in the section grid.
var origin: Vector2i = Vector2i.ZERO
## Doors connected to a tunnel; all other doors are walled up.
var used_doors: Array[RoomTemplate.DoorSide] = []


func _init(room_template: RoomTemplate, room_origin: Vector2i) -> void:
	template = room_template
	origin = room_origin


func get_rect() -> Rect2i:
	return Rect2i(origin, template.get_size())


## Middle cell of a door, in section grid cells.
func door_cell(side: RoomTemplate.DoorSide) -> Vector2i:
	return origin + template.door_center(side)


## All cells of a door, in section grid cells.
func door_cells(side: RoomTemplate.DoorSide) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in template.doors[side]:
		cells.append(origin + cell)
	return cells


## Template cells (slots) moved to section grid cells.
func to_section_cells(template_cells: Array[Vector2i]) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	for cell: Vector2i in template_cells:
		cells.append(origin + cell)
	return cells
