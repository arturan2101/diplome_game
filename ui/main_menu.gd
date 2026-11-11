extends Control
## Main menu: a title screen, then the choice of the starting weapon and basic skill,
## then the run. Also holds the hidden experiment panel (director mode and seed),
## opened by F1 or by holding a finger on the title. The mode is never shown to the
## player; it only goes to the log.

const GAME_SCENE: String = "res://main/main.tscn"
## Launch argument that skips the menu and lets the bot play.
const BOT_ARG: String = "--bot"
const RANDOM_SEED_TEXT: String = ""

## Weapons and skills offered before a run. Adding one here adds a button.
@export var weapons: Array[WeaponData] = []
@export var skills: Array[SkillData] = []
@export var title_screen: Control
@export var loadout_screen: Control
@export var title_label: Control
@export var play_button: Button
@export var quit_button: Button
@export var weapon_row: Container
@export var skill_row: Container
@export var start_button: Button
@export var back_button: Button
@export var debug_panel: Control
@export var mode_option: OptionButton
@export var seed_edit: LineEdit
## Seconds to hold the title to open the experiment panel.
@export var debug_hold_time: float = 1.5

var _selected_weapon: WeaponData = null
var _selected_skill: SkillData = null
var _title_held_time: float = -1.0


func _ready() -> void:
	get_tree().paused = false
	if BOT_ARG in OS.get_cmdline_user_args():
		_start_run.call_deferred()
		return
	play_button.pressed.connect(_show_loadout.bind(true))
	back_button.pressed.connect(_show_loadout.bind(false))
	start_button.pressed.connect(_start_run)
	quit_button.pressed.connect(get_tree().quit)
	# There is nothing to quit to on a phone.
	quit_button.visible = not OS.has_feature("mobile")
	title_label.gui_input.connect(_on_title_input)
	_selected_weapon = _fill_row(weapon_row, weapons, GameManager.starting_weapon, _on_weapon_chosen)
	_selected_skill = _fill_row(skill_row, skills, GameManager.starting_skill, _on_skill_chosen)
	_setup_debug_panel()
	_show_loadout(false)


func _process(delta: float) -> void:
	if _title_held_time < 0.0:
		return
	_title_held_time += delta
	if _title_held_time >= debug_hold_time:
		_title_held_time = -1.0
		_toggle_debug_panel()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		_toggle_debug_panel()


func _show_loadout(show_loadout: bool) -> void:
	title_screen.visible = not show_loadout
	loadout_screen.visible = show_loadout


## Makes one toggle button per item (weapon or skill) and presses the current one.
## Returns the selected item.
func _fill_row(row: Container, items: Array, current: Resource, on_chosen: Callable) -> Resource:
	var group: ButtonGroup = ButtonGroup.new()
	var selected: Resource = items[0] if not items.is_empty() else null
	for item: Resource in items:
		var button: Button = Button.new()
		button.text = item.display_name
		button.icon = item.icon
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(110.0, 32.0)
		button.pressed.connect(on_chosen.bind(item))
		row.add_child(button)
		if item == current:
			selected = item
			button.button_pressed = true
	if selected != current and row.get_child_count() > 0:
		(row.get_child(0) as Button).button_pressed = true
	return selected


func _on_weapon_chosen(weapon_data: WeaponData) -> void:
	_selected_weapon = weapon_data


func _on_skill_chosen(skill_data: SkillData) -> void:
	_selected_skill = skill_data


func _start_run() -> void:
	if _selected_weapon != null:
		GameManager.starting_weapon = _selected_weapon
	if _selected_skill != null:
		GameManager.starting_skill = _selected_skill
	GameManager.start_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _setup_debug_panel() -> void:
	debug_panel.visible = false
	for mode_name: String in GameManager.DirectorMode.keys():
		mode_option.add_item(mode_name)
	mode_option.select(GameManager.director_mode)
	mode_option.item_selected.connect(_on_mode_selected)
	seed_edit.text = RANDOM_SEED_TEXT if GameManager.forced_seed == GameManager.RANDOM_SEED else str(GameManager.forced_seed)
	seed_edit.text_changed.connect(_on_seed_changed)


func _toggle_debug_panel() -> void:
	debug_panel.visible = not debug_panel.visible


func _on_mode_selected(index: int) -> void:
	GameManager.director_mode = index as GameManager.DirectorMode


func _on_seed_changed(text: String) -> void:
	GameManager.forced_seed = text.to_int() if text.is_valid_int() else GameManager.RANDOM_SEED


## Holding the title (mouse or finger) opens the experiment panel.
func _on_title_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event as InputEventMouseButton
		if button_event.button_index == MOUSE_BUTTON_LEFT:
			_title_held_time = 0.0 if button_event.pressed else -1.0
	elif event is InputEventScreenTouch:
		_title_held_time = 0.0 if (event as InputEventScreenTouch).pressed else -1.0
