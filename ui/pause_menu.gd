class_name PauseMenu
extends CanvasLayer
## Pause during a run: opened by the pause action (Esc, the phone's back button) or
## by the pause button of the HUD. It keeps working while the tree is paused
## (process mode "Always"), everything else stops, including telemetry time.

const MENU_SCENE: String = "res://ui/main_menu.tscn"

@export var panel: Control
@export var resume_button: Button
@export var menu_button: Button

var _music_button: Button = null
var _sounds_button: Button = null


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	resume_button.pressed.connect(set_paused.bind(false))
	menu_button.pressed.connect(_on_menu_pressed)
	_add_sound_buttons()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	# The phone's back button pauses instead of closing the game.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		toggle()


func toggle() -> void:
	# Paused by another screen (the spell choice): that screen decides when to resume.
	if get_tree().paused and not panel.visible:
		return
	set_paused(not get_tree().paused)


func set_paused(paused: bool) -> void:
	# No pausing on the death screen.
	if paused and GameManager.is_run_over:
		return
	if paused != panel.visible:
		Sound.play(&"ui_open" if paused else &"ui_close")
	get_tree().paused = paused
	panel.visible = paused
	if paused:
		resume_button.grab_focus()


## Music and sounds on / off (stage 46), between Resume and Menu; made in code so the
## scene keeps its two buttons.
func _add_sound_buttons() -> void:
	var box: Node = menu_button.get_parent()
	_music_button = Button.new()
	_sounds_button = Button.new()
	for button: Button in [_music_button, _sounds_button]:
		button.custom_minimum_size = resume_button.custom_minimum_size
		box.add_child(button)
		box.move_child(button, menu_button.get_index())
	_music_button.pressed.connect(func() -> void:
		Sound.set_music_on(not Sound.music_on)
		_update_sound_buttons())
	_sounds_button.pressed.connect(func() -> void:
		Sound.set_sounds_on(not Sound.sounds_on)
		_update_sound_buttons())
	_update_sound_buttons()


func _update_sound_buttons() -> void:
	_music_button.text = "Music: %s" % ("on" if Sound.music_on else "off")
	_sounds_button.text = "Sounds: %s" % ("on" if Sound.sounds_on else "off")


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
