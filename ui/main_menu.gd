extends Control
## Main menu: a title screen, then the choice of the starting weapon and basic skill,
## then the run. Also holds the hidden experiment panel (director mode and seed),
## opened by F1 or by holding a finger on the title. The mode is never shown to the
## player; it only goes to the log.

const GAME_SCENE: String = "res://main/main.tscn"
## With the progress between runs, a run starts from the camp at the ruins.
const CAMP_SCENE: String = "res://camp/camp.tscn"
const RANDOM_SEED_TEXT: String = ""

## Weapons and skills offered before a run. Adding one here adds a button.
@export var weapons: Array[WeaponData] = []
@export var skills: Array[SkillData] = []
## Basic skills offered too when batch 8 is on (ExperimentConfig.arsenal): parry, teleport.
@export var arsenal_skills: Array[SkillData] = []
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
## Playtest: the player's id, the start button, log export and a line for messages.
@export var player_id_edit: LineEdit
@export var playtest_button: Button
@export var export_button: Button
@export var status_label: Label
## The title screen's art (stage 42): the background over the whole screen, the
## campfire flames on it (a strip of fire_frames looping at fire_fps, top-left at
## fire_position) and the logo in place of the title text. Null = the plain colour and
## the text title.
@export var background_texture: Texture2D = preload("res://assets/art/ui/menu_background.png")
@export var fire_texture: Texture2D = preload("res://assets/art/ui/menu_fire.png")
@export var fire_frames: int = 3
@export var fire_fps: float = 8.0
@export var fire_position: Vector2 = Vector2(180.0, 284.0)
@export var logo_texture: Texture2D = preload("res://assets/art/ui/title_logo.png")
## Seconds to hold the title to open the experiment panel.
@export var debug_hold_time: float = 1.5

var _selected_weapon: WeaponData = null
var _selected_skill: SkillData = null
var _title_held_time: float = -1.0
var _fire: AtlasTexture = null
var _fire_time: float = 0.0


func _ready() -> void:
	get_tree().paused = false
	Sound.play_music(&"menu_camp")
	# Coming back to the menu ends a playtest session (the experimenter left it).
	if Playtest.is_active:
		Playtest.cancel()
	if BotPlayer.profile_from_command_line() != null:
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
	_refresh_skill_row()
	_setup_debug_panel()
	_make_art()
	_show_loadout(false)


## The background with its flickering fire behind everything, and the logo as the title
## (the title label stays: holding it opens the experiment panel).
func _make_art() -> void:
	if background_texture != null:
		var back: TextureRect = TextureRect.new()
		back.name = "Art"
		back.texture = background_texture
		back.mouse_filter = Control.MOUSE_FILTER_IGNORE
		back.set_anchors_preset(Control.PRESET_FULL_RECT)
		back.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		back.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		add_child(back)
		move_child(back, 1)
		if fire_texture != null:
			_fire = AtlasTexture.new()
			_fire.atlas = fire_texture
			var frame_size: Vector2 = Vector2(fire_texture.get_width() / float(maxi(fire_frames, 1)), fire_texture.get_height())
			_fire.region = Rect2(Vector2.ZERO, frame_size)
			var flames: TextureRect = TextureRect.new()
			flames.name = "Fire"
			flames.texture = _fire
			flames.mouse_filter = Control.MOUSE_FILTER_IGNORE
			flames.position = fire_position
			flames.size = frame_size
			back.add_child(flames)
	if logo_texture != null and title_label is Label:
		(title_label as Label).text = ""
		title_label.custom_minimum_size = logo_texture.get_size()
		var logo: TextureRect = TextureRect.new()
		logo.name = "Logo"
		logo.texture = logo_texture
		logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
		logo.set_anchors_preset(Control.PRESET_FULL_RECT)
		logo.stretch_mode = TextureRect.STRETCH_KEEP_CENTERED
		title_label.add_child(logo)


func _animate_fire(delta: float) -> void:
	if _fire == null:
		return
	_fire_time += delta
	var frame: int = int(_fire_time * fire_fps) % maxi(fire_frames, 1)
	_fire.region.position.x = frame * _fire.region.size.x


