class_name SkillTreeScreen
extends CanvasLayer
## The camp altar's screen (stage 35): the permanent skills as a tree built from a
## PerkTree, one node per skill in its branch column and tier row, lines between a
## skill and the one it needs. A node shows its state (locked, can be bought, bought);
## choosing one shows its name, effect, level and next price, and Buy spends the shards.
## The game is paused while it is open; Esc, the phone's back button or Back close it.

signal closed

## Size of a node on screen (the 20x20 frame art scaled up) and the space between.
@export var node_size: Vector2 = Vector2(40.0, 40.0)
@export var spacing: Vector2 = Vector2(110.0, 58.0)
@export var node_frames: Texture2D = preload("res://assets/art/ui/skill_node.png")
@export var line_texture: Texture2D = preload("res://assets/art/ui/skill_line.png")
@export var panel_texture: Texture2D = preload("res://assets/art/ui/skill_panel.png")
@export var shard_icon: Texture2D = preload("res://assets/sprites/shard.tres")

enum NodeState { LOCKED, AVAILABLE, BOUGHT }

var tree: PerkTree = null
var selected: PerkData = null

var _panel: Control = null
var _nodes_box: Control = null
var _title: Label = null
var _details: Label = null
var _buy: Button = null
var _node_buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open(perk_tree: PerkTree) -> void:
	tree = perk_tree
	selected = null
	get_tree().paused = true
	_panel.visible = true
	refresh()


func close() -> void:
	if not is_open():
		return
	_panel.visible = false
	get_tree().paused = false
	closed.emit()


func _exit_tree() -> void:
	if is_open():
		get_tree().paused = false


## Draws the nodes and lines again for the current levels and shards.
func refresh() -> void:
	for child: Node in _nodes_box.get_children():
		_nodes_box.remove_child(child)
		child.queue_free()
	_node_buttons.clear()
	_title.text = "Skills at the altar  -  ruin shards: %d" % Progress.shards
	for perk: PerkData in tree.perks:
		if perk.requires != null:
			_add_line(perk.requires, perk)
	for perk: PerkData in tree.perks:
		_add_node(perk)
	_show_details()


## A skill's place on the screen (top-left of its node).
func node_position(perk: PerkData) -> Vector2:
	return Vector2(perk.tree_position) * spacing


func state_of(perk: PerkData) -> NodeState:
	if tree.level_of(perk) > 0:
		return NodeState.BOUGHT
	if perk.requires == null or tree.level_of(perk.requires) > 0:
		return NodeState.AVAILABLE
	return NodeState.LOCKED


## The node buttons by skill id (for tests).
func get_node_button(perk_id: StringName) -> Button:
	return _node_buttons.get(perk_id) as Button


func get_buy_button() -> Button:
	return _buy


func select(perk: PerkData) -> void:
	selected = perk
	_show_details()


func _add_node(perk: PerkData) -> void:
	var button: Button = Button.new()
	button.flat = true
	button.custom_minimum_size = node_size
	button.size = node_size
	button.position = node_position(perk)
	button.pressed.connect(select.bind(perk))
	var frame: TextureRect = TextureRect.new()
	var region: AtlasTexture = AtlasTexture.new()
	region.atlas = node_frames
	var cell: float = node_frames.get_height()
	region.region = Rect2(cell * int(state_of(perk)), 0.0, cell, cell)
	frame.texture = region
	frame.stretch_mode = TextureRect.STRETCH_SCALE
	frame.size = node_size
	frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(frame)
	var icon: TextureRect = TextureRect.new()
	icon.texture = perk.icon
	icon.stretch_mode = TextureRect.STRETCH_SCALE
	icon.position = node_size * 0.1
	icon.size = node_size * 0.8
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if state_of(perk) == NodeState.LOCKED:
		icon.modulate = Color(0.45, 0.45, 0.5)
	button.add_child(icon)
	var level: Label = Label.new()
	level.text = "%d/%d" % [tree.level_of(perk), perk.max_level()]
	level.add_theme_font_size_override("font_size", 9)
	level.position = Vector2(node_size.x - 14.0, node_size.y - 6.0)
	level.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(level)
	_nodes_box.add_child(button)
	_node_buttons[perk.id] = button


## A vertical line from the needed skill down to this one, gold once the needed one is bought.
func _add_line(from: PerkData, to: PerkData) -> void:
	var line: TextureRect = TextureRect.new()
	var region: AtlasTexture = AtlasTexture.new()
	region.atlas = line_texture
	var width: float = line_texture.get_width() * 0.5
	var active: bool = tree.level_of(from) > 0
	region.region = Rect2(width if active else 0.0, 0.0, width, line_texture.get_height())
	line.texture = region
	line.stretch_mode = TextureRect.STRETCH_SCALE
	var top: Vector2 = node_position(from) + Vector2(node_size.x * 0.5, node_size.y)
	var bottom: Vector2 = node_position(to) + Vector2(node_size.x * 0.5, 0.0)
	var length: float = top.distance_to(bottom)
	line.size = Vector2(length, line_texture.get_height())
	line.pivot_offset = Vector2.ZERO
	line.rotation = PI * 0.5
	line.position = top + Vector2(line_texture.get_height() * 0.5, 0.0)
	line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_nodes_box.add_child(line)


func _show_details() -> void:
	if selected == null:
		_details.text = "Choose a skill. Shards fall from elite enemies, golems and the Guardian."
		_buy.disabled = true
		_buy.text = "Buy"
		return
	var level: int = tree.level_of(selected)
	var cost: int = selected.cost_after(level)
	var lines: PackedStringArray = PackedStringArray([
		"%s  (level %d of %d)" % [selected.display_name, level, selected.max_level()], selected.description])
	if cost < 0:
		lines.append("At the top level.")
	elif selected.requires != null and tree.level_of(selected.requires) == 0:
		lines.append("Needs %s first." % selected.requires.display_name)
	_details.text = "\n".join(lines)
	_buy.text = "Buy for %d shards" % cost if cost >= 0 else "Bought"
	_buy.disabled = not tree.can_buy(selected)


func _on_buy_pressed() -> void:
	if selected != null and tree.buy(selected):
		refresh()


func _build() -> void:
	_panel = ColorRect.new()
	(_panel as ColorRect).color = Color(0.0, 0.0, 0.0, 0.75)
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)
	var center: CenterContainer = CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	_panel.add_child(center)
	var frame: PanelContainer = PanelContainer.new()
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = panel_texture
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, 8.0)
		style.set_content_margin(side, 14.0)
	frame.add_theme_stylebox_override("panel", style)
	center.add_child(frame)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	frame.add_child(box)
	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_title)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	_nodes_box = Control.new()
	_nodes_box.custom_minimum_size = Vector2(spacing.x * 2.0 + node_size.x, spacing.y * 3.0 + node_size.y)
	row.add_child(_nodes_box)
	var side: VBoxContainer = VBoxContainer.new()
	side.custom_minimum_size = Vector2(170.0, 0.0)
	row.add_child(side)
	_details = Label.new()
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.custom_minimum_size = Vector2(170.0, 120.0)
	_details.add_theme_font_size_override("font_size", 11)
	side.add_child(_details)
	_buy = Button.new()
	_buy.pressed.connect(_on_buy_pressed)
	side.add_child(_buy)
	var back: Button = Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	side.add_child(back)


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open():
		close()
