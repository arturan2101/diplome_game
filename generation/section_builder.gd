class_name SectionBuilder
extends RefCounted
## Builds one section from the director's plan:
## 1. picks room templates and lays them out left to right (plus an optional treasure
##    room above or below one of them),
## 2. walls up unused doors and digs tunnels between the used ones (TunnelCarver),
## 3. fills the slots: cover, enemies, health packs, coins, chest,
## 4. checks that the gate and every placed thing can be reached from the entrance
##    over plain floor (no pits, no spikes); if not, builds again.
## All randomness comes from the generator passed to build(), so the same seed,
## section index and plan always give the same section.

const CATALOG_PATH: String = "res://actors/enemies/enemy_catalog.tres"
## Empty tiles kept around everything.
const MARGIN: int = 3
## Tunnel length between neighbouring rooms, in tiles.
const GAP_MIN: int = 6
const GAP_MAX: int = 12
## How far a room may shift up or down relative to the previous one, in tiles.
const HEIGHT_JITTER: int = 5
## Distance from a room to its treasure room, in tiles.
const BRANCH_GAP_MIN: int = 5
const BRANCH_GAP_MAX: int = 8
const BRANCH_SHIFT: int = 2
const MAX_ATTEMPTS: int = 20
## A room with a tag the director prefers is this many times more likely per tag.
const PREFERRED_TAG_WEIGHT: int = 3
const COINS_PER_SLOT: int = 3
## Reference time added per tunnel, in seconds.
const TUNNEL_REF_TIME: float = 3.0
const RANDOM_CELL_TRIES: int = 60

var _library: RoomLibrary = null
var _catalog: EnemyCatalog = null


func _init(library: RoomLibrary = null, catalog: EnemyCatalog = null) -> void:
	_library = library if library != null else RoomLibrary.get_default()
	_catalog = catalog if catalog != null else load(CATALOG_PATH) as EnemyCatalog


## Builds a section for the plan. rng should be GameManager.make_section_rng(index).
func build(plan: SectionPlan, rng: RandomNumberGenerator) -> SectionLayout:
	var layout: SectionLayout = null
	for attempt in MAX_ATTEMPTS:
		layout = _build_once(plan, rng)
		layout.attempts = attempt + 1
		if is_passable(layout):
			return layout
	push_error("SectionBuilder: no passable section after %d attempts" % MAX_ATTEMPTS)
	return layout


## True if the gate and all enemies and items can be reached from the entrance
## by walking over plain floor only.
static func is_passable(layout: SectionLayout) -> bool:
	var reached: Dictionary = layout.grid.reachable_floor(layout.entrance)
	if not reached.has(layout.exit):
		return false
	for entry: Dictionary in layout.enemies + layout.items:
		if not reached.has(entry["cell"]):
			return false
	return true


func _build_once(plan: SectionPlan, rng: RandomNumberGenerator) -> SectionLayout:
	var chain: Array[PlacedRoom] = _place_chain(plan, rng)
	var treasure: PlacedRoom = _place_treasure(chain, rng) if plan.has_side_branch else null
	var rooms: Array[PlacedRoom] = chain.duplicate()
	if treasure != null:
		rooms.append(treasure)
	var size: Vector2i = _move_into_grid(rooms)

	var layout: SectionLayout = SectionLayout.new()
	layout.grid = LevelGrid.new(size.x, size.y)
	var rects: Array[Rect2i] = []
	for room: PlacedRoom in rooms:
		_stamp(layout.grid, room)
		rects.append(room.get_rect())
		layout.room_rects.append(room.get_rect())
		layout.room_names.append(room.template.name)
		layout.reference_time += room.template.ref_time

	var carver: TunnelCarver = TunnelCarver.new(layout.grid, rects)
	for i in range(chain.size() - 1):
		carver.carve(_outside(chain[i], RoomTemplate.DoorSide.EAST), _outside(chain[i + 1], RoomTemplate.DoorSide.WEST),
				plan.corridor_width, plan.corridor_twist, rng)
		layout.reference_time += TUNNEL_REF_TIME
	if treasure != null:
		var host: PlacedRoom = _host_of(chain, treasure)
		var host_side: RoomTemplate.DoorSide = _branch_side(host)
		carver.carve(_outside(host, host_side), _outside(treasure, _opposite(host_side)),
				plan.corridor_width, plan.corridor_twist, rng)
		layout.reference_time += TUNNEL_REF_TIME
	carver.smooth()

	layout.entrance = _inside(layout.grid, chain[0], RoomTemplate.DoorSide.WEST)
	layout.exit = _inside(layout.grid, chain[chain.size() - 1], RoomTemplate.DoorSide.EAST)
	var taken: Dictionary = {layout.entrance: true, layout.exit: true}
	_place_cover(layout, rooms, plan, rng, taken)
	_place_enemies(layout, chain, treasure, plan, rng, taken)
	_place_items(layout, chain, treasure, plan, rng, taken)
	return layout


