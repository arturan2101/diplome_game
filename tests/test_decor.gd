extends TestCase
## Headless test for the level's decor (stage 38): torches never stand side by side, no
## half-columns or statues on the walls, decor is the same for the same grid.

const ROWS: int = 12
const WIDTH: int = 60


func run() -> void:
	var lines: PackedStringArray = PackedStringArray()
	lines.append("#".repeat(WIDTH))
	for _y in ROWS:
		lines.append("#" + ".".repeat(WIDTH - 2) + "#")
	lines.append("#".repeat(WIDTH))
	var level: Level = Level.new()
	level.debug_map = "\n".join(lines)
	var decor: LevelDecor = LevelDecor.new()
	decor.torch_chance = 0.5
	level.add_child(decor)
	add_child(level)
	await physics_frames(3)
	decor._grid = level.grid
	decor._rebuild()
	var spaced: bool = true
	for a: Vector2i in decor._torches:
		for b: Vector2i in decor._torches:
			if a != b and Vector2(a).distance_to(Vector2(b)) < decor.torch_min_spacing:
				spaced = false
	check(decor._torches.size() > 3 and spaced, "torches stand at least %d cells apart (%d torches)" % [decor.torch_min_spacing, decor._torches.size()])
	var wall_statues: bool = false
	for cell: Vector2i in decor._wall:
		if decor._wall[cell] == LevelDecor.WallPiece.PILLAR or decor._wall[cell] == LevelDecor.WallPiece.STATUE:
			wall_statues = true
	check(not wall_statues, "no half-columns or statues on the walls (flat details are fine, stage 42)")
	var first: Array[Vector2i] = decor._torches.duplicate()
	decor._rebuild()
	check(decor._torches == first, "the same grid gets the same decor")
	level.queue_free()
	await physics_frames(2)
