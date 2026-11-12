extends TestCase
## Headless test for the touch controls of the HUD with synthetic touches: the floating
## joystick, the action buttons, several fingers at once, and letting go on pause.
## Real feel on a phone still has to be checked by hand (see docs/android-build.md).

const HUD_SCENE: String = "res://ui/hud.tscn"
const JOYSTICK_TOUCH: Vector2 = Vector2(100.0, 250.0)
const LEFT_FINGER: int = 0
const RIGHT_FINGER: int = 1


func run() -> void:
	var hud: Hud = (load(HUD_SCENE) as PackedScene).instantiate() as Hud
	add_child(hud)
	await physics_frames(2)
	var attack_button: TouchScreenButton = hud.get_node("AttackButton") as TouchScreenButton
	var skill_button: TouchScreenButton = hud.get_node("SkillButton") as TouchScreenButton
	var swap_button: TouchScreenButton = hud.get_node("SwapButton") as TouchScreenButton
	var pause_button: TouchScreenButton = hud.get_node("PauseButton") as TouchScreenButton
	check(attack_button.action == "attack" and skill_button.action == "skill" and swap_button.action == "swap_weapon"
			and pause_button.action == "pause", "each touch button presses its Input Map action")

	# Left thumb on the joystick, dragged right.
	await _touch(LEFT_FINGER, JOYSTICK_TOUCH, true)
	await _drag(LEFT_FINGER, JOYSTICK_TOUCH + Vector2(60.0, 0.0))
	check(_move_vector().x > 0.9 and absf(_move_vector().y) < 0.1, "dragging the joystick right moves right at full strength")

	# Right thumb presses attack while the left one keeps the joystick.
	await _touch(RIGHT_FINGER, attack_button.global_position, true)
	check(Input.is_action_pressed("attack") and _move_vector().x > 0.9, "attack and joystick work with two fingers at once")
	await _drag(LEFT_FINGER, JOYSTICK_TOUCH + Vector2(0.0, -60.0))
	check(_move_vector().y < -0.9 and Input.is_action_pressed("attack"), "the joystick follows its own finger while attack is held")
	await _touch(RIGHT_FINGER, attack_button.global_position, false)
	check(not Input.is_action_pressed("attack") and _move_vector().y < -0.9, "releasing attack keeps the joystick")

	await _touch(RIGHT_FINGER, skill_button.global_position, true)
	check(Input.is_action_pressed("skill"), "the skill button presses the skill action")
	await _touch(RIGHT_FINGER, skill_button.global_position, false)

	await _touch(LEFT_FINGER, JOYSTICK_TOUCH, false)
	check(_move_vector().is_zero_approx(), "lifting the finger stops the movement")

	# Pausing with a finger on the joystick must not leave the player walking.
	await _touch(LEFT_FINGER, JOYSTICK_TOUCH, true)
	await _drag(LEFT_FINGER, JOYSTICK_TOUCH + Vector2(60.0, 0.0))
	get_tree().paused = true
	await get_tree().process_frame
	var released_on_pause: bool = _move_vector().is_zero_approx()
	get_tree().paused = false
	await get_tree().process_frame
	check(released_on_pause, "pausing releases the joystick")
	await _touch(LEFT_FINGER, JOYSTICK_TOUCH, false)
	hud.queue_free()
	await physics_frames(2)


func _move_vector() -> Vector2:
	return Input.get_vector("move_left", "move_right", "move_up", "move_down")


func _touch(finger: int, at: Vector2, pressed: bool) -> void:
	var event: InputEventScreenTouch = InputEventScreenTouch.new()
	event.index = finger
	event.position = at
	event.pressed = pressed
	# Positions are already in game (viewport) coordinates: skip the window transform.
	get_viewport().push_input(event, true)
	await physics_frames(2)


func _drag(finger: int, to: Vector2) -> void:
	var event: InputEventScreenDrag = InputEventScreenDrag.new()
	event.index = finger
	event.position = to
	# Positions are already in game (viewport) coordinates: skip the window transform.
	get_viewport().push_input(event, true)
	await physics_frames(2)
