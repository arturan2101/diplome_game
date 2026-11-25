class_name SporePuff
extends Node2D
## The fungal puffball (stage 48, numbers in SporeTrapData): breathes on the floor;
## when the player comes within trigger_radius it bursts, and on the release frame of
## the burst a spore cloud (SpellZone) appears on it. Then it lies flat for regrow_time
## and breathes again. Walkable, no collision: only the cloud hurts.
## pick_cells() chooses where the puffballs of a section go.

enum State { BREATHING, BURSTING, SPENT }

var data: SporeTrapData = null
var state: State = State.BREATHING
var _sprite: AnimatedSprite2D = null
var _released: bool = false
var _regrow_left: float = 0.0


## A new puffball at a world position, added to parent.
static func spawn(parent: Node, at: Vector2, trap: SporeTrapData) -> SporePuff:
	var puff: SporePuff = SporePuff.new()
	puff.data = trap
	parent.add_child(puff)
	puff.global_position = at
	return puff


## Cells for the puffballs of a section: plain floor inside the rooms of the main path
## but the first (the player starts there) and the arena, with plain floor all round
## (never in a doorway or against a wall), away from the entrance, the exit portal, the
## items and the enemies, and min_spacing apart. Picked with rng from the candidates in
## a fixed order, so the same section and seed give the same cells.
static func pick_cells(layout: SectionLayout, trap: SporeTrapData, rng: RandomNumberGenerator) -> Array[Vector2i]:
	var cells: Array[Vector2i] = []
	if layout.arena_room >= 0:
		return cells
	var keep_away: Array[Vector2i] = [layout.entrance]
	keep_away.append_array(SectionBuilder.gate_footprint(layout.exit))
	for entry: Dictionary in layout.items + layout.enemies:
		keep_away.append(entry["cell"])
	var candidates: Array[Vector2i] = []
	for room in range(1, mini(layout.path_room_count, layout.room_rects.size())):
		var rect: Rect2i = layout.room_rects[room]
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var cell: Vector2i = Vector2i(x, y)
				if _open_all_round(layout.grid, cell) and not _near_any(cell, keep_away, trap.clearance):
					candidates.append(cell)
	var wanted: int = rng.randi_range(trap.per_section.x, trap.per_section.y)
	while cells.size() < wanted and not candidates.is_empty():
		var cell: Vector2i = candidates[rng.randi_range(0, candidates.size() - 1)]
		cells.append(cell)
		candidates = candidates.filter(func(other: Vector2i) -> bool:
			return maxi(absi(other.x - cell.x), absi(other.y - cell.y)) >= trap.min_spacing)
	return cells


static func _open_all_round(grid: LevelGrid, cell: Vector2i) -> bool:
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if not grid.is_floor(cell + Vector2i(dx, dy)):
				return false
	return true


static func _near_any(cell: Vector2i, others: Array[Vector2i], distance: int) -> bool:
	for other: Vector2i in others:
		if maxi(absi(other.x - cell.x), absi(other.y - cell.y)) <= distance:
			return true
	return false


func _ready() -> void:
	if data.frames != null and data.frames.has_animation(data.breathe_animation):
		_sprite = AnimatedSprite2D.new()
		_sprite.sprite_frames = data.frames
		_sprite.frame_changed.connect(_on_frame_changed)
		_sprite.animation_finished.connect(_on_burst_finished)
		add_child(_sprite)
		_breathe()


func _physics_process(delta: float) -> void:
	match state:
		State.BREATHING:
			var player: Node2D = get_tree().get_first_node_in_group(Player.GROUP) as Node2D
			if player != null and player.global_position.distance_to(global_position) <= data.trigger_radius:
				burst()
		State.SPENT:
			_regrow_left -= delta
			if _regrow_left <= 0.0:
				_breathe()


## Bursts now (the player came close): the cloud comes out on the release frame.
func burst() -> void:
	if state != State.BREATHING:
		return
	state = State.BURSTING
	_released = false
	if _sprite == null or not data.frames.has_animation(data.burst_animation):
		_release()
		_on_burst_finished()
		return
	_sprite.play(data.burst_animation)


func _on_frame_changed() -> void:
	if state == State.BURSTING and _sprite.animation == data.burst_animation and _sprite.frame >= data.release_frame:
		_release()


func _release() -> void:
	if _released:
		return
	_released = true
	Sound.play_at(data.burst_sound, global_position)
	if data.cloud != null:
		SpellZone.spawn(get_parent(), global_position, data.cloud, 1, self, data.id, data.target_mask, data.wall_mask)


func _on_burst_finished() -> void:
	if state != State.BURSTING:
		return
	_release()
	state = State.SPENT
	_regrow_left = data.regrow_time


func _breathe() -> void:
	state = State.BREATHING
	if _sprite != null:
		_sprite.play(data.breathe_animation)
		# Puffballs side by side do not breathe in step.
		_sprite.frame = absi(hash(global_position)) % maxi(data.frames.get_frame_count(data.breathe_animation), 1)