# --- rooms ---------------------------------------------------------------

## Picks the rooms of the main chain and puts them one after another, left to right.
func _place_chain(plan: SectionPlan, rng: RandomNumberGenerator) -> Array[PlacedRoom]:
	var candidates: Array[RoomTemplate] = _library.filter_by_tag(RoomTemplate.TREASURE_TAG, false)
	var chain: Array[PlacedRoom] = []
	var previous: RoomTemplate = null
	for i in clampi(plan.room_count, 2, 8):
		var template: RoomTemplate = _pick_room(candidates, plan, rng, previous)
		var origin: Vector2i = Vector2i.ZERO
		if not chain.is_empty():
			var last: PlacedRoom = chain[chain.size() - 1]
			origin.x = last.get_rect().end.x + rng.randi_range(GAP_MIN, GAP_MAX)
			# Keep the two doors roughly level, then shift a little.
			origin.y = last.door_cell(RoomTemplate.DoorSide.EAST).y - template.door_center(RoomTemplate.DoorSide.WEST).y \
					+ rng.randi_range(-HEIGHT_JITTER, HEIGHT_JITTER)
		var room: PlacedRoom = PlacedRoom.new(template, origin)
		if i > 0:
			room.used_doors.append(RoomTemplate.DoorSide.WEST)
			chain[i - 1].used_doors.append(RoomTemplate.DoorSide.EAST)
		chain.append(room)
		previous = template
	if plan.has_side_branch:
		_ensure_branch_door(chain, candidates, rng)
	return chain


func _pick_room(candidates: Array[RoomTemplate], plan: SectionPlan, rng: RandomNumberGenerator,
		previous: RoomTemplate) -> RoomTemplate:
	var weights: Array[int] = []
	var total: int = 0
	for template: RoomTemplate in candidates:
		var weight: int = 1
		for tag: StringName in plan.preferred_tags:
			if template.has_tag(tag):
				weight *= PREFERRED_TAG_WEIGHT
		# The same room twice in a row looks odd.
		if template == previous and candidates.size() > 1:
			weight = 0
		weights.append(weight)
		total += weight
	var roll: int = rng.randi_range(1, total)
	for i in candidates.size():
		roll -= weights[i]
		if roll <= 0:
			return candidates[i]
	return candidates[candidates.size() - 1]


## A side branch hangs from a top or bottom door of a room that is not the first one.
## If no such room was picked, one of them is swapped for a room that has such a door.
func _ensure_branch_door(chain: Array[PlacedRoom], candidates: Array[RoomTemplate], rng: RandomNumberGenerator) -> void:
	for i in range(1, chain.size()):
		if _has_branch_door(chain[i].template):
			return
	var with_door: Array[RoomTemplate] = []
	for template: RoomTemplate in candidates:
		if _has_branch_door(template):
			with_door.append(template)
	if with_door.is_empty():
		return
	var index: int = rng.randi_range(1, chain.size() - 1)
	var old: PlacedRoom = chain[index]
	var template: RoomTemplate = with_door[rng.randi_range(0, with_door.size() - 1)]
	# Keep the west door at the same height, so the layout stays in line.
	var origin: Vector2i = Vector2i(old.origin.x,
			old.door_cell(RoomTemplate.DoorSide.WEST).y - template.door_center(RoomTemplate.DoorSide.WEST).y)
	var room: PlacedRoom = PlacedRoom.new(template, origin)
	room.used_doors = old.used_doors
	chain[index] = room
	# Rooms to the right move with the new width.
	var shift: int = room.get_rect().end.x - old.get_rect().end.x
	for i in range(index + 1, chain.size()):
		chain[i].origin.x += shift


