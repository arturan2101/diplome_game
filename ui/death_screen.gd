class_name DeathScreen
extends CanvasLayer
## Shown when the run ends: the results of the run and the way back to the menu
## or straight into a new run with the same loadout.

const MENU_SCENE: String = "res://ui/main_menu.tscn"

@export var panel: Control
@export var stats_label: Label
@export var again_button: Button
@export var menu_button: Button

## False during a playtest block: the player only starts a new run.
var menu_enabled: bool = true


func _ready() -> void:
	panel.visible = false
	again_button.pressed.connect(_on_again_pressed)
	menu_button.pressed.connect(_on_menu_pressed)


## Shows the results. summary comes from GameManager.get_run_summary().
func show_summary(summary: Dictionary) -> void:
	var seconds: int = int(summary["time"])
	stats_label.text = "Depth reached: %d\nSections cleared: %d\nTime: %d:%02d\nEnemies defeated: %d\nCoins: %d" % [
			int(summary["depth"]) + 1, summary["sections"], seconds / 60, seconds % 60, summary["kills"], summary["coins"]]
	menu_button.visible = menu_enabled
	panel.visible = true
	again_button.grab_focus()


func _notification(what: int) -> void:
	# The phone's back button on the results screen leads to the menu.
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_node_ready() and panel.visible and menu_enabled:
		_on_menu_pressed()


func _on_again_pressed() -> void:
	GameManager.restart_run()


func _on_menu_pressed() -> void:
	get_tree().change_scene_to_file(MENU_SCENE)
