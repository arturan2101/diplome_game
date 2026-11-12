extends Node
## Debug-only camera zoom for looking at a whole section while playing on a PC.
## + / - (main keyboard or keypad) and the mouse wheel zoom from 0.5 to 2, 0 resets.
## The game adds this node only in debug builds, and the export preset leaves the
## tools/debug folder out, so it never reaches a player.

@export var min_zoom: float = 0.5
@export var max_zoom: float = 2.0
## Each key press or wheel notch multiplies the zoom by this.
@export var zoom_step: float = 1.25

const ZOOM_IN_KEYS: Array[Key] = [KEY_EQUAL, KEY_PLUS, KEY_KP_ADD]
const ZOOM_OUT_KEYS: Array[Key] = [KEY_MINUS, KEY_KP_SUBTRACT]
const RESET_KEYS: Array[Key] = [KEY_0, KEY_KP_0]


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo:
		if key.keycode in ZOOM_IN_KEYS:
			_zoom_by(zoom_step)
		elif key.keycode in ZOOM_OUT_KEYS:
			_zoom_by(1.0 / zoom_step)
		elif key.keycode in RESET_KEYS:
			_set_zoom(1.0)
		return
	var button: InputEventMouseButton = event as InputEventMouseButton
	if button != null and button.pressed:
		if button.button_index == MOUSE_BUTTON_WHEEL_UP:
			_zoom_by(zoom_step)
		elif button.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_zoom_by(1.0 / zoom_step)


func _zoom_by(factor: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		_set_zoom(camera.zoom.x * factor)


func _set_zoom(value: float) -> void:
	var camera: Camera2D = get_viewport().get_camera_2d()
	if camera != null:
		var zoom: float = clampf(value, min_zoom, max_zoom)
		camera.zoom = Vector2(zoom, zoom)