func _has_branch_door(template: RoomTemplate) -> bool:
	return template.has_door(RoomTemplate.DoorSide.NORTH) or template.has_door(RoomTemplate.DoorSide.SOUTH)


## Puts a treasure room above or below a chain room that has a door there.
func _place_treasure(chain: Array[PlacedRoom], rng: RandomNumberGenerator) -> PlacedRoom:
	var treasures: Array[RoomTemplate] = _library.filter_by_tag(RoomTemplate.TREASURE_TAG)
	var hosts: Array[PlacedRoom] = []
	for i in range(1, chain.size()):
		if _has_branch_door(chain[i].template):
			hosts.append(chain[i])
	if treasures.is_empty() or hosts.is_empty():
		return null
	var host: PlacedRoom = hosts[rng.randi_range(0, hosts.size() - 1)]
	var sides: Array[RoomTemplate.DoorSide] = []
	for side: RoomTemplate.DoorSide in [RoomTemplate.DoorSide.NORTH, RoomTemplate.DoorSide.SOUTH]:
		if host.template.has_door(side):
			sides.append(side)
	var host_side: RoomTemplate.DoorSide = sides[rng.randi_range(0, sides.size() - 1)]
	var template: RoomTemplate = treasures[rng.randi_range(0, treasures.size() - 1)]
	var own_side: RoomTemplate.DoorSide = _opposite(host_side)
	var gap: int = rng.randi_range(BRANCH_GAP_MIN, BRANCH_GAP_MAX)
	var origin: Vector2i = Vector2i.ZERO
	origin.x = host.door_cell(host_side).x - template.door_center(own_side).x + rng.randi_range(-BRANCH_SHIFT, BRANCH_SHIFT)
	if host_side == RoomTemplate.DoorSide.NORTH:
		origin.y = host.origin.y - gap - template.get_size().y
	else:
		origin.y = host.get_rect().end.y + gap
	var treasure: PlacedRoom = PlacedRoom.new(template, origin)
	treasure.used_doors.append(own_side)
	host.used_doors.append(host_side)
	return treasure


## The chain room whose top or bottom door leads to the treasure room.
func _host_of(chain: Array[PlacedRoom], _treasure: PlacedRoom) -> PlacedRoom:
	for room: PlacedRoom in chain:
		if RoomTemplate.DoorSide.NORTH in room.used_doors or RoomTemplate.DoorSide.SOUTH in room.used_doors:
			return room
	return null


func _branch_side(host: PlacedRoom) -> RoomTemplate.DoorSide:
	if RoomTemplate.DoorSide.NORTH in host.used_doors:
		return RoomTemplate.DoorSide.NORTH
	return RoomTemplate.DoorSide.SOUTH


## Shifts all rooms so that they sit inside a grid with a margin; returns the grid size.
func _move_into_grid(rooms: Array[PlacedRoom]) -> Vector2i:
	var bounds: Rect2i = rooms[0].get_rect()
	for room: PlacedRoom in rooms:
		bounds = bounds.merge(room.get_rect())
	var shift: Vector2i = Vector2i(MARGIN, MARGIN) - bounds.position
	for room: PlacedRoom in rooms:
		room.origin += shift
	return bounds.size + Vector2i(MARGIN, MARGIN) * 2


