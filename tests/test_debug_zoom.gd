extends TestCase
## Headless test for the debug camera zoom: keys and wheel change the zoom within
## 0.5-2, 0 resets, and the export preset leaves the debug tools out.

const GAME_SCENE: String = "res://main/main.tscn"
const EXPORT_PRESETS: String = "res://export_presets.cfg"


func run() -> void:
	GameManager.start_run(7)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(3)
	var zoom: Node = game.get_node_or_null("DebugCameraZoom")
	var camera: Camera2D = game.player.camera
	check(OS.is_debug_build() and zoom != null, "a debug build gets the debug camera zoom")
	if zoom == null:
		game.queue_free()
		return
	zoom._unhandled_input(_key(KEY_EQUAL))
	check(is_equal_approx(camera.zoom.x, 1.25), "+ zooms in")
	for _i in 10:
		zoom._unhandled_input(_key(KEY_MINUS))
	check(is_equal_approx(camera.zoom.x, 0.5), "- zooms out, not below 0.5")
	for _i in 10:
		zoom._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP))
	check(is_equal_approx(camera.zoom.x, 2.0), "the mouse wheel zooms in, not above 2")
	zoom._unhandled_input(_key(KEY_0))
	check(is_equal_approx(camera.zoom.x, 1.0), "0 resets the zoom")
	var presets: ConfigFile = ConfigFile.new()
	presets.load(EXPORT_PRESETS)
	check(String(presets.get_value("preset.0", "exclude_filter", "")).contains("tools/debug/*"),
			"the export preset leaves tools/debug out")
	game.queue_free()
	await physics_frames(3)


func _key(keycode: Key) -> InputEventKey:
	var event: InputEventKey = InputEventKey.new()
	event.keycode = keycode
	event.pressed = true
	return event


func _wheel(button: MouseButton) -> InputEventMouseButton:
	var event: InputEventMouseButton = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	return event
