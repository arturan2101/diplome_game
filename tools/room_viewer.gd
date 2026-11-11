extends Node2D
## Shows one room template with its slots marked, to check a hand-edited map.
## Run tools/room_viewer.tscn (F6) after setting room_name on the root node.

## Name of the room to show (the "; name:" of a file in res://rooms).
@export var room_name: String = "pillar_hall"
@export var slot_color: Color = Color(1.0, 1.0, 1.0, 0.9)
@export var door_color: Color = Color(0.3, 1.0, 0.5, 0.5)

const TILE: float = 16.0
const MARGIN: Vector2 = Vector2(16.0, 16.0)
const FONT_SIZE: int = 10

var _template: RoomTemplate = null


func _ready() -> void:
	var library: RoomLibrary = RoomLibrary.get_default()
	for problem: String in library.errors:
		print("Room error: ", problem)
	_template = library.get_by_name(StringName(room_name))
	if _template == null:
		push_error("No valid room named '%s' in %s" % [room_name, RoomLibrary.ROOMS_DIR])
		return
	var level: Level = Level.new()
	level.position = MARGIN
	add_child(level)
	level.build(_template.grid)
	# Children are normally drawn over their parent; this puts the tiles under the markers.
	level.show_behind_parent = true
	queue_redraw()


func _draw() -> void:
	if _template == null:
		return
	var font: Font = ThemeDB.fallback_font
	for side: RoomTemplate.DoorSide in _template.doors:
		for cell: Vector2i in _template.doors[side]:
			draw_rect(Rect2(MARGIN + Vector2(cell) * TILE, Vector2(TILE, TILE)), door_color)
	var slots: Dictionary = {
		RoomTemplate.ENEMY_SLOT: _template.enemy_slots,
		RoomTemplate.COVER_SLOT: _template.cover_slots,
		RoomTemplate.ITEM_SLOT: _template.item_slots,
		RoomTemplate.CHEST_SLOT: _template.chest_slots,
	}
	for symbol: String in slots:
		for cell: Vector2i in slots[symbol]:
			draw_string(font, MARGIN + (Vector2(cell) + Vector2(0.25, 0.8)) * TILE, symbol,
					HORIZONTAL_ALIGNMENT_LEFT, -1.0, FONT_SIZE, slot_color)
