class_name PitDecor
extends Node2D
## Visual only: depth for the pits of the Level it sits under. Draws the broken stone
## rim on the side and bottom edges (the top edge is in the pit tile: rim plus a sheer
## wall going down), darkens the pit towards its middle, and lets dust and pebbles fall
## slowly into it, with a rare spark deep down. Collision and falling stay in Level.
## Rebuilds itself whenever the Level gets a new grid.

## Rim colors: lit top-left edge and its shadow.
@export var rim_color: Color = Color("#767a8c")
@export var rim_shadow_color: Color = Color("#2a2935")
## Darkness added per cell of distance from the edge, and its limit.
@export var darkness_step: float = 0.3
@export var darkness_max: float = 0.85
## One dust emitter per this many pit cells; one spark emitter per this many.
@export var cells_per_dust: int = 5
@export var cells_per_spark: int = 14
@export var dust_color: Color = Color("#5d6072")
@export var spark_color: Color = Color("#e09a20")

var _level: Level = null
var _grid: LevelGrid = null
var _pits: Dictionary = {}
var _emitters: Array[Node] = []


func _ready() -> void:
	_level = get_parent() as Level
	# Above the ground tiles, below the actors.
	z_index = 0


func _process(_delta: float) -> void:
	if _level == null or _level.grid == _grid:
		return
	_grid = _level.grid
	_rebuild()


func _rebuild() -> void:
	for node: Node in _emitters:
		node.queue_free()
	_emitters.clear()
	_pits.clear()
	if _grid == null:
		queue_redraw()
		return
	for y in _grid.height:
		for x in _grid.width:
			var cell: Vector2i = Vector2i(x, y)
			if _grid.get_cell(cell) == LevelGrid.Cell.PIT:
				_pits[cell] = 0
	_measure_depth()
	var index: int = 0
	for cell: Vector2i in _pits:
		var roll: int = absi(hash(cell))
		if roll % cells_per_dust == 0:
			_add_emitter(cell, false)
		if int(_pits[cell]) >= 2 and roll % cells_per_spark == 1:
			_add_emitter(cell, true)
		index += 1
	queue_redraw()


## Distance (in cells) of every pit cell from the nearest edge: 1 at the edge.
func _measure_depth() -> void:
	var queue: Array[Vector2i] = []
	for cell: Vector2i in _pits:
		for step: Vector2i in LevelGrid.NEIGHBOURS:
			if not _pits.has(cell + step):
				_pits[cell] = 1
				queue.append(cell)
				break
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for step: Vector2i in LevelGrid.NEIGHBOURS:
			var next: Vector2i = cell + step
			if _pits.has(next) and int(_pits[next]) == 0:
				_pits[next] = int(_pits[cell]) + 1
				queue.append(next)


func _draw() -> void:
	var size: float = float(_level.theme.tile_size) if _level != null else 16.0
	for cell: Vector2i in _pits:
		var origin: Vector2 = Vector2(cell) * size
		var depth: int = int(_pits[cell])
		var shade: float = minf(darkness_max, darkness_step * float(depth - 1))
		if shade > 0.0:
			draw_rect(Rect2(origin, Vector2(size, size)), Color(0, 0, 0, shade))
		var roll: int = absi(hash(cell))
		# Broken rim: a lit lip with a notch where the stone has crumbled.
		if not _pits.has(cell + Vector2i.DOWN):
			draw_rect(Rect2(origin + Vector2(0, size - 2), Vector2(size, 2)), rim_color)
			draw_rect(Rect2(origin + Vector2(roll % 12, size - 2), Vector2(3, 1)), rim_shadow_color)
		if not _pits.has(cell + Vector2i.LEFT):
			draw_rect(Rect2(origin, Vector2(2, size)), rim_color)
			draw_rect(Rect2(origin + Vector2(1, roll % 12), Vector2(1, 3)), rim_shadow_color)
		if not _pits.has(cell + Vector2i.RIGHT):
			draw_rect(Rect2(origin + Vector2(size - 2, 0), Vector2(2, size)), rim_shadow_color)


func _add_emitter(cell: Vector2i, spark: bool) -> void:
	var size: float = float(_level.theme.tile_size)
	var particles: CPUParticles2D = CPUParticles2D.new()
	particles.position = (Vector2(cell) + Vector2(0.5, 0.2)) * size
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(size * 0.5, size * 0.2)
	particles.direction = Vector2.DOWN
	particles.spread = 10.0
	particles.gravity = Vector2.ZERO
	if spark:
		particles.amount = 1
		particles.lifetime = 2.5
		particles.initial_velocity_min = 0.0
		particles.initial_velocity_max = 2.0
		particles.color = spark_color
		particles.preprocess = 2.0
		particles.randomness = 1.0
		particles.explosiveness = 0.0
		particles.scale_amount_min = 1.0
		particles.scale_amount_max = 1.0
		var ramp: Gradient = Gradient.new()
		ramp.set_color(0, Color(spark_color, 0.0))
		ramp.add_point(0.5, spark_color)
		ramp.set_color(ramp.get_point_count() - 1, Color(spark_color, 0.0))
		particles.color_ramp = ramp
	else:
		particles.amount = 2
		particles.lifetime = 3.0
		particles.initial_velocity_min = 2.0
		particles.initial_velocity_max = 5.0
		particles.color = dust_color
		particles.preprocess = 3.0
		var fade: Gradient = Gradient.new()
		fade.set_color(0, dust_color)
		fade.set_color(fade.get_point_count() - 1, Color(dust_color, 0.0))
		particles.color_ramp = fade
	add_child(particles)
	_emitters.append(particles)