## Copies the room tiles into the grid and walls up the doors that lead nowhere.
func _stamp(grid: LevelGrid, room: PlacedRoom) -> void:
	var size: Vector2i = room.template.get_size()
	for y in size.y:
		for x in size.x:
			grid.set_cell(room.origin + Vector2i(x, y), room.template.grid.get_cell(Vector2i(x, y)))
	for side: RoomTemplate.DoorSide in room.template.doors:
		if side in room.used_doors:
			continue
		for cell: Vector2i in room.door_cells(side):
			grid.set_cell(cell, LevelGrid.Cell.WALL)


# --- doors ---------------------------------------------------------------

func _door_direction(side: RoomTemplate.DoorSide) -> Vector2i:
	match side:
		RoomTemplate.DoorSide.WEST:
			return Vector2i.LEFT
		RoomTemplate.DoorSide.EAST:
			return Vector2i.RIGHT
		RoomTemplate.DoorSide.NORTH:
			return Vector2i.UP
	return Vector2i.DOWN


func _opposite(side: RoomTemplate.DoorSide) -> RoomTemplate.DoorSide:
	match side:
		RoomTemplate.DoorSide.WEST:
			return RoomTemplate.DoorSide.EAST
		RoomTemplate.DoorSide.EAST:
			return RoomTemplate.DoorSide.WEST
		RoomTemplate.DoorSide.NORTH:
			return RoomTemplate.DoorSide.SOUTH
	return RoomTemplate.DoorSide.NORTH


## The cell just outside a door: where its tunnel starts.
func _outside(room: PlacedRoom, side: RoomTemplate.DoorSide) -> Vector2i:
	return room.door_cell(side) + _door_direction(side)


## A floor cell just inside a (walled-up) door: where the player starts or the gate stands.
func _inside(grid: LevelGrid, room: PlacedRoom, side: RoomTemplate.DoorSide) -> Vector2i:
	var inward: Vector2i = -_door_direction(side)
	var center: Vector2i = room.door_cell(side) + inward
	if grid.is_floor(center):
		return center
	for cell: Vector2i in room.door_cells(side):
		if grid.is_floor(cell + inward):
			return cell + inward
	return center


# --- contents ------------------------------------------------------------

func _place_cover(layout: SectionLayout, rooms: Array[PlacedRoom], plan: SectionPlan,
		rng: RandomNumberGenerator, taken: Dictionary) -> void:
	for room: PlacedRoom in rooms:
		for cell: Vector2i in room.to_section_cells(room.template.cover_slots):
			if rng.randf() < plan.cover_density and not taken.has(cell):
				layout.grid.set_cell(cell, LevelGrid.Cell.COVER)
				taken[cell] = true


## Enemies go into the enemy slots of every room except the first one (the player
## must not start in a fight). A pack fills the cells around its slot.
func _place_enemies(layout: SectionLayout, chain: Array[PlacedRoom], treasure: PlacedRoom, plan: SectionPlan,
		rng: RandomNumberGenerator, taken: Dictionary) -> void:
	var combat_rooms: Array[PlacedRoom] = chain.slice(1)
	if treasure != null:
		combat_rooms.append(treasure)
	var slots: Array[Vector2i] = []
	for room: PlacedRoom in combat_rooms:
		slots.append_array(room.to_section_cells(room.template.enemy_slots))
	_shuffle(slots, rng)
	var ids: Array = plan.enemy_mix.keys()
	ids.sort()
	var spawns: Array[StringName] = []
	for id: StringName in ids:
		for _i in int(plan.enemy_mix[id]):
			spawns.append(id)
	_shuffle(spawns, rng)
	for i in spawns.size():
		var data: EnemyData = _catalog.get_by_id(spawns[i])
		if data == null:
			push_warning("SectionBuilder: unknown enemy id %s in the plan" % spawns[i])
			continue
		var slot: Vector2i = slots[i] if i < slots.size() else _random_free_cell(layout.grid, combat_rooms, rng, taken)
		var pack_size: int = rng.randi_range(data.pack_min, maxi(data.pack_min, data.pack_max))
		for cell: Vector2i in _free_cells_near(layout.grid, slot, pack_size, taken):
			layout.enemies.append({"id": data.id, "cell": cell})
			taken[cell] = true


