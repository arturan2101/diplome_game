class_name Level
extends Node2D
## One section in the scene: draws a LevelGrid with tiles, gives walls their collision,
## and answers questions about the ground (cell types, paths, safe positions).
## Actors find it through the "level" group.

const GROUP: StringName = &"level"
const DEFAULT_THEME: TileTheme = preload("res://level/ruins_theme.tres")
## Ids of the two atlases inside the generated TileSet.
const MAIN_SOURCE: int = 0
const HAZARD_SOURCE: int = 1
## How far (in cells) to look for floor around a blocked cell.
const NEAREST_FLOOR_RADIUS: int = 6

## Pictures for the cells. Empty = the default ruins theme.
@export var theme: TileTheme
## Optional text map built on start, for hand-made test levels (see LevelGrid.TEXT_CELLS).
@export_multiline var debug_map: String = ""

var grid: LevelGrid = null

var _ground: TileMapLayer = null
var _props: TileMapLayer = null
var _astar: AStarGrid2D = AStarGrid2D.new()


func _ready() -> void:
	add_to_group(GROUP)
	if theme == null:
		theme = DEFAULT_THEME
	_ground = TileMapLayer.new()
	_ground.name = "Ground"
	add_child(_ground)
	_props = TileMapLayer.new()
	_props.name = "Props"
	add_child(_props)
	var tile_set: TileSet = _make_tile_set()
	_ground.tile_set = tile_set
	_props.tile_set = tile_set
	if grid == null and debug_map.strip_edges() != "":
		build(LevelGrid.from_text(debug_map))


## Draws the grid and prepares pathfinding. Replaces whatever was built before.
func build(new_grid: LevelGrid) -> void:
	grid = new_grid
	_ground.clear()
	_props.clear()
	for y in grid.height:
		for x in grid.width:
			_paint_cell(Vector2i(x, y))
	_astar.region = Rect2i(0, 0, grid.width, grid.height)
	_astar.cell_size = Vector2(theme.tile_size, theme.tile_size)
	_astar.offset = _astar.cell_size * 0.5
	# No cutting corners around walls and pits.
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for y in grid.height:
		for x in grid.width:
			var cell: Vector2i = Vector2i(x, y)
			# Enemies walk over plain floor only: walls, cover, pits and spikes are all "solid".
			_astar.set_point_solid(cell, not grid.is_floor(cell))


## Changes cells while the level is running (the doors of an arena lock and unlock).
## Tiles, collision and pathfinding follow.
func set_cells(cells: Array[Vector2i], type: LevelGrid.Cell) -> void:
	for cell: Vector2i in cells:
		grid.set_cell(cell, type)
		_ground.erase_cell(cell)
		_props.erase_cell(cell)
		_paint_cell(cell)
		_astar.set_point_solid(cell, not grid.is_floor(cell))


