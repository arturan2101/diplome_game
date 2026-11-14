class_name LevelGrid
extends RefCounted
## Tile grid of one section: pure data without nodes, so generation and its tests
## run without the game. Level turns it into a TileMapLayer.

## SPIKES are static (always up); SPIKES_TIMED rise and hide on a cycle (SpikeTrapData).
enum Cell { WALL, FLOOR, PIT, SPIKES, COVER, SPIKES_TIMED }

## Characters of text maps (room templates, test maps). Anything else is read as floor.
const TEXT_CELLS: Dictionary = {
	"#": Cell.WALL,
	" ": Cell.WALL,
	".": Cell.FLOOR,
	"~": Cell.PIT,
	"^": Cell.SPIKES,
	"%": Cell.COVER,
	"!": Cell.SPIKES_TIMED,
}
const NEIGHBOURS: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]

var width: int = 0
var height: int = 0
## Phase shift in seconds of every timed spike cell (cell -> seconds): where in its
## cycle the cell is when the section starts.
var spike_phase: Dictionary = {}
## Wall cells drawn with a crack (the way into a secret room), as a set.
var cracked: Dictionary = {}
## Floor cells in a patch of light from above, as a set.
var sunlit: Dictionary = {}
## Floor cells paved with old slabs on purpose (around the glade's sunlit patch), as a set.
var paved: Dictionary = {}
## Parts of the grid drawn with another tile theme (a secret room's overgrown ruins):
## {"rect": Rect2i, "theme": StringName (a key of Level.region_themes)}.
var theme_regions: Array[Dictionary] = []

var _cells: PackedByteArray = PackedByteArray()


func _init(grid_width: int = 0, grid_height: int = 0, fill: Cell = Cell.WALL) -> void:
	width = grid_width
	height = grid_height
	_cells.resize(width * height)
	_cells.fill(fill)


## Builds a grid from lines of text, one character per cell (see TEXT_CELLS).
## Short lines are padded with walls.
static func from_text(text: String) -> LevelGrid:
	var lines: PackedStringArray = text.split("\n")
	while not lines.is_empty() and lines[lines.size() - 1].strip_edges() == "":
		lines.remove_at(lines.size() - 1)
	var grid_width: int = 0
	for line: String in lines:
		grid_width = maxi(grid_width, line.length())
	var grid: LevelGrid = LevelGrid.new(grid_width, lines.size())
	for y in lines.size():
		for x in lines[y].length():
			grid.set_cell(Vector2i(x, y), TEXT_CELLS.get(lines[y][x], Cell.FLOOR))
	return grid


func in_bounds(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < width and cell.y < height


## Cells outside the grid count as walls.
func get_cell(cell: Vector2i) -> Cell:
	if not in_bounds(cell):
		return Cell.WALL
	return _cells[cell.y * width + cell.x] as Cell


func set_cell(cell: Vector2i, type: Cell) -> void:
	if in_bounds(cell):
		_cells[cell.y * width + cell.x] = type
		if type != Cell.SPIKES_TIMED:
			spike_phase.erase(cell)
		elif not spike_phase.has(cell):
			spike_phase[cell] = 0.0


## Turns a cell into timed spikes with the given phase shift (seconds).
func set_timed_spikes(cell: Vector2i, phase_shift: float) -> void:
	if in_bounds(cell):
		set_cell(cell, Cell.SPIKES_TIMED)
		spike_phase[cell] = phase_shift


func fill_rect(rect: Rect2i, type: Cell) -> void:
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			set_cell(Vector2i(x, y), type)


## Safe to stand on: plain floor only (no pit, no spikes).
func is_floor(cell: Vector2i) -> bool:
	return get_cell(cell) == Cell.FLOOR


## Can be walked over: plain floor, and timed spikes, which are crossed between strikes.
func is_walkable(cell: Vector2i) -> bool:
	var type: Cell = get_cell(cell)
	return type == Cell.FLOOR or type == Cell.SPIKES_TIMED


## Blocks movement and sight: walls and cover.
func is_solid(cell: Vector2i) -> bool:
	var type: Cell = get_cell(cell)
	return type == Cell.WALL or type == Cell.COVER


## All cells reachable from start by walking (4 directions) over plain floor and timed
## spikes (they can be crossed between strikes); pits and static spikes stop the walk.
## Returned as a set: Dictionary with cells as keys.
func reachable_floor(start: Vector2i) -> Dictionary:
	var reached: Dictionary = {}
	if not is_walkable(start):
		return reached
	var queue: Array[Vector2i] = [start]
	reached[start] = true
	var head: int = 0
	while head < queue.size():
		var cell: Vector2i = queue[head]
		head += 1
		for step: Vector2i in NEIGHBOURS:
			var next: Vector2i = cell + step
			if is_walkable(next) and not reached.has(next):
				reached[next] = true
				queue.append(next)
	return reached


## Text form of the grid: for debugging and for comparing two builds.
func to_text() -> String:
	var symbols: Dictionary = {Cell.WALL: "#", Cell.FLOOR: ".", Cell.PIT: "~", Cell.SPIKES: "^", Cell.COVER: "%",
			Cell.SPIKES_TIMED: "!"}
	var lines: PackedStringArray = PackedStringArray()
	for y in height:
		var line: String = ""
		for x in width:
			line += symbols[get_cell(Vector2i(x, y))]
		lines.append(line)
	return "\n".join(lines)
