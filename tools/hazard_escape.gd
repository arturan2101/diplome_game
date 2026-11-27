class_name HazardEscape
extends RefCounted
## Where a bot steps out of a boss pattern (stage 50): the nearest spot on plain floor
## that the hazards it knows will not hurt from the moment it gets there until a while
## later, reached in a straight line that no hazard crosses at the time the bot walks it.
## Kept apart from BotPlayer so the search can be tested without a whole game.

## Distances (pixels) and directions tried, nearest first.
const RINGS: Array[float] = [10.0, 18.0, 26.0, 36.0, 48.0, 62.0, 78.0, 96.0, 116.0]
const DIRECTIONS: int = 16
## Seconds the spot must stay safe after the bot arrives: at least this, and at least
## the horizon the bot looks ahead (else it would walk out again at once).
const STAY_TIME: float = 0.5
const DEFAULT_HORIZON: float = 0.9
## The way there is checked every this many pixels, each point around its moment.
const PATH_STEP: float = 8.0
const PATH_SLACK: float = 0.1


## The nearest safe spot from a world position, or Vector2.INF if there is none.
## start_angle turns the order of the directions (a bot's own random choice).
static func find_spot(level: Level, tree: SceneTree, from: Vector2, speed: float, margin: float,
		hazards: Array, start_angle: float = 0.0, horizon: float = DEFAULT_HORIZON) -> Vector2:
	var stay: float = maxf(STAY_TIME, horizon)
	var walk: float = maxf(speed, 1.0)
	for ring: float in RINGS:
		for i in DIRECTIONS:
			var direction: Vector2 = Vector2.from_angle(start_angle + TAU * i / DIRECTIONS)
			var spot: Vector2 = from + direction * ring
			var arrive: float = ring / walk
			if not _is_floor_line(level, from, direction, ring + margin):
				continue
			if BossHazard.threat_at(tree, spot, margin, arrive, arrive + stay, hazards):
				continue
			if _way_is_safe(tree, from, direction, ring, walk, margin, hazards):
				return spot
	return Vector2.INF


static func _way_is_safe(tree: SceneTree, from: Vector2, direction: Vector2, distance: float, speed: float,
		margin: float, hazards: Array) -> bool:
	var travelled: float = PATH_STEP
	while travelled < distance:
		var moment: float = travelled / speed
		if BossHazard.threat_at(tree, from + direction * travelled, margin, maxf(moment - PATH_SLACK, 0.0),
				moment + PATH_SLACK, hazards):
			return false
		travelled += PATH_STEP
	return true


## True if every point of the line, every half tile, is plain floor.
static func _is_floor_line(level: Level, from: Vector2, direction: Vector2, distance: float) -> bool:
	if level == null:
		return true
	var step: float = float(level.theme.tile_size) * 0.5
	var travelled: float = step
	while travelled <= distance:
		if level.cell_type_at(from + direction * travelled) != LevelGrid.Cell.FLOOR:
			return false
		travelled += step
	return level.cell_type_at(from + direction * distance) == LevelGrid.Cell.FLOOR