## Health packs first, then coins in small heaps, then the chest.
func _place_items(layout: SectionLayout, chain: Array[PlacedRoom], treasure: PlacedRoom, plan: SectionPlan,
		rng: RandomNumberGenerator, taken: Dictionary) -> void:
	var rooms: Array[PlacedRoom] = chain.duplicate()
	if treasure != null:
		rooms.append(treasure)
	if plan.has_chest:
		var chest_cell: Vector2i = _chest_cell(layout.grid, chain, treasure, rng, taken)
		layout.items.append({"id": SectionLayout.ITEM_CHEST, "cell": chest_cell})
		taken[chest_cell] = true
	var slots: Array[Vector2i] = []
	for room: PlacedRoom in rooms:
		slots.append_array(room.to_section_cells(room.template.item_slots))
	_shuffle(slots, rng)
	var next_slot: int = 0
	for _i in plan.health_packs:
		var slot: Vector2i = slots[next_slot] if next_slot < slots.size() else _random_free_cell(layout.grid, rooms, rng, taken)
		next_slot += 1
		for cell: Vector2i in _free_cells_near(layout.grid, slot, 1, taken):
			layout.items.append({"id": SectionLayout.ITEM_HEALTH_PACK, "cell": cell})
			taken[cell] = true
	var coins_left: int = plan.coins
	while coins_left > 0:
		var slot: Vector2i = slots[next_slot] if next_slot < slots.size() else _random_free_cell(layout.grid, rooms, rng, taken)
		next_slot += 1
		var heap: int = mini(coins_left, COINS_PER_SLOT)
		for cell: Vector2i in _free_cells_near(layout.grid, slot, heap, taken):
			layout.items.append({"id": SectionLayout.ITEM_COIN, "cell": cell})
			taken[cell] = true
		coins_left -= heap


## The chest stands in the treasure room if there is one, otherwise in a room of the chain.
func _chest_cell(grid: LevelGrid, chain: Array[PlacedRoom], treasure: PlacedRoom,
		rng: RandomNumberGenerator, taken: Dictionary) -> Vector2i:
	if treasure != null and not treasure.template.chest_slots.is_empty():
		return treasure.to_section_cells(treasure.template.chest_slots)[0]
	var later_rooms: Array[PlacedRoom] = chain.slice(1)
	return _random_free_cell(grid, later_rooms, rng, taken)


## Up to count free floor cells, starting at the given cell and spreading outwards.
func _free_cells_near(grid: LevelGrid, start: Vector2i, count: int, taken: Dictionary) -> Array[Vector2i]:
	var found: Array[Vector2i] = []
	var seen: Dictionary = {start: true}
	var queue: Array[Vector2i] = [start]
	var head: int = 0
	while head < queue.size() and found.size() < count:
		var cell: Vector2i = queue[head]
		head += 1
		if grid.is_floor(cell) and not taken.has(cell):
			found.append(cell)
		for step: Vector2i in LevelGrid.NEIGHBOURS:
			var next: Vector2i = cell + step
			if grid.is_floor(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return found


## A random free floor cell inside one of the rooms (used when slots run out).
func _random_free_cell(grid: LevelGrid, rooms: Array[PlacedRoom], rng: RandomNumberGenerator, taken: Dictionary) -> Vector2i:
	var room: PlacedRoom = rooms[0]
	for _i in RANDOM_CELL_TRIES:
		room = rooms[rng.randi_range(0, rooms.size() - 1)]
		var rect: Rect2i = room.get_rect().grow(-2)
		var cell: Vector2i = Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1),
				rng.randi_range(rect.position.y, rect.end.y - 1))
		if grid.is_floor(cell) and not taken.has(cell):
			return cell
	return room.get_rect().get_center()


## Fisher-Yates shuffle driven by the section generator (Array.shuffle() would use
## the global random generator and break determinism).
func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
