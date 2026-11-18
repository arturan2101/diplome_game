class_name LevelDecor
extends Node2D
## Visual only, no collision: small things on the floor (pebbles, cracks, a puddle,
## moss, old bones...), torches with a warm glow, half-columns and statues against the
## brick fronts of walls, and rubble on doors that were walled up while the level runs
## (an arena or a combat room sealing). Places are picked from the cell coordinates
## (hash), never from the game's random streams, so the same grid always looks the same
## and the decor changes nothing in the sections. Sits under a Level (main.tscn) and
## rebuilds itself when the Level gets a new grid.

## Share of plain floor cells with a decal, and of brick wall fronts with a torch, a
## half-column or a statue.
@export_range(0.0, 1.0) var floor_decor_chance: float = 0.06
@export_range(0.0, 1.0) var torch_chance: float = 0.08
@export_range(0.0, 1.0) var pillar_chance: float = 0.05
@export_range(0.0, 1.0) var statue_chance: float = 0.025
## Floor decals: a strip of 16x16 pieces (pebbles, rubble, cracks, puddle, moss, bones,
## broken slab), plus single pictures.
@export var floor_decals: Texture2D = preload("res://assets/art/tiles/floor_decals.png")
@export var extra_decals: Array[Texture2D] = [preload("res://assets/art/level/bones.png")]
## Torch: a strip of flame frames, its frames per second, and its glow.
@export var torch: Texture2D = preload("res://assets/art/level/torch.png")
@export var torch_frames: int = 4
@export var flame_fps: float = 8.0
@export var torch_light: Texture2D = preload("res://assets/art/fx/light_torch.png")
@export var torch_light_color: Color = Color(1.0, 0.62, 0.3, 0.22)
## How much the glow breathes (share of its size).
@export var torch_light_flicker: float = 0.06
## Against the wall fronts; their bottom stands on the bottom of the wall cell.
@export var pillar: Texture2D = preload("res://assets/art/level/pillar.png")
@export var statue: Texture2D = preload("res://assets/art/level/statue.png")
## Rubble drawn on door cells that turned into walls (sealed doors).
@export var door_seal: Texture2D = preload("res://assets/art/tiles/door_seal.png")

enum WallPiece { TORCH, PILLAR, STATUE }

var _level: Level = null
var _grid: LevelGrid = null
## {cell: decal index}.
var _floor: Dictionary = {}
## {cell: WallPiece}.
var _wall: Dictionary = {}
var _torches: Array[Vector2i] = []
## Door cells walled up while the level runs: {cell: true}.
var _sealed: Dictionary = {}
var _time: float = 0.0
## The glow is drawn by its own node with additive blending.
var _lights: Node2D = null


func _ready() -> void:
	_level = get_parent() as Level
	_lights = Node2D.new()
	_lights.name = "Lights"
	var glow: CanvasItemMaterial = CanvasItemMaterial.new()
	glow.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	_lights.material = glow
	_lights.draw.connect(_draw_lights)
	add_child(_lights)
	if _level != null:
		_level.cells_changed.connect(_on_cells_changed)
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
		_lights.queue_redraw()


func _rebuild() -> void:
	_floor.clear()
	_wall.clear()
	_torches.clear()
	_sealed.clear()
	if _grid != null:
		var decal_count: int = _decal_count()
		for y in _grid.height:
			for x in _grid.width:
				var cell: Vector2i = Vector2i(x, y)
				var roll: float = float(absi(hash([cell, "decor"])) % 1000) / 1000.0
				var kind: int = absi(hash([cell, "kind"]))
				if _grid.get_cell(cell) == LevelGrid.Cell.FLOOR and roll < floor_decor_chance and decal_count > 0:
					_floor[cell] = kind % decal_count
				elif _is_wall_front(cell):
					if roll < torch_chance:
						_wall[cell] = WallPiece.TORCH
						_torches.append(cell)
					elif roll < torch_chance + pillar_chance:
						_wall[cell] = WallPiece.PILLAR
					elif roll < torch_chance + pillar_chance + statue_chance:
						_wall[cell] = WallPiece.STATUE
	queue_redraw()
	_lights.queue_redraw()


## A wall cell showing its brick front: plain floor right below it.
func _is_wall_front(cell: Vector2i) -> bool:
	return _grid.get_cell(cell) == LevelGrid.Cell.WALL and _grid.is_floor(cell + Vector2i.DOWN)


func _decal_count() -> int:
	var strip: int = floor_decals.get_width() / _tile() if floor_decals != null else 0
	return strip + extra_decals.size()


func _tile() -> int:
	return _level.theme.tile_size if _level != null and _level.theme != null else 16


func _on_cells_changed(cells: Array[Vector2i], type: LevelGrid.Cell) -> void:
	for cell: Vector2i in cells:
		if type == LevelGrid.Cell.WALL:
			_sealed[cell] = true
		else:
			_sealed.erase(cell)
	queue_redraw()


func _draw() -> void:
	if _level == null or _grid == null:
		return
	var size: float = float(_tile())
	var strip: int = floor_decals.get_width() / _tile() if floor_decals != null else 0
	for cell: Vector2i in _floor:
		var index: int = int(_floor[cell])
		var spot: Rect2 = Rect2(Vector2(cell) * size, Vector2(size, size))
		if index < strip:
			draw_texture_rect_region(floor_decals, spot, Rect2(index * size, 0.0, size, size))
		else:
			draw_texture_rect(extra_decals[index - strip], spot, false)
	var flame: int = int(_time * flame_fps)
	for cell: Vector2i in _wall:
		var bottom: Vector2 = Vector2(cell) * size + Vector2(size * 0.5, size)
		match _wall[cell]:
			WallPiece.TORCH:
				if torch != null:
					var frame: int = (flame + absi(hash(cell))) % maxi(torch_frames, 1)
					var w: float = float(torch.get_width()) / maxi(torch_frames, 1)
					draw_texture_rect_region(torch, Rect2(bottom - Vector2(w * 0.5, size), Vector2(w, size)),
							Rect2(frame * w, 0.0, w, torch.get_height()))
			WallPiece.PILLAR:
				_draw_standing(pillar, bottom)
			WallPiece.STATUE:
				_draw_standing(statue, bottom)
	if door_seal != null:
		for cell: Vector2i in _sealed:
			draw_texture(door_seal, Vector2(cell) * size)


## A picture whose bottom stands on the bottom of the cell.
func _draw_standing(picture: Texture2D, bottom: Vector2) -> void:
	if picture != null:
		draw_texture(picture, bottom - Vector2(picture.get_width() * 0.5, picture.get_height()))


func _draw_lights() -> void:
	if torch_light == null or _grid == null:
		return
	var size: float = float(_tile())
	for cell: Vector2i in _torches:
		var breathe: float = 1.0 + torch_light_flicker * sin(_time * 7.0 + float(absi(hash(cell)) % 100))
		var extent: Vector2 = torch_light.get_size() * breathe
		var centre: Vector2 = Vector2(cell) * size + Vector2(size * 0.5, size * 0.6)
		_lights.draw_texture_rect(torch_light, Rect2(centre - extent * 0.5, extent), false, torch_light_color)
