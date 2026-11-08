class_name TouchJoystick
extends Control
## Floating virtual joystick. Place it over the left half of the screen.
## A touch inside this control moves the joystick under the finger; dragging presses
## the move_* Input Map actions with analog strength, so the player script does not
## know whether input comes from the keyboard or from touch.
## The deadzone comes from the Input Map actions, not from this script.

## Distance in pixels from the base centre at which the knob gives full strength.
@export var radius: float = 48.0
## Radius of the knob circle in pixels.
@export var knob_radius: float = 18.0
## Where the idle joystick is drawn, in this control's local coordinates.
## A future "fixed joystick" option would keep the base here instead of moving it.
@export var rest_position: Vector2 = Vector2(96.0, 256.0)
@export var base_color: Color = Color(1.0, 1.0, 1.0, 0.2)
@export var knob_color: Color = Color(1.0, 1.0, 1.0, 0.5)

## Index of the finger that controls the joystick, -1 when not touched.
## Following one finger lets other fingers press buttons at the same time.
var _touch_index: int = -1
var _base_center: Vector2 = Vector2.ZERO
var _knob_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Touches are read in _input, so this control must not block mouse/GUI events.
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_base_center = rest_position


func _input(event: InputEvent) -> void:
	if not (event is InputEventScreenTouch or event is InputEventScreenDrag):
		return
	var local_event: InputEvent = make_input_local(event)
	if local_event is InputEventScreenTouch:
		_on_touch(local_event as InputEventScreenTouch)
	else:
		_on_drag(local_event as InputEventScreenDrag)


func _notification(what: int) -> void:
	# A finger can be lost without a release event (app minimised, scene changed).
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_EXIT_TREE:
		_end_touch()


func _draw() -> void:
	draw_circle(_base_center, radius, base_color)
	draw_circle(_base_center + _knob_offset, knob_radius, knob_color)


func _on_touch(event: InputEventScreenTouch) -> void:
	if event.pressed:
		if _touch_index != -1 or not Rect2(Vector2.ZERO, size).has_point(event.position):
			return
		_touch_index = event.index
		# Keep the whole base on screen when the finger lands near an edge.
		_base_center = event.position.clamp(Vector2(radius, radius), size - Vector2(radius, radius))
		_move_knob(event.position)
		get_viewport().set_input_as_handled()
	elif event.index == _touch_index:
		_end_touch()
		get_viewport().set_input_as_handled()


func _on_drag(event: InputEventScreenDrag) -> void:
	if event.index != _touch_index:
		return
	_move_knob(event.position)
	get_viewport().set_input_as_handled()


func _move_knob(finger_position: Vector2) -> void:
	_knob_offset = (finger_position - _base_center).limit_length(radius)
	var direction: Vector2 = _knob_offset / radius
	_press_axis("move_left", "move_right", direction.x)
	_press_axis("move_up", "move_down", direction.y)
	queue_redraw()


func _end_touch() -> void:
	if _touch_index == -1:
		return
	_touch_index = -1
	_base_center = rest_position
	_knob_offset = Vector2.ZERO
	_press_axis("move_left", "move_right", 0.0)
	_press_axis("move_up", "move_down", 0.0)
	queue_redraw()


## Presses one action of an axis with the given strength (0..1) and releases the other.
func _press_axis(negative_action: StringName, positive_action: StringName, value: float) -> void:
	if value < 0.0:
		Input.action_press(negative_action, -value)
		Input.action_release(positive_action)
	elif value > 0.0:
		Input.action_press(positive_action, value)
		Input.action_release(negative_action)
	else:
		Input.action_release(negative_action)
		Input.action_release(positive_action)
