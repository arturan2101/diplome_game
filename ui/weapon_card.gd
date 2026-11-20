class_name WeaponCard
extends PanelContainer
## Card of a weapon lying on the floor (stage 39): its name in the rarity colour (with
## its level once it has grown) and its numbers next to those of the weapon in hand;
## a better number is green, a worse one red. The numbers come from
## WeaponData.get_card_stats(), so a new kind of weapon brings its own lines.
## Built in code; the HUD shows it while the player stands next to a weapon.

@export var font_size: int = 10
@export var better_color: Color = Color("#7ccf5a")
@export var worse_color: Color = Color("#e85a3a")
@export var text_color: Color = Color("#f4f0e0")
@export var muted_color: Color = Color(0.65, 0.65, 0.7)
@export var background_color: Color = Color(0.06, 0.06, 0.09, 0.88)
## Gap between the columns, pixels.
@export var column_gap: int = 8

var _title: Label = null
var _grid: GridContainer = null
var _style: StyleBoxFlat = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_style = StyleBoxFlat.new()
	_style.set_border_width_all(1)
	_style.set_content_margin_all(4.0)
	add_theme_stylebox_override(&"panel", _style)
	var box: VBoxContainer = VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override(&"separation", 2)
	add_child(box)
	_title = _label("")
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	_grid = GridContainer.new()
	_grid.columns = 3
	_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_grid.add_theme_constant_override(&"h_separation", column_gap)
	_grid.add_theme_constant_override(&"v_separation", 0)
	box.add_child(_grid)
	visible = false


## Fills the card for a weapon on the floor, compared with the one in hand (or null).
func show_weapon(lying: WeaponData, in_hand: WeaponData) -> void:
	var rarity_color: Color = lying.get_rarity().color
	_style.bg_color = background_color
	_style.border_color = rarity_color
	_title.text = lying.get_full_name()
	_title.add_theme_color_override(&"font_color", rarity_color)
	for child: Node in _grid.get_children():
		_grid.remove_child(child)
		child.queue_free()
	var hand_lines: Dictionary = {}
	if in_hand != null:
		for line: Dictionary in in_hand.get_card_stats():
			hand_lines[line["name"]] = line
	_add_row("", "Floor", "In hand" if in_hand != null else "", muted_color, muted_color)
	var shown: Dictionary = {}
	for line: Dictionary in lying.get_card_stats():
		shown[line["name"]] = true
		var hand: Dictionary = hand_lines.get(line["name"], {})
		var color: Color = text_color
		if not hand.is_empty():
			if float(line["value"]) > float(hand["value"]) + 0.001:
				color = better_color
			elif float(line["value"]) < float(hand["value"]) - 0.001:
				color = worse_color
		_add_row(line["name"], line["text"], hand.get("text", "-" if in_hand != null else ""), color, muted_color)
	for line_name: String in hand_lines:
		if not shown.has(line_name):
			_add_row(line_name, "-", hand_lines[line_name]["text"], worse_color, muted_color)
	visible = true
	size = get_combined_minimum_size()


## The rows shown now, without the header: [name, floor text, in-hand text]. For tests.
func get_rows() -> Array[PackedStringArray]:
	var rows: Array[PackedStringArray] = []
	var cells: Array[Node] = _grid.get_children().filter(func(cell: Node) -> bool: return not cell.is_queued_for_deletion())
	for i in range(3, cells.size(), 3):
		rows.append(PackedStringArray([(cells[i] as Label).text, (cells[i + 1] as Label).text, (cells[i + 2] as Label).text]))
	return rows


func get_title() -> String:
	return _title.text


func _add_row(line_name: String, lying_text: String, hand_text: String, lying_color: Color, hand_color: Color) -> void:
	_grid.add_child(_label(line_name, muted_color))
	_grid.add_child(_label(lying_text, lying_color))
	_grid.add_child(_label(hand_text, hand_color))


func _label(text: String, color: Color = text_color) -> Label:
	var label: Label = Label.new()
	label.text = text
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override(&"font_size", font_size)
	label.add_theme_color_override(&"font_color", color)
	return label
