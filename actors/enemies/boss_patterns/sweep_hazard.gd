class_name SweepHazard
extends BossHazard
## Arms sweeping round a centre (stage 50): the warning shows each arm where it starts
## and a faint copy a little ahead in the way it will turn; then the arms (vines) turn
## at turn_speed for spin_time, hurting whatever they touch, and pull back. Each arm
## reaches max_length or the first wall. The safe floor is the wedge between two arms,
## and it moves: the player has to walk round with it.
## A hit pushes the target ahead of the arm.

## Radians ahead of an arm its faint warning is drawn, showing where it turns.
const LEAD_ANGLE: float = 0.25
## Seconds the arms take to pull back at the end (harmless).
const RETRACT_TIME: float = 0.3

var arms: int = 2
var start_angle: float = 0.0
## Radians per second; negative turns the other way.
var turn_speed: float = 0.7
var spin_time: float = 4.0
var max_length: float = 220.0
var half_width: float = 6.0


func is_finished() -> bool:
	return time_to_strike() < -(spin_time + RETRACT_TIME)


func is_spinning() -> bool:
	var since: float = -time_to_strike()
	return since >= 0.0 and since <= spin_time


## Angle of arm index now (it stands at its start before the spin).
func arm_angle(index: int) -> float:
	return arm_angle_at(index, 0.0)


## Angle of arm index at a time from now.
func arm_angle_at(index: int, time: float) -> float:
	var turned: float = clampf(-time_to_strike() + time, 0.0, spin_time) * turn_speed
	return start_angle + TAU * index / maxi(arms, 1) + turned


func threatens(point: Vector2, margin: float, from_time: float, to_time: float) -> bool:
	var spin_start: float = time_to_strike()
	var first: float = maxf(from_time, spin_start)
	var last: float = minf(to_time, spin_start + spin_time)
	if last < first:
		return false
	var offset: Vector2 = point - global_position
	var r: float = offset.length()
	if r > max_length + margin:
		return false
	var spread: float = PI if r <= half_width + margin else asin((half_width + margin) / r)
	var angle: float = offset.angle()
	for i in maxi(arms, 1):
		var a: float = arm_angle_at(i, first)
		var b: float = arm_angle_at(i, last)
		var low: float = minf(a, b) - spread
		var span: float = absf(b - a) + spread * 2.0
		if span >= TAU or fposmod(angle - low, TAU) <= span:
			return true
	return false


func _update(_delta: float) -> void:
	if not is_spinning():
		return
	for i in maxi(arms, 1):
		var angle: float = arm_angle(i)
		var push: Vector2 = Vector2.from_angle(angle + signf(turn_speed) * PI * 0.5)
		for hurtbox: Hurtbox in _hurtboxes_in_band(global_position, angle, _reach(global_position, angle, max_length), half_width):
			_hit(hurtbox, push)


func _draw() -> void:
	if age < start_delay:
		return
	var since: float = -time_to_strike()
	var band: float = half_width * 2.0 + 2.0
	var warn_frame: int = BossHazard.frame_at(age, pattern.warn_fps, pattern.warn_frames)
	var shrink: float = 1.0 - clampf((since - spin_time) / RETRACT_TIME, 0.0, 1.0)
	for i in maxi(arms, 1):
		var angle: float = arm_angle(i)
		var reach: float = _reach(global_position, angle, max_length)
		var ahead: float = angle + signf(turn_speed) * LEAD_ANGLE
		if since <= spin_time:
			# Where it turns next: faint, a little ahead.
			draw_set_transform(Vector2.ZERO, ahead, Vector2.ONE)
			_draw_band(pattern.warn_texture, pattern.warn_frames, warn_frame, 0.0,
					_reach(global_position, ahead, max_length), band, pattern.warn_color, 0.3)
		draw_set_transform(Vector2.ZERO, angle, Vector2.ONE)
		if since < 0.0:
			var t: float = 1.0 - (-since) / maxf(pattern.warn_time, 0.001)
			_draw_band(pattern.warn_texture, pattern.warn_frames, warn_frame, 0.0, reach, band, pattern.warn_color,
					lerpf(0.5, 1.0, t))
		else:
			_draw_strike(reach * shrink, BossHazard.frame_at(since, pattern.strike_fps, pattern.strike_frames))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
