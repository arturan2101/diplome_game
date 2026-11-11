class_name DeathScreen
extends CanvasLayer
## Shown when the run ends: the results of the run and the way back to the menu
## or straight into a new run with the same loadout.

const MENU_SCENE: String = "res://ui/main_menu.tscn"

@export var panel: Control
@export var stats_label: Label
@export var again_button: Button
@export var menu_button: Button


func _ready() -> void:
	panel.visible = false
	again_button.pressed.connect(_on_again_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


## Shows the results. summary comes from GameManager.get_run_summary().
func show_summary(summary: Dictionary) -> void:
	var seconds: int = int(summary["time"])
	stats_label.text = "Depth reached: %d\nSections cleared: %d\nTime: %d:%02d\nEnemies defeated: %d\nCoins: %d" % [
			int(summary["depth"]) + 1, summary["sections"], seconds / 60, seconds % 60, summary["kills"], summary["coins"]]
	panel.visible = true
	again_button.grab_focus()


func _on_again_pressed() -> void:
	GameManager.restart_run()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
