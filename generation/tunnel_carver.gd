class_name TunnelCarver
extends RefCounted
## Digs tunnels between rooms of a section grid.
## carve(): a "drunkard's walk" that drifts towards the target and wanders sideways
## according to twist, digging a square brush of the corridor width. It never digs
## inside rooms. If the walk does not arrive in time, the rest is dug along the
## shortest free path, so a tunnel always connects its two ends.
## smooth(): a few steps of a cellular automaton that round off the jagged walls,
## so tunnels look like caved-in passages. The centre line of every tunnel is kept.

## Walk steps allowed per tile of straight distance before the fallback kicks in.
const STEPS_PER_TILE: int = 8
const EXTRA_STEPS: int = 40
const SMOOTH_PASSES: int = 2
## A wall cell with at least this many floor cells around it (of 8) becomes floor.
const OPEN_WALL_AT: int = 5
## A floor cell with at most this many floor cells around it becomes wall (dead-end spur).
const CLOSE_FLOOR_AT: int = 1
const AROUND: Array[Vector2i] = [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(-1, 0),
	Vector2i(1, 0), Vector2i(-1, 1), Vector2i(0, 1), Vector2i(1, 1),
]

var _grid: LevelGrid = null
var _room_rects: Array[Rect2i] = []
## Cells the carver may dig: everything except the outermost ring of the grid.
var _diggable: Rect2i = Rect2i()
## Centre-line cells of all tunnels (a set). Smoothing never closes them.
var _backbone: Dictionary = {}


func _init(grid: LevelGrid, room_rects: Array[Rect2i]) -> void:
	_grid = grid
	_room_rects = room_rects
	_diggable = Rect2i(1, 1, grid.width - 2, grid.height - 2)


## Digs a tunnel from one cell to another. Both must lie outside the rooms.
func carve(from: Vector2i, to: Vector2i, width: int, twist: float, rng: RandomNumberGenerator) -> void:
	var cell: Vector2i = from
	_dig(cell, width)
	var steps_left: int = (absi(to.x - from.x) + absi(to.y - from.y)) * STEPS_PER_TILE + EXTRA_STEPS
	while cell != to and steps_left > 0:
		steps_left -= 1
		var next: Vector2i = cell + _pick_step(cell, to, twist, rng)
		if not _can_dig(next):
			continue
		cell = next
		_dig(cell, width)
	if cell != to:
		for path_cell: Vector2i in _shortest_path(cell, to):
			_dig(path_cell, width)


## Rounds off tunnel walls. Rooms are not touched.
func smooth() -> void:
	for _pass in SMOOTH_PASSES:
		var to_floor: Array[Vector2i] = []
		var to_wall: Array[Vector2i] = []
		for y in range(_diggable.position.y, _diggable.end.y):
			for x in range(_diggable.position.x, _diggable.end.x):
				var cell: Vector2i = Vector2i(x, y)
				if _in_room(cell):
					continue
				var floor_around: int = _count_floor_around(cell)
				if _grid.get_cell(cell) == LevelGrid.Cell.WALL and floor_around >= OPEN_WALL_AT:
					to_floor.append(cell)
				elif _grid.is_floor(cell) and floor_around <= CLOSE_FLOOR_AT and not _backbone.has(cell):
					to_wall.append(cell)
		for cell: Vector2i in to_floor:
			_grid.set_cell(cell, LevelGrid.Cell.FLOOR)
		for cell: Vector2i in to_wall:
			_grid.set_cell(cell, LevelGrid.Cell.WALL)


## One step of the walk: mostly towards the target, sometimes anywhere.
func _pick_step(cell: Vector2i, to: Vector2i, twist: float, rng: RandomNumberGenerator) -> Vector2i:
	if rng.randf() < twist:
		return LevelGrid.NEIGHBOURS[rng.randi_range(0, LevelGrid.NEIGHBOURS.size() - 1)]
	var delta: Vector2i = to - cell
	var horizontal: Vector2i = Vector2i(signi(delta.x), 0)
	var vertical: Vector2i = Vector2i(0, signi(delta.y))
	if delta.x == 0:
		return vertical
	if delta.y == 0:
		return horizontal
	# Both axes left: pick one in proportion to the distance along it.
	var total: int = absi(delta.x) + absi(delta.y)
	return horizontal if rng.randi_range(1, total) <= absi(delta.x) else vertical


func _dig(center: Vector2i, width: int) -> void:
	_backbone[center] = true
	var first: int = -((width - 1) / 2)
	for dy in range(first, first + width):
		for dx in range(first, first + width):
			var cell: Vector2i = center + Vector2i(dx, dy)
			if _can_dig(cell):
				_grid.set_cell(cell, LevelGrid.Cell.FLOOR)


func _can_dig(cell: Vector2i) -> bool:
	return _diggable.has_point(cell) and not _in_room(cell)


func _in_room(cell: Vector2i) -> bool:
	for rect: Rect2i in _room_rects:
		if rect.has_point(cell):
			return true
	return false


func _count_floor_around(cell: Vector2i) -> int:
	var count: int = 0
	for offset: Vector2i in AROUND:
		if _grid.is_floor(cell + offset):
			count += 1
	return count


## Breadth-first search over diggable cells; the path excludes the start cell.
func _shortest_path(from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var came_from: Dictionary = {from: from}
	var queue: Array[Vector2i] = [from]
	var head: int = 0
	while head < queue.size() and not came_from.has(to):
		var cell: Vector2i = queue[head]
		head += 1
		for step: Vector2i in LevelGrid.NEIGHBOURS:
			var next: Vector2i = cell + step
			if _can_dig(next) and not came_from.has(next):
				came_from[next] = cell
				queue.append(next)
	var path: Array[Vector2i] = []
	if not came_from.has(to):
		return path
	var cell: Vector2i = to
	while cell != from:
		path.append(cell)
		cell = came_from[cell]
	path.reverse()
	return path
