class_name CombatRoomTracker
extends Node
## Combat rooms of the current section (stage 23). Their enemies are not there at the
## start: when the player walks trigger_depth tiles into such a room its doors seal and
## the enemies come in waves. Every enemy of a wave is first a spawn marker for
## warning_time seconds, on a cell at least min_player_distance from the player; the
## next wave comes when this one is dead, and after the last one the doors open.
## The Game owns it and hands it the layout of each section; arenas stay with the Game.

signal room_sealed(room: CombatRoom)
signal wave_started(room: CombatRoom, wave: int)
signal room_cleared(room: CombatRoom)

const MARKER_SCENE: PackedScene = preload("res://actors/enemies/spawn_marker.tscn")

## How many tiles inside the room the player must be for its doors to seal.
@export var trigger_depth: int = 2
## Seconds a spawn marker warns before its enemy appears.
@export var warning_time: float = 1.0
## Enemies appear at least this far from the player (pixels).
@export var min_player_distance: float = 64.0

var game: Game = null
var rooms: Array[CombatRoom] = []


## Takes the combat rooms of a freshly built section.
func setup(layout: SectionLayout) -> void:
	rooms.clear()
	for entry: Dictionary in layout.combat_rooms:
		var room: CombatRoom = CombatRoom.new()
		room.index = int(entry["room"])
		room.rect = layout.room_rects[room.index]
		room.doors.assign(entry["doors"])
		for _wave in int(entry["waves"]):
			room.waves.append([])
		rooms.append(room)
	for enemy: Dictionary in layout.enemies:
		var room: CombatRoom = get_room(int(enemy["room"]))
		if room != null:
			room.waves[clampi(int(enemy["wave"]), 0, room.waves.size() - 1)].append(enemy)


## The combat room with this room index, or null.
func get_room(room_index: int) -> CombatRoom:
	for room: CombatRoom in rooms:
		if room.index == room_index:
			return room
	return null


## True if this enemy entry of the layout waits for its combat room.
func owns(enemy_entry: Dictionary) -> bool:
	return get_room(int(enemy_entry["room"])) != null


func is_fighting() -> bool:
	for room: CombatRoom in rooms:
		if room.is_fighting():
			return true
	return false


func _physics_process(_delta: float) -> void:
	if game == null or game.player == null or GameManager.is_run_over:
		return
	var cell: Vector2i = game.level.cell_at(game.player.global_position)
	for room: CombatRoom in rooms:
		if room.state == CombatRoom.State.WAITING and room.rect.grow(-trigger_depth).has_point(cell):
			_seal(room)


func _seal(room: CombatRoom) -> void:
	room.state = CombatRoom.State.FIGHTING
	game.level.set_cells(room.doors, LevelGrid.Cell.WALL)
	# Nobody may stay inside a sealed door.
	for enemy: Enemy in game.get_enemies():
		var cell: Vector2i = game.level.cell_at(enemy.global_position)
		if cell in room.doors:
			enemy.global_position = game.level.nearest_safe_position(enemy.global_position)
	room_sealed.emit(room)
	_send_wave(room)


func _send_wave(room: CombatRoom) -> void:
	var wave: int = room.next_wave
	room.next_wave += 1
	wave_started.emit(room, wave)
	var used: Dictionary = {}
	for entry: Dictionary in room.waves[wave]:
		var data: EnemyData = game.get_enemy_data(entry["id"])
		if data == null:
			continue
		var cell: Vector2i = _spawn_cell(room, entry["cell"], used)
		used[cell] = true
		var marker: SpawnMarker = MARKER_SCENE.instantiate() as SpawnMarker
		marker.cell = cell
		marker.start(warning_time)
		marker.expired.connect(_on_marker_expired.bind(room, data))
		game.add_section_node(marker)
		# First among the section's things: drawn over the floor, under the actors.
		marker.get_parent().move_child(marker, 0)
		marker.global_position = game.level.cell_center(cell)
		room.warning += 1
	_check(room)


func _on_marker_expired(marker: SpawnMarker, room: CombatRoom, data: EnemyData) -> void:
	room.warning -= 1
	var enemy: Enemy = game.spawn_enemy(data, marker.cell)
	room.alive += 1
	enemy.defeated.connect(_on_enemy_defeated.bind(room))


func _on_enemy_defeated(_enemy: Enemy, room: CombatRoom) -> void:
	room.alive -= 1
	_check(room)


## Next wave when this one is over, and the doors open after the last one.
func _check(room: CombatRoom) -> void:
	if room.state != CombatRoom.State.FIGHTING or room.alive > 0 or room.warning > 0:
		return
	if room.next_wave < room.waves.size():
		_send_wave(room)
		return
	room.state = CombatRoom.State.CLEARED
	game.level.set_cells(room.doors, LevelGrid.Cell.FLOOR)
	room_cleared.emit(room)


## The planned cell if it is far enough from the player, else the nearest free floor
## cell of the room that is (the farthest one if none is).
func _spawn_cell(room: CombatRoom, planned: Vector2i, used: Dictionary) -> Vector2i:
	var player_position: Vector2 = game.player.global_position
	var level: Level = game.level
	if level.grid.is_floor(planned) and not used.has(planned) \
			and level.cell_center(planned).distance_to(player_position) >= min_player_distance:
		return planned
	var best: Vector2i = planned
	var best_score: float = INF
	var farthest: Vector2i = planned
	var farthest_distance: float = -1.0
	var inside: Rect2i = room.rect.grow(-1)
	for y in range(inside.position.y, inside.end.y):
		for x in range(inside.position.x, inside.end.x):
			var cell: Vector2i = Vector2i(x, y)
			if not level.grid.is_floor(cell) or used.has(cell):
				continue
			var distance: float = level.cell_center(cell).distance_to(player_position)
			if distance > farthest_distance:
				farthest_distance = distance
				farthest = cell
			if distance < min_player_distance:
				continue
			var score: float = Vector2(cell - planned).length_squared()
			if score < best_score:
				best_score = score
				best = cell
	return best if best_score < INF else farthest
