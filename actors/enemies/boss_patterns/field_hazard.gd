class_name FieldHazard
extends BossHazard
## Floor cells that light up and burst (stage 50), in waves: wave w warns from the moment
## wave w-1 bursts, for the pattern's warn_time. A burst hurts a target whose centre
## stands on one of its cells, during active_time; its art plays for burst_time.
## Everything is drawn by this one node (a field can have a hundred cells).

var active_time: float = 0.15
var burst_time: float = 0.4
## Per wave: the lit cells (cell -> true) and their top-left corners in local pixels.
var _waves: Array[Dictionary] = []
var _corners: Array[PackedVector2Array] = []
var _tile: float = 16.0
var _level: Level = null
## Waves whose burst has been dealt.
var _struck: int = 0


func add_wave(cells: Array[Vector2i]) -> void:
	var lit: Dictionary = {}
	for cell: Vector2i in cells:
		lit[cell] = true
	_waves.append(lit)


func wave_count() -> int:
	return _waves.size()


func is_lit(wave: int, cell: Vector2i) -> bool:
	return wave >= 0 and wave < _waves.size() and _waves[wave].has(cell)


## Seconds from now until wave w bursts.
func wave_strike(wave: int) -> float:
	return start_delay + pattern.warn_time * (wave + 1) - age


## Fixes the cells' corners once the field stands in the level.
func set_cells_from(level: Level) -> void:
	_level = level
	_tile = float(level.theme.tile_size)
	_corners.clear()
	for lit: Dictionary in _waves:
		var corners: PackedVector2Array = PackedVector2Array()
		for cell: Vector2i in lit:
			corners.append(to_local(level.cell_center(cell)) - Vector2.ONE * _tile * 0.5)
		_corners.append(corners)


func is_finished() -> bool:
	return _waves.is_empty() or wave_strike(_waves.size() - 1) < -maxf(burst_time, active_time)


func threatens(point: Vector2, margin: float, from_time: float, to_time: float) -> bool:
	if _level == null:
		return false
	var cells: Array[Vector2i] = []
	for corner: Vector2 in [Vector2(-margin, -margin), Vector2(margin, -margin), Vector2(-margin, margin), Vector2(margin, margin)]:
		var cell: Vector2i = _level.cell_at(point + corner)
		if not cell in cells:
			cells.append(cell)
	for wave in _waves.size():
		var strike: float = wave_strike(wave)
		if to_time < strike or from_time > strike + active_time:
			continue
		for cell: Vector2i in cells:
			if _waves[wave].has(cell):
				return true
	return false


func _update(_delta: float) -> void:
	if _level == null:
		return
	for wave in _waves.size():
		var since: float = -wave_strike(wave)
		if since < 0.0 or since > active_time:
			continue
		if wave >= _struck:
			_struck = wave + 1
			if wave > 0:
				Sound.play_at(pattern.strike_sound, global_position)
		for hurtbox: Hurtbox in AreaDamage.targets(get_world_2d().direct_space_state, global_position,
				_reach_radius(), target_mask, 0):
			if _waves[wave].has(_level.cell_at(hurtbox.global_position)):
				_hit(hurtbox, Vector2.ZERO)


## A circle that holds every cell of the field.
func _reach_radius() -> float:
	var far: float = 0.0
	for corners: PackedVector2Array in _corners:
		for corner: Vector2 in corners:
			far = maxf(far, (corner + Vector2.ONE * _tile * 0.5).length())
	return far + _tile


func _draw() -> void:
	for wave in _corners.size():
		var strike: float = wave_strike(wave)
		if strike > pattern.warn_time or -strike > burst_time:
			continue
		var warning: bool = strike > 0.0
		var texture: Texture2D = pattern.warn_texture if warning else pattern.strike_texture
		var frames: int = pattern.warn_frames if warning else pattern.strike_frames
		# Both play once and hold their last frame: the warning over its whole time.
		var progress: float = 1.0 - strike / maxf(pattern.warn_time, 0.001) if warning else -strike / maxf(burst_time, 0.001)
		var frame: int = clampi(int(progress * frames), 0, maxi(frames, 1) - 1)
		var color: Color = pattern.warn_color if warning else pattern.strike_color
		var alpha: float = lerpf(0.5, 1.0, progress) if warning else 1.0 - progress * 0.5
		var field: FieldPattern = pattern as FieldPattern
		var fill: bool = warning and texture != null and field != null and field.fill_warning
		for corner: Vector2 in _corners[wave]:
			var rect: Rect2 = Rect2(corner, Vector2.ONE * _tile)
			if fill:
				draw_rect(rect.grow(-1.0), Color(color, color.a * alpha))
			if texture == null:
				draw_rect(rect.grow(-1.0), Color(color, color.a * alpha))
			else:
				var size: float = float(texture.get_height())
				draw_texture_rect_region(texture, rect, Rect2(frame * size, 0.0, size, size), Color(1.0, 1.0, 1.0, alpha))