func _process(delta: float) -> void:
	_animate_fire(delta)
	if _title_held_time < 0.0:
		return
	_title_held_time += delta
	if _title_held_time >= debug_hold_time:
		_title_held_time = -1.0
		_toggle_debug_panel()


func _notification(what: int) -> void:
	# The phone's back button: from the loadout to the title, from the title out of the game.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready():
		if loadout_screen.visible:
			_show_loadout(false)
		else:
			get_tree().quit()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug_menu"):
		_toggle_debug_panel()


func _show_loadout(show_loadout: bool) -> void:
	title_screen.visible = not show_loadout
	loadout_screen.visible = show_loadout
	if show_loadout:
		# The series may have been switched in the experiment panel since.
		_refresh_skill_row()


## The basic skills this series offers: the core ones, plus batch 8's with it on.
func get_offered_skills() -> Array[SkillData]:
	var offered: Array[SkillData] = skills.duplicate()
	if GameManager.config.arsenal:
		offered.append_array(arsenal_skills)
	return offered


func _refresh_skill_row() -> void:
	for button: Node in skill_row.get_children():
		skill_row.remove_child(button)
		button.queue_free()
	var current: SkillData = _selected_skill if _selected_skill != null else GameManager.starting_skill
	_selected_skill = _fill_row(skill_row, get_offered_skills(), current, _on_skill_chosen)


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
	if GameManager.config.meta_progression:
		get_tree().change_scene_to_file(CAMP_SCENE)
		return
	GameManager.start_run()
	get_tree().change_scene_to_file(GAME_SCENE)


func _setup_debug_panel() -> void:
	debug_panel.visible = false
	for mode_name: String in GameManager.DirectorMode.keys():
		var mode: int = GameManager.DirectorMode[mode_name]
		# Exploring is for bot simulations only (training data for the learned director).
		if mode != GameManager.DirectorMode.EXPLORE:
			mode_option.add_item(mode_name, mode)
	mode_option.select(mode_option.get_item_index(GameManager.director_mode))
	mode_option.item_selected.connect(_on_mode_selected)
	seed_edit.text = RANDOM_SEED_TEXT if GameManager.forced_seed == GameManager.RANDOM_SEED else str(GameManager.forced_seed)
	seed_edit.text_changed.connect(_on_seed_changed)
	playtest_button.pressed.connect(_on_playtest_pressed)
	export_button.pressed.connect(_on_export_pressed)
	_add_progress_controls()
	status_label.text = ""


## Progress between runs for testing: everything unlocked and bought, or the real save;
## and a button that forgets the save.
func _add_progress_controls() -> void:
	var box: Container = seed_edit.get_parent() as Container
	if box == null:
		return
	var unlock: CheckBox = CheckBox.new()
	unlock.name = "UnlockAll"
	unlock.text = "Everything unlocked (testing)"
	unlock.button_pressed = Progress.unlock_all
	unlock.toggled.connect(func(on: bool) -> void: Progress.unlock_all = on)
	box.add_child(unlock)
	var reset: Button = Button.new()
	reset.name = "ResetProgress"
	reset.text = "Reset progress (shards, skills, spells)"
	reset.pressed.connect(func() -> void:
		Progress.reset()
		status_label.text = "Progress reset.")
	box.add_child(reset)


func _toggle_debug_panel() -> void:
	debug_panel.visible = not debug_panel.visible


func _on_mode_selected(index: int) -> void:
	GameManager.director_mode = mode_option.get_item_id(index) as GameManager.DirectorMode


func _on_playtest_pressed() -> void:
	var text: String = player_id_edit.text.strip_edges()
	if not text.is_valid_int() or text.to_int() < 1:
		status_label.text = "Enter the player's id: a whole number from 1."
		return
	Playtest.start(text.to_int())


func _on_export_pressed() -> void:
	var path: String = Telemetry.export_logs()
	if path.is_empty():
		status_label.text = "No logs to export yet (or nothing could be written)."
	elif path.begins_with("user://"):
		status_label.text = "Downloads could not be written (allow file access and press again). Saved inside the game: %s" \
				% ProjectSettings.globalize_path(path)
	else:
		status_label.text = "Logs saved: %s" % path


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
