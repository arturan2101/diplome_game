class_name PauseMenu
extends CanvasLayer
## Pause during a run: opened by the pause action (Esc, the phone's back button) or
## by the pause button of the HUD. It keeps working while the tree is paused
## (process mode "Always"), everything else stops, including telemetry time.

const MENU_SCENE: String = "res://ui/main_menu.tscn"

@export var panel: Control
@export var resume_button: Button
@export var menu_button: Button


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	resume_button.pressed.connect(set_paused.bind(false))
	menu_button.pressed.connect(_on_menu_pressed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		toggle()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	set_paused(not get_tree().paused)


func set_paused(paused: bool) -> void:
	# No pausing on the death screen.
	if paused and GameManager.is_run_over:
		return
	get_tree().paused = paused
	panel.visible = paused
	if paused:
		resume_button.grab_focus()


func _on_menu_pressed() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file(MENU_SCENE)
