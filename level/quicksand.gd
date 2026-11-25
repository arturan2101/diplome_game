class_name Quicksand
extends Node2D
## A patch of quicksand (stage 49, numbers in QuicksandData): a few floor cells drawn
## with swirling sand. The player and the enemies that walk (not fliers, ghosts or
## bosses: their HazardReceiver is off) are slowed while they stand on it. No
## collision and no damage. pick_patches() chooses where the patches of a section go.

var data: QuicksandData = null
## The cells of this patch (level grid).
var cells: Array[Vector2i] = []
var _level: Level = null
var _player_inside: bool = false
var _sound_left: float = 0.0


## A new patch over cells of level, added to parent.
static func spawn(parent: Node, level: Level, patch_cells: Array[Vector2i], stats: QuicksandData) -> Quicksand:
	var patch: Quicksand = Quicksand.new()
	patch.data = stats
	patch.cells = patch_cells
	patch._level = level
	parent.add_child(patch)
	return patch


## Rectangles of cells for the patches of a section: plain floor inside the rooms of
## the main path but the first and the arena, never touching a wall (so never in a
## doorway), away from the entrance and the exit portal (clearance) and from the items
## (item_clearance), and min_spacing apart. Enemies may stand on it. Picked with rng in
## a fixed order, so the same section and seed give the same patches.
static func pick_patches(layout: SectionLayout, stats: QuicksandData, rng: RandomNumberGenerator) -> Array[Rect2i]:
	var patches: Array[Rect2i] = []
	if layout.arena_room >= 0:
		return patches
	var gates: Array[Vector2i] = [layout.entrance]
	gates.append_array(SectionBuilder.gate_footprint(layout.exit))
	var items: Array[Vector2i] = []
	for entry: Dictionary in layout.items:
		items.append(entry["cell"])
	var wanted: int = rng.randi_range(stats.per_section.x, stats.per_section.y)
	for _i in wanted:
		var size: Vector2i = Vector2i(rng.randi_range(stats.patch_size.x, stats.patch_size.y),
				rng.randi_range(stats.patch_size.x, stats.patch_size.y))
		var candidates: Array[Rect2i] = []
		for room in range(1, mini(layout.path_room_count, layout.room_rects.size())):
			var room_rect: Rect2i = layout.room_rects[room]
			for y in range(room_rect.position.y, room_rect.end.y - size.y + 1):
				for x in range(room_rect.position.x, room_rect.end.x - size.x + 1):
					var rect: Rect2i = Rect2i(Vector2i(x, y), size)
					if _fits(layout.grid, rect) and not _near_any(rect, gates, stats.clearance) 							and not _near_any(rect, items, stats.item_clearance) and not _near_patches(rect, patches, stats.min_spacing):
						candidates.append(rect)
		if candidates.is_empty():
			break
		patches.append(candidates[rng.randi_range(0, candidates.size() - 1)])
	return patches


## The cells of a patch rectangle.
static func rect_cells(rect: Rect2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			result.append(Vector2i(x, y))
	return result


## Every cell plain floor, no wall next to any of them (cover and pits may be).
static func _fits(grid: LevelGrid, rect: Rect2i) -> bool:
	for cell: Vector2i in rect_cells(rect):
		if not grid.is_floor(cell):
			return false
	for cell: Vector2i in rect_cells(rect.grow(1)):
		if grid.get_cell(cell) == LevelGrid.Cell.WALL:
			return false
	return true


static func _near_any(rect: Rect2i, cells: Array[Vector2i], distance: int) -> bool:
	var guarded: Rect2i = rect.grow(distance)
	for cell: Vector2i in cells:
		if guarded.has_point(cell):
			return true
	return false


static func _near_patches(rect: Rect2i, patches: Array[Rect2i], spacing: int) -> bool:
	for other: Rect2i in patches:
		if rect.grow(spacing).intersects(other):
			return true
	return false


func _ready() -> void:
	if data.strip == null or _level == null:
		return
	for cell: Vector2i in cells:
		var sprite: StripSprite = StripSprite.new()
		sprite.texture = data.strip
		sprite.hframes = maxi(data.strip_frames, 1)
		sprite.fps = data.strip_fps
		add_child(sprite)
		sprite.global_position = _level.cell_center(cell)


func _physics_process(delta: float) -> void:
	if _level == null:
		return
	_sound_left = maxf(_sound_left - delta, 0.0)
	var player: Player = get_tree().get_first_node_in_group(Player.GROUP) as Player
	var player_on: bool = player != null and is_on(player.global_position)
	if player_on:
		player.slow(data.slow_multiplier, data.slow_linger)
		if not _player_inside and _sound_left <= 0.0:
			Sound.play_at(data.step_sound, player.global_position)
			_sound_left = data.sound_cooldown
	_player_inside = player_on
	# The enemies of the section are its siblings (the game's contents node).
	for node: Node in get_parent().get_children():
		var enemy: Enemy = node as Enemy
		if enemy != null and walks_on_sand(enemy) and is_on(enemy.global_position):
			enemy.slow(data.slow_multiplier, data.slow_linger)


## True if a world position is on this patch.
func is_on(world_position: Vector2) -> bool:
	return cells.has(_level.cell_at(world_position))


## Enemies that feel the floor (pits, spikes) feel the sand too; fliers, ghosts and
## bosses do not.
static func walks_on_sand(enemy: Enemy) -> bool:
	return enemy.hazards != null and enemy.hazards.process_mode != Node.PROCESS_MODE_DISABLED
