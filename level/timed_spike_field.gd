class_name TimedSpikeField
extends Node2D
## The timed spikes of a Level: one animated sprite per cell, shown in the phase the
## section clock gives (no animation clock of its own, so the picture always matches
## the damage), and the answers to "do these spikes hurt now" and "do they stay down
## for a while". The Level rebuilds it with every grid.

## Cycle and look of the timed spikes (HazardData.timed_spikes).
var data: SpikeTrapData = null

## Cell -> phase shift in seconds (LevelGrid.spike_phase).
var _shifts: Dictionary = {}
## Cell -> AnimatedSprite2D.
var _sprites: Dictionary = {}


## Takes the timed spike cells of a grid; sprites only if the data has frames.
func rebuild(grid: LevelGrid, trap: SpikeTrapData, tile_size: int) -> void:
	data = trap
	for sprite: Node in _sprites.values():
		sprite.queue_free()
	_sprites.clear()
	_shifts.clear()
	if data == null:
		return
	for cell: Vector2i in grid.spike_phase:
		if grid.get_cell(cell) != LevelGrid.Cell.SPIKES_TIMED:
			continue
		_shifts[cell] = float(grid.spike_phase[cell])
		if data.frames == null:
			continue
		var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
		sprite.sprite_frames = data.frames
		sprite.position = (Vector2(cell) + Vector2(0.5, 0.5)) * float(tile_size)
		add_child(sprite)
		_sprites[cell] = sprite


func has_cell(cell: Vector2i) -> bool:
	return _shifts.has(cell)


func get_cells() -> Array:
	return _shifts.keys()


## True if the spikes on that cell hurt at that section time.
func is_up(cell: Vector2i, section_time: float) -> bool:
	return has_cell(cell) and data.is_up_at(section_time + float(_shifts[cell]))


## True if the spikes on that cell stay harmless from one section time to another.
func is_down_during(cell: Vector2i, from: float, to: float) -> bool:
	if not has_cell(cell):
		return true
	var shift: float = float(_shifts[cell])
	return data.is_down_during(from + shift, to + shift)


## Phase of that cell at that section time (for tests and debugging).
func phase_of(cell: Vector2i, section_time: float) -> StringName:
	return data.phase_at(section_time + float(_shifts[cell])) if has_cell(cell) else &""


## Shows every sprite in the phase of the given section time.
func update_look(section_time: float) -> void:
	for cell: Vector2i in _sprites:
		var sprite: AnimatedSprite2D = _sprites[cell]
		var time: float = section_time + float(_shifts[cell])
		var phase: StringName = data.phase_at(time)
		if not sprite.sprite_frames.has_animation(phase):
			continue
		if sprite.animation != phase:
			sprite.animation = phase
		var count: int = sprite.sprite_frames.get_frame_count(phase)
		sprite.frame = clampi(floori(data.phase_progress_at(time) * count), 0, count - 1)
