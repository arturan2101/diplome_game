class_name SpellShelfScreen
extends CanvasLayer
## The camp shelf's screen (stage 36): every spell of the pool, open from the start,
## unlocked, or with its price in ruin shards. Only unlocked spells turn up in a run
## (scrolls, shrines, the merchant). The game is paused while it is open.

signal closed

@export var panel_texture: Texture2D = preload("res://assets/art/ui/skill_panel.png")
@export var row_size: Vector2 = Vector2(360.0, 34.0)

var pool: SpellPool = null

var _panel: Control = null
var _title: Label = null
var _rows: VBoxContainer = null
var _buttons: Dictionary = {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 20
	_build()
	_panel.visible = false


func is_open() -> bool:
	return _panel.visible


func open(spell_pool: SpellPool) -> void:
	pool = spell_pool
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


func refresh() -> void:
	for child: Node in _rows.get_children():
		_rows.remove_child(child)
		child.queue_free()
	_buttons.clear()
	_title.text = "Spells on the shelf  -  ruin shards: %d" % Progress.shards
	for spell_data: SpellData in pool.spells:
		var button: Button = Button.new()
		button.icon = spell_data.icon
		button.expand_icon = false
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.custom_minimum_size = row_size
		var open_now: bool = spell_data.unlocked_from_start or Progress.is_spell_unlocked(spell_data.id)
		var state: String = "known from the start" if spell_data.unlocked_from_start else ("unlocked" if open_now
				else "unlock for %d shards" % spell_data.unlock_cost)
		button.text = "%s  -  %s" % [spell_data.display_name, state]
		button.disabled = open_now or spell_data.unlock_cost > Progress.shards
		button.pressed.connect(_on_unlock_pressed.bind(spell_data))
		_rows.add_child(button)
		_buttons[spell_data.id] = button
	var back: Button = Button.new()
	back.text = "Back"
	back.pressed.connect(close)
	_rows.add_child(back)


## The row button of a spell (for tests).
func get_spell_button(spell_id: StringName) -> Button:
	return _buttons.get(spell_id) as Button


func _on_unlock_pressed(spell_data: SpellData) -> void:
	if Progress.is_spell_unlocked(spell_data.id) or not Progress.spend_shards(spell_data.unlock_cost):
		return
	Progress.unlock_spell(spell_data.id)
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
	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 6)
	box.add_child(_rows)


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open():
		close()