## Up to count floor cells around a world position, nearest first (where loot falls).
func free_floor_cells_near(world_position: Vector2, count: int) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var start: Vector2i = cell_at(world_position)
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size() and found.size() < count:
		var cell: Vector2i = queue[head]
		head += 1
		if grid.is_floor(cell) and cell != start:
			found.append(cell)
		for step: Vector2i in LevelGrid.NEIGHBOURS:
			var next: Vector2i = cell + step
			if grid.is_floor(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return found


func cell_at(world_position: Vector2) -> Vector2i:
	return Vector2i((to_local(world_position) / float(theme.tile_size)).floor())


func cell_center(cell: Vector2i) -> Vector2:
	return to_global((Vector2(cell) + Vector2(0.5, 0.5)) * float(theme.tile_size))


func cell_type_at(world_position: Vector2) -> LevelGrid.Cell:
	if grid == null:
		return LevelGrid.Cell.FLOOR
	return grid.get_cell(cell_at(world_position))


## World-space waypoints from one position to another over plain floor, or an empty
## array if there is no way. Ends that are not on floor snap to the nearest floor cell.
func find_path(from: Vector2, to: Vector2) -> PackedVector2Array:
	var path: PackedVector2Array = PackedVector2Array()
	if grid == null:
		return path
	var from_cell: Vector2i = nearest_floor_cell(cell_at(from))
	var to_cell: Vector2i = nearest_floor_cell(cell_at(to))
	if not grid.in_bounds(from_cell) or not grid.in_bounds(to_cell):
		return path
	for point: Vector2 in _astar.get_point_path(from_cell, to_cell):
		path.append(to_global(point))
	return path


## The closest floor cell to the given one (itself if it is floor), or (-1, -1).
func nearest_floor_cell(cell: Vector2i) -> Vector2i:
	if grid.is_floor(cell):
		return cell
	var best: Vector2i = Vector2i(-1, -1)
	var best_distance: int = -1
	for dy in range(-NEAREST_FLOOR_RADIUS, NEAREST_FLOOR_RADIUS + 1):
		for dx in range(-NEAREST_FLOOR_RADIUS, NEAREST_FLOOR_RADIUS + 1):
			var candidate: Vector2i = cell + Vector2i(dx, dy)
			if not grid.is_floor(candidate):
				continue
			var distance: int = dx * dx + dy * dy
			if best_distance < 0 or distance < best_distance:
				best = candidate
				best_distance = distance
	return best


## Centre of the closest floor cell: where a fallen actor is put back.
func nearest_safe_position(world_position: Vector2) -> Vector2:
	var cell: Vector2i = nearest_floor_cell(cell_at(world_position))
	if not grid.in_bounds(cell):
		return world_position
	return cell_center(cell)


## Rectangle of the whole level in world coordinates (camera limits).
func get_bounds() -> Rect2:
	if grid == null:
		return Rect2()
	return Rect2(global_position, Vector2(grid.width, grid.height) * float(theme.tile_size))


func _paint_cell(cell: Vector2i) -> void:
	match grid.get_cell(cell):
		LevelGrid.Cell.FLOOR:
			_ground.set_cell(cell, MAIN_SOURCE, _floor_tile(cell))
		LevelGrid.Cell.WALL:
			# Solid rock that touches nothing walkable gets no tile and no collision:
			# big sections stay cheap to draw and to simulate.
			if _touches_open_cell(cell):
				_ground.set_cell(cell, MAIN_SOURCE, _wall_tile(cell))
		LevelGrid.Cell.PIT:
			var below_pit: bool = grid.get_cell(cell + Vector2i.UP) == LevelGrid.Cell.PIT
			_ground.set_cell(cell, HAZARD_SOURCE, theme.pit_inner_tile if below_pit else theme.pit_tile)
		LevelGrid.Cell.SPIKES:
			_ground.set_cell(cell, HAZARD_SOURCE, theme.spikes_tile)
		LevelGrid.Cell.COVER:
			_ground.set_cell(cell, MAIN_SOURCE, _floor_tile(cell))
			_props.set_cell(cell, MAIN_SOURCE, theme.cover_tile)


## True if any of the 8 cells around is not a wall.
func _touches_open_cell(cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if grid.get_cell(cell + Vector2i(dx, dy)) != LevelGrid.Cell.WALL:
				return true
	return false


## Wall tile for a cell. A wall with an open cell directly south shows its front
## face (wall_tiles); any other wall shows only its top (wall_top_tiles), so side
## walls do not repeat the brick face. Without wall_top_tiles all walls use wall_tiles.
func _wall_tile(cell: Vector2i) -> Vector2i:
	var tiles: Array[Vector2i] = theme.wall_tiles
	var open_south: bool = grid.get_cell(cell + Vector2i.DOWN) != LevelGrid.Cell.WALL
	if not open_south and not theme.wall_top_tiles.is_empty():
		tiles = theme.wall_top_tiles
	return tiles[_cell_hash(cell) % tiles.size()]


## Floor tile for a cell. Variants are picked from the cell coordinates, not from
## a random generator, so the same grid always looks the same.
func _floor_tile(cell: Vector2i) -> Vector2i:
	var roll: int = _cell_hash(cell)
	if theme.floor_tiles.size() > 1 and (roll % 100) < int(theme.floor_variant_chance * 100.0):
		return theme.floor_tiles[1 + (roll / 100) % (theme.floor_tiles.size() - 1)]
	return theme.floor_tiles[0]


func _cell_hash(cell: Vector2i) -> int:
	return absi(hash(cell))


func _make_tile_set() -> TileSet:
	var tile_set: TileSet = TileSet.new()
	tile_set.tile_size = Vector2i(theme.tile_size, theme.tile_size)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, theme.solid_collision_layer)
	tile_set.set_physics_layer_collision_mask(0, 0)
	var main: TileSetAtlasSource = _make_source(tile_set, MAIN_SOURCE, theme.texture)
	for coords: Vector2i in theme.floor_tiles:
		_add_tile(main, coords, false)
	for coords: Vector2i in theme.wall_tiles:
		_add_tile(main, coords, true)
	for coords: Vector2i in theme.wall_top_tiles:
		_add_tile(main, coords, true)
	_add_tile(main, theme.cover_tile, true)
	var hazards: TileSetAtlasSource = _make_source(tile_set, HAZARD_SOURCE, theme.hazard_texture)
	_add_tile(hazards, theme.pit_tile, false)
	_add_tile(hazards, theme.pit_inner_tile, false)
	_add_tile(hazards, theme.spikes_tile, false)
	return tile_set


func _make_source(tile_set: TileSet, source_id: int, texture: Texture2D) -> TileSetAtlasSource:
	var source: TileSetAtlasSource = TileSetAtlasSource.new()
	source.texture = texture
	source.texture_region_size = Vector2i(theme.tile_size, theme.tile_size)
	tile_set.add_source(source, source_id)
	return source


func _add_tile(source: TileSetAtlasSource, coords: Vector2i, solid: bool) -> void:
	if source.has_tile(coords):
		return
	source.create_tile(coords)
	if not solid:
		return
	var half: float = theme.tile_size * 0.5
	var tile_data: TileData = source.get_tile_data(coords, 0)
	tile_data.add_collision_polygon(0)
	tile_data.set_collision_polygon_points(0, 0, PackedVector2Array([
			Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)]))
