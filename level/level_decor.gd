class_name LevelDecor
extends Node2D
## Visual only, no collision: small things on the floor (bones, rubble, grass in the
## cracks) and torches on the brick fronts of walls, with an animated flame and no
## light. Placed from the cell coordinates, so the same grid always looks the same.
## Sits under a Level and rebuilds itself when the Level gets a new grid.

## Share of plain floor cells with a decor piece, and of brick wall fronts with a torch.
@export_range(0.0, 1.0) var floor_decor_chance: float = 0.06
@export_range(0.0, 1.0) var torch_chance: float = 0.08
## Flame frames per second.
@export var flame_fps: float = 8.0

const BONE: Color = Color("#d8d4c4")
const BONE_SHADOW: Color = Color("#9aa2ad")
const RUBBLE: Color = Color("#5d6072")
const RUBBLE_SHADOW: Color = Color("#2a2935")
const GRASS: Color = Color("#3b5a45")
const GRASS_DARK: Color = Color("#263a32")
const WOOD: Color = Color("#7a4a2c")
const FLAME: Array[Color] = [Color("#a82a30"), Color("#e85a3a"), Color("#e09a20"), Color("#ffd860")]
## Pixel pictures: (dx, dy, color index) with 0 light, 1 dark.
const PIECES: Array = [
	[[5, 9, 0], [6, 9, 0], [7, 9, 0], [8, 9, 0], [4, 8, 0], [9, 10, 0], [5, 10, 1], [8, 10, 1]],
	[[6, 7, 0], [7, 7, 0], [6, 8, 0], [7, 8, 1], [10, 11, 0], [11, 11, 1], [3, 12, 0]],
	[[7, 10, 0], [6, 9, 0], [9, 9, 0], [8, 8, 0], [7, 11, 1], [9, 11, 1]],
]

var _level: Level = null
var _grid: LevelGrid = null
## {cell: piece index} with the kind in the high bits: 0 bones, 1 rubble, 2 grass.
var _floor: Dictionary = {}
var _torches: Array[Vector2i] = []
var _time: float = 0.0


func _ready() -> void:
	_level = get_parent() as Level
	_place_above_tiles.call_deferred()


## Drawn right above the floor tiles: after the Level's Props layer, before the
## section contents (pickups, enemies) that the Level adds later.
func _place_above_tiles() -> void:
	var props: Node = _level.get_node_or_null("Props") if _level != null else null
	if props != null:
		_level.move_child(self, props.get_index() + 1)


func _process(delta: float) -> void:
	if _level == null:
		return
	if _level.grid != _grid:
		_grid = _level.grid
		_rebuild()
	_time += delta
	if not _torches.is_empty():
		queue_redraw()


func _rebuild() -> void:
	_floor.clear()
	_torches.clear()
	if _grid != null:
		for y in _grid.height:
			for x in _grid.width:
				var cell: Vector2i = Vector2i(x, y)
				var roll: float = float(absi(hash([cell, "decor"])) % 1000) / 1000.0
				var kind: int = absi(hash([cell, "kind"]))
				if _grid.get_cell(cell) == LevelGrid.Cell.FLOOR and roll < floor_decor_chance:
					_floor[cell] = kind
				elif _grid.get_cell(cell) == LevelGrid.Cell.WALL and _grid.is_floor(cell + Vector2i.DOWN) \
						and roll < torch_chance:
					_torches.append(cell)
	queue_redraw()


func _draw() -> void:
	if _level == null or _grid == null:
		return
	var size: float = float(_level.theme.tile_size)
	for cell: Vector2i in _floor:
		var kind: int = int(_floor[cell])
		var origin: Vector2 = Vector2(cell) * size
		match kind % 3:
			0:
				_draw_piece(origin, PIECES[kind % PIECES.size()], BONE, BONE_SHADOW)
			1:
				_draw_piece(origin, PIECES[(kind / 3) % PIECES.size()], RUBBLE, RUBBLE_SHADOW)
			_:
				for i in 4:
					var x: float = 3.0 + float((kind / 7 + i * 3) % 10)
					draw_rect(Rect2(origin + Vector2(x, 12.0 - float(i % 2)), Vector2(1, 2 + i % 2)), GRASS if i % 2 == 0 else GRASS_DARK)
	var frame: int = int(_time * flame_fps)
	for cell: Vector2i in _torches:
		var origin: Vector2 = Vector2(cell) * size + Vector2(7, 7)
		draw_rect(Rect2(origin + Vector2(0, 2), Vector2(2, 4)), WOOD)
		var flicker: int = (frame + absi(hash(cell))) % 4
		draw_rect(Rect2(origin + Vector2(-1, 0), Vector2(4, 2)), FLAME[0])
		draw_rect(Rect2(origin + Vector2(0, -1 - flicker % 2), Vector2(2, 2 + flicker % 2)), FLAME[1 + flicker % 2])
		draw_rect(Rect2(origin + Vector2(flicker % 2, -2 - flicker % 3), Vector2(1, 2)), FLAME[3])


func _draw_piece(origin: Vector2, pixels: Array, light: Color, dark: Color) -> void:
	for p: Array in pixels:
		draw_rect(Rect2(origin + Vector2(p[0], p[1]), Vector2.ONE), light if p[2] == 0 else dark)
