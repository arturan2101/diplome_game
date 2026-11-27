class_name LineHazard
extends BossHazard
## One straight lash (stage 50): from its position along its rotation, length long (cut
## at the first wall when placed), half_width to each side. First a glowing crack shows
## the whole band; then the vine shoots out along it (extend_time), lies there hurting
## whoever touches it (hold_time) and pulls back (retract_time, harmless).
## A hit pushes the target sideways, out of the band.

var length: float = 0.0
var half_width: float = 7.0
var extend_time: float = 0.12
var hold_time: float = 0.35
var retract_time: float = 0.2


## A lash from a world point along an angle; its length stops at the first wall.
static func make(from_pattern: BossPattern, host: Node, from: Vector2, angle: float, max_length: float,
		width: float, hit: int, by: Node, id: StringName, mask: int, delay: float) -> LineHazard:
	var line: LineHazard = LineHazard.new()
	line.setup(from_pattern, hit, by, id, mask, delay)
	line.half_width = width
	line.rotation = angle
	BossHazard.place(line, host, from)
	line.length = line._reach(from, angle, max_length)
	return line


func is_finished() -> bool:
	return time_to_strike() < -(extend_time + hold_time + retract_time)


## Hurts from the strike until the vine starts to pull back.
func threatens(point: Vector2, margin: float, from_time: float, to_time: float) -> bool:
	var strike: float = time_to_strike()
	if to_time < strike or from_time > strike + extend_time + hold_time:
		return false
	var local: Vector2 = (point - global_position).rotated(-rotation)
	return local.x >= -margin and local.x <= length + margin and absf(local.y) <= half_width + margin


## How far the vine reaches now (0 before the strike).
func reach_now() -> float:
	var since: float = -time_to_strike()
	if since < 0.0:
		return 0.0
	if since < extend_time:
		return length * since / maxf(extend_time, 0.001)
	if since < extend_time + hold_time:
		return length
	return length * clampf(1.0 - (since - extend_time - hold_time) / maxf(retract_time, 0.001), 0.0, 1.0)


func _update(_delta: float) -> void:
	var since: float = -time_to_strike()
	if since < 0.0 or since > extend_time + hold_time:
		return
	var push: Vector2 = Vector2.from_angle(rotation).orthogonal()
	for hurtbox: Hurtbox in _hurtboxes_in_band(global_position, rotation, reach_now(), half_width):
		var side: float = signf((hurtbox.global_position - global_position).dot(push))
		_hit(hurtbox, push * (side if side != 0.0 else 1.0))


func _draw() -> void:
	if age < start_delay:
		return
	var strike: float = time_to_strike()
	var band: float = half_width * 2.0 + 2.0
	if strike > 0.0:
		# The warning brightens as the strike nears, flickering at the end.
		var t: float = 1.0 - strike / maxf(pattern.warn_time, 0.001)
		var alpha: float = lerpf(0.45, 1.0, t) * (0.75 if strike < 0.2 and int(age * 20.0) % 2 == 0 else 1.0)
		_draw_band(pattern.warn_texture, pattern.warn_frames, BossHazard.frame_at(age, pattern.warn_fps, pattern.warn_frames),
				0.0, length, band, pattern.warn_color, alpha)
		return
	_draw_strike(reach_now(), BossHazard.frame_at(-strike, pattern.strike_fps, pattern.strike_frames))
