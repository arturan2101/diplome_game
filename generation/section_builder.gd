class_name SectionBuilder
extends RefCounted
## Builds one section from the director's plan:
## 1. lays the rooms out on a coarse 2D grid: the main path is a random walk that never
##    crosses itself (so it can go up, down, left and right, with turns), and side
##    branches (treasure rooms) hang off it,
## 2. picks a room template for every node, walls up unused doors and digs tunnels
##    between the doors that face each other (TunnelCarver),
## 3. fills the rooms: cover, enemies spread over the rooms, chests, health packs and
##    coins, so that hardly any room is empty,
## 4. checks that the gate and every placed thing can be reached from the entrance
##    over plain floor (no pits, no spikes); if not, builds again.
## All randomness comes from the generator passed to build(), so the same seed,
## section index and plan always give the same section.

const CATALOG_PATH: String = "res://actors/enemies/enemy_catalog.tres"
const HAZARD_TAG: StringName = &"hazard"
const SIDES: Array[RoomTemplate.DoorSide] = [
	RoomTemplate.DoorSide.WEST, RoomTemplate.DoorSide.EAST,
	RoomTemplate.DoorSide.NORTH, RoomTemplate.DoorSide.SOUTH,
]
## Empty tiles kept around everything.
const MARGIN: int = 3
## A layout cell is the largest room plus this many tiles; rooms sit somewhere inside
## their cell, so tunnels between neighbours differ in length.
const NODE_GAP: int = 4
## The layout of an ordinary section fits in this many cells (columns, rows): with the
## largest room at 23x15 tiles that is at most about 80x60 tiles. An arena may be larger.
const SECTION_SPAN: Vector2i = Vector2i(3, 3)
const ARENA_SPAN: Vector2i = Vector2i(4, 3)
## A room keeps at least this distance from the border of its layout cell.
const CELL_EDGE: int = 2
const MAX_ATTEMPTS: int = 20
const PATH_TRIES: int = 30
## A room with a tag the director prefers is this many times more likely per tag.
const PREFERRED_TAG_WEIGHT: int = 3
const NEUTRAL_WEIGHT: int = 9
const COINS_PER_SLOT: int = 3
## Reference time added per tunnel, in seconds.
const TUNNEL_REF_TIME: float = 2.5
const RANDOM_CELL_TRIES: int = 60

var _library: RoomLibrary = null
var _catalog: EnemyCatalog = null
## Size of one layout cell in tiles.
var _cell_size: Vector2i = Vector2i.ZERO
## Tunnels to dig: [room_a, side_a, room_b, side_b].
var _links: Array[Array] = []


func _init(library: RoomLibrary = null, catalog: EnemyCatalog = null) -> void:
	_library = library if library != null else RoomLibrary.get_default()
	_catalog = catalog if catalog != null else load(CATALOG_PATH) as EnemyCatalog
	var largest: Vector2i = Vector2i.ZERO
	for template: RoomTemplate in _library.templates:
		largest = Vector2i(maxi(largest.x, template.get_size().x), maxi(largest.y, template.get_size().y))
	_cell_size = largest + Vector2i(NODE_GAP, NODE_GAP)


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
	_links.clear()
	var span: Vector2i = ARENA_SPAN if plan.is_arena else SECTION_SPAN
	var path: Array[PlacedRoom] = _lay_out_path(plan, span, rng)
	var branches: Array[PlacedRoom] = _lay_out_branches(path, plan, span, rng)
	var rooms: Array[PlacedRoom] = path + branches
	_choose_templates(path, branches, plan, rng)
	var size: Vector2i = _move_into_grid(rooms)

	var layout: SectionLayout = SectionLayout.new()
	layout.grid = LevelGrid.new(size.x, size.y)
	layout.path_room_count = path.size()
	var rects: Array[Rect2i] = []
	for i in rooms.size():
		rooms[i].index = i
		_stamp(layout.grid, rooms[i])
		rects.append(rooms[i].get_rect())
		layout.room_rects.append(rooms[i].get_rect())
		layout.room_names.append(rooms[i].template.name)
		layout.reference_time += rooms[i].template.ref_time

	var carver: TunnelCarver = TunnelCarver.new(layout.grid, rects)
	for link: Array in _links:
		carver.carve(_outside(link[0], link[1]), _outside(link[2], link[3]),
				plan.corridor_width, plan.corridor_twist, rng)
		layout.reference_time += TUNNEL_REF_TIME
	carver.smooth()

	var taken: Dictionary = {}
	layout.entrance = _free_spot(layout.grid, path[0], taken)
	taken[layout.entrance] = true
	var last: PlacedRoom = path[path.size() - 1]
	layout.exit = _free_spot(layout.grid, last, taken)
	taken[layout.exit] = true
	if plan.is_arena:
		layout.arena_room = last.index
		for side: RoomTemplate.DoorSide in last.used_doors:
			layout.arena_doors.append_array(last.door_cells(side))
	_place_cover(layout, rooms, plan, rng, taken)
	_place_enemies(layout, path, branches, plan, rng, taken)
	_place_chests(layout, path, branches, plan, rng, taken)
	_place_items(layout, path, branches, plan, rng, taken)
	return layout


# --- layout --------------------------------------------------------------

## The main path: a walk over the coarse grid that never steps on its own cells and
## stays inside span. A walk is kept only if it leaves room for the planned branches.
func _lay_out_path(plan: SectionPlan, span: Vector2i, rng: RandomNumberGenerator) -> Array[PlacedRoom]:
	var count: int = clampi(plan.room_count, 2, span.x * span.y)
	var nodes: Array[Vector2i] = []
	var found: bool = false
	for _try in PATH_TRIES:
		nodes = [Vector2i.ZERO]
		while nodes.size() < count:
			var free: Array[Vector2i] = _free_neighbours(nodes[nodes.size() - 1], nodes, span)
			if free.is_empty():
				break
			nodes.append(free[rng.randi_range(0, free.size() - 1)])
		if nodes.size() == count and _branch_capacity(nodes, span) >= plan.side_branches:
			found = true
			break
	# A walk can corner itself; a snake through the box always fits.
	if not found:
		nodes.clear()
		for i in count:
			var row: int = i / span.x
			var column: int = i % span.x if row % 2 == 0 else span.x - 1 - i % span.x
			nodes.append(Vector2i(column, row))
	var path: Array[PlacedRoom] = []
	for i in count:
		var room: PlacedRoom = PlacedRoom.new()
		room.node = nodes[i]
		path.append(room)
		if i > 0:
			_link(path[i - 1], room)
	return path


## Free layout cells next to the path rooms that may carry a branch (not the first one).
func _branch_capacity(nodes: Array[Vector2i], span: Vector2i) -> int:
	var free: Dictionary = {}
	for i in range(1, nodes.size()):
		for cell: Vector2i in _free_neighbours(nodes[i], nodes, span):
			free[cell] = true
	return free.size()


## Treasure rooms: each hangs off a room of the path (not the first one) that still
## has a free cell next to it.
func _lay_out_branches(path: Array[PlacedRoom], plan: SectionPlan, span: Vector2i,
		rng: RandomNumberGenerator) -> Array[PlacedRoom]:
	var branches: Array[PlacedRoom] = []
	if _library.filter_by_tag(RoomTemplate.TREASURE_TAG).is_empty():
		return branches
	var occupied: Array[Vector2i] = []
	for room: PlacedRoom in path:
		occupied.append(room.node)
	for _i in plan.side_branches:
		var hosts: Array[PlacedRoom] = []
		for i in range(1, path.size()):
			if not _free_neighbours(path[i].node, occupied, span).is_empty():
				hosts.append(path[i])
		if hosts.is_empty():
			break
		var host: PlacedRoom = hosts[rng.randi_range(0, hosts.size() - 1)]
		var free: Array[Vector2i] = _free_neighbours(host.node, occupied, span)
		var branch: PlacedRoom = PlacedRoom.new()
		branch.node = free[rng.randi_range(0, free.size() - 1)]
		branch.is_branch = true
		occupied.append(branch.node)
		branches.append(branch)
		_link(host, branch)
	return branches


## Neighbouring layout cells that are free and keep all cells inside span.
func _free_neighbours(node: Vector2i, occupied: Array[Vector2i], span: Vector2i) -> Array[Vector2i]:
	var low: Vector2i = occupied[0]
	var high: Vector2i = occupied[0]
	for cell: Vector2i in occupied:
		low = low.min(cell)
		high = high.max(cell)
	var free: Array[Vector2i] = []
	for side: RoomTemplate.DoorSide in SIDES:
		var next: Vector2i = node + _door_direction(side)
		if next in occupied:
			continue
		# Cells spanned (inclusive) if this one is added.
		var cells_spanned: Vector2i = high.max(next) - low.min(next) + Vector2i.ONE
		if cells_spanned.x > span.x or cells_spanned.y > span.y:
			continue
		free.append(next)
	return free


## Remembers a tunnel between two rooms in neighbouring layout cells and marks the
## doors that face each other as used.
func _link(from: PlacedRoom, to: PlacedRoom) -> void:
	var side: RoomTemplate.DoorSide = _side_towards(to.node - from.node)
	from.used_doors.append(side)
	to.used_doors.append(_opposite(side))
	_links.append([from, side, to, _opposite(side)])


## A template for every room (it must have all the doors the room uses) and a
## position inside the room's layout cell.
func _choose_templates(path: Array[PlacedRoom], branches: Array[PlacedRoom], plan: SectionPlan,
		rng: RandomNumberGenerator) -> void:
	var ordinary: Array[RoomTemplate] = _library.filter_by_tag(RoomTemplate.TREASURE_TAG, false)
	var treasure: Array[RoomTemplate] = _library.filter_by_tag(RoomTemplate.TREASURE_TAG)
	var previous: RoomTemplate = null
	for i in path.size():
		var candidates: Array[RoomTemplate] = _with_doors(ordinary, path[i].used_doors)
		if plan.is_arena and i == path.size() - 1:
			# The locked fight needs a big room.
			var arenas: Array[RoomTemplate] = []
			for template: RoomTemplate in candidates:
				if template.has_tag(RoomTemplate.ARENA_TAG):
					arenas.append(template)
			if not arenas.is_empty():
				candidates = arenas
		path[i].template = _pick_room(candidates, plan, rng, previous)
		previous = path[i].template
	for branch: PlacedRoom in branches:
		branch.template = _pick_room(_with_doors(treasure, branch.used_doors), plan, rng, null)
	for room: PlacedRoom in path + branches:
		var slack: Vector2i = _cell_size - room.template.get_size() - Vector2i(CELL_EDGE, CELL_EDGE)
		room.origin = room.node * _cell_size + Vector2i(
				rng.randi_range(CELL_EDGE, maxi(CELL_EDGE, slack.x)), rng.randi_range(CELL_EDGE, maxi(CELL_EDGE, slack.y)))


func _with_doors(templates: Array[RoomTemplate], sides: Array[RoomTemplate.DoorSide]) -> Array[RoomTemplate]:
	var result: Array[RoomTemplate] = []
	for template: RoomTemplate in templates:
		if template.has_doors(sides):
			result.append(template)
	if result.is_empty():
		push_error("SectionBuilder: no room template has doors on sides %s" % [sides])
		return templates
	return result


func _pick_room(candidates: Array[RoomTemplate], plan: SectionPlan, rng: RandomNumberGenerator,
		previous: RoomTemplate) -> RoomTemplate:
	var weights: Array[int] = []
	var total: int = 0
	for template: RoomTemplate in candidates:
		# Weights are in thirds: 9 is neutral, a preferred tag triples it, an avoided one cuts it to a third.
		var weight: int = NEUTRAL_WEIGHT
		for tag: StringName in plan.preferred_tags:
			if template.has_tag(tag):
				weight *= PREFERRED_TAG_WEIGHT
		for tag: StringName in plan.avoided_tags:
			if template.has_tag(tag):
				weight = maxi(1, weight / PREFERRED_TAG_WEIGHT)
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


func _side_towards(direction: Vector2i) -> RoomTemplate.DoorSide:
	for side: RoomTemplate.DoorSide in SIDES:
		if _door_direction(side) == direction:
			return side
	return RoomTemplate.DoorSide.EAST


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


## A free floor cell for the player's start or for the gate: just inside one of the
## walled-up doors of the room, or else near the middle of the room.
func _free_spot(grid: LevelGrid, room: PlacedRoom, taken: Dictionary) -> Vector2i:
	for side: RoomTemplate.DoorSide in SIDES:
		if not room.template.has_door(side) or side in room.used_doors:
			continue
		var cell: Vector2i = room.door_cell(side) - _door_direction(side)
		if grid.is_floor(cell) and not taken.has(cell):
			return cell
	var near_middle: Array[Vector2i] = _free_cells_near(grid, room.get_rect().get_center(), 1, taken)
	return near_middle[0] if not near_middle.is_empty() else room.get_rect().get_center()


# --- contents ------------------------------------------------------------

func _place_cover(layout: SectionLayout, rooms: Array[PlacedRoom], plan: SectionPlan,
		rng: RandomNumberGenerator, taken: Dictionary) -> void:
	for room: PlacedRoom in rooms:
		for cell: Vector2i in room.to_section_cells(room.template.cover_slots):
			if rng.randf() < plan.cover_density and not taken.has(cell):
				layout.grid.set_cell(cell, LevelGrid.Cell.COVER)
				taken[cell] = true


## Spreads the enemy spawns over the rooms: first one spawn per room of the path
## (never the first room, where the player starts), then the side branches, then
## round again. In an arena everything goes into the locked room, split into waves.
func _place_enemies(layout: SectionLayout, path: Array[PlacedRoom], branches: Array[PlacedRoom], plan: SectionPlan,
		rng: RandomNumberGenerator, taken: Dictionary) -> void:
	var targets: Array[PlacedRoom] = []
	if plan.is_arena:
		targets.append(path[path.size() - 1])
	else:
		targets = path.slice(1)
		_shuffle(targets, rng)
		var guarded: Array[PlacedRoom] = branches.duplicate()
		_shuffle(guarded, rng)
		targets.append_array(guarded)
	var slots: Dictionary = {}
	for room: PlacedRoom in targets:
		var room_slots: Array[Vector2i] = room.to_section_cells(room.template.enemy_slots)
		_shuffle(room_slots, rng)
		slots[room.index] = room_slots
	var ids: Array = plan.enemy_mix.keys()
	ids.sort()
	var spawns: Array[StringName] = []
	for id: StringName in ids:
		for _i in int(plan.enemy_mix[id]):
			spawns.append(id)
	_shuffle(spawns, rng)
	var waves: int = maxi(1, plan.waves) if plan.is_arena else 1
	for i in spawns.size():
		var data: EnemyData = _catalog.get_by_id(spawns[i])
		if data == null:
			push_warning("SectionBuilder: unknown enemy id %s in the plan" % spawns[i])
			continue
		var room: PlacedRoom = targets[i % targets.size()]
		var room_slots: Array[Vector2i] = slots[room.index]
		var slot: Vector2i = room_slots.pop_back() if not room_slots.is_empty() else _random_free_cell(layout.grid, room, rng, taken)
		var pack_size: int = rng.randi_range(data.pack_min, maxi(data.pack_min, data.pack_max))
		# A pack stays inside its room: not in a doorway (an arena walls those up) nor in a tunnel.
		for cell: Vector2i in _free_cells_near(layout.grid, slot, pack_size, taken, room.get_rect().grow(-1)):
			layout.enemies.append({"id": data.id, "cell": cell, "room": room.index, "wave": i % waves})
			taken[cell] = true


## Chests go into the side branches first, then into rooms of the path that have no
## enemies, then into any room of the path but the first.
func _place_chests(layout: SectionLayout, path: Array[PlacedRoom], branches: Array[PlacedRoom], plan: SectionPlan,
		rng: RandomNumberGenerator, taken: Dictionary) -> void:
	var rooms: Array[PlacedRoom] = branches.duplicate()
	var later: Array[PlacedRoom] = path.slice(1)
	_shuffle(later, rng)
	for room: PlacedRoom in later:
		if not _has_enemies(layout, room):
			rooms.append(room)
	for room: PlacedRoom in later:
		if _has_enemies(layout, room):
			rooms.append(room)
	for i in mini(plan.chests, rooms.size()):
		var room: PlacedRoom = rooms[i]
		var cell: Vector2i = _random_free_cell(layout.grid, room, rng, taken)
		var chest_slots: Array[Vector2i] = room.to_section_cells(room.template.chest_slots)
		if not chest_slots.is_empty() and not taken.has(chest_slots[0]):
			cell = chest_slots[0]
		layout.items.append({"id": SectionLayout.ITEM_CHEST, "cell": cell, "room": room.index})
		taken[cell] = true


## No empty rooms: a room of the path with no enemies, no chest and no hazards gets a
## health pack (while the plan has any) or a heap of coins. What is left of the
## plan's health packs and coins then goes into item slots anywhere.
func _place_items(layout: SectionLayout, path: Array[PlacedRoom], branches: Array[PlacedRoom], plan: SectionPlan,
		rng: RandomNumberGenerator, taken: Dictionary) -> void:
	var packs_left: int = plan.health_packs
	var coins_left: int = plan.coins
	for room: PlacedRoom in path.slice(1):
		if _has_enemies(layout, room) or _has_items(layout, room) or room.template.has_tag(HAZARD_TAG):
			continue
		var slot: Vector2i = _item_slot(layout.grid, room, rng, taken)
		if packs_left > 0:
			packs_left -= 1
			_add_items(layout, SectionLayout.ITEM_HEALTH_PACK, slot, 1, room, taken)
		else:
			# Coins of the plan first; once they are spent this is a small bonus heap.
			var placed: int = _add_items(layout, SectionLayout.ITEM_COIN, slot, COINS_PER_SLOT, room, taken)
			coins_left = maxi(0, coins_left - placed)
	var rooms: Array[PlacedRoom] = path + branches
	while packs_left > 0:
		packs_left -= 1
		var room: PlacedRoom = rooms[rng.randi_range(0, rooms.size() - 1)]
		_add_items(layout, SectionLayout.ITEM_HEALTH_PACK, _item_slot(layout.grid, room, rng, taken), 1, room, taken)
	while coins_left > 0:
		var room: PlacedRoom = rooms[rng.randi_range(0, rooms.size() - 1)]
		var placed: int = _add_items(layout, SectionLayout.ITEM_COIN, _item_slot(layout.grid, room, rng, taken),
				mini(coins_left, COINS_PER_SLOT), room, taken)
		coins_left -= maxi(placed, 1)


## Puts up to count items of one kind around a cell. Returns how many were placed.
func _add_items(layout: SectionLayout, item_id: StringName, slot: Vector2i, count: int, room: PlacedRoom,
		taken: Dictionary) -> int:
	var cells: Array[Vector2i] = _free_cells_near(layout.grid, slot, count, taken)
	for cell: Vector2i in cells:
		layout.items.append({"id": item_id, "cell": cell, "room": room.index})
		taken[cell] = true
	return cells.size()


## A free item slot of the room, or a random free cell in it.
func _item_slot(grid: LevelGrid, room: PlacedRoom, rng: RandomNumberGenerator, taken: Dictionary) -> Vector2i:
	var free_slots: Array[Vector2i] = []
	for cell: Vector2i in room.to_section_cells(room.template.item_slots):
		if not taken.has(cell):
			free_slots.append(cell)
	if free_slots.is_empty():
		return _random_free_cell(grid, room, rng, taken)
	return free_slots[rng.randi_range(0, free_slots.size() - 1)]


func _has_enemies(layout: SectionLayout, room: PlacedRoom) -> bool:
	for entry: Dictionary in layout.enemies:
		if entry["room"] == room.index:
			return true
	return false


func _has_items(layout: SectionLayout, room: PlacedRoom) -> bool:
	for entry: Dictionary in layout.items:
		if entry["room"] == room.index:
			return true
	return false


## Up to count free floor cells, starting at the given cell and spreading outwards.
## With bounds, only cells inside them are used.
func _free_cells_near(grid: LevelGrid, start: Vector2i, count: int, taken: Dictionary,
		bounds: Rect2i = Rect2i()) -> Array[Vector2i]:
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
			if bounds.has_area() and not bounds.has_point(next):
				continue
			if grid.is_floor(next) and not seen.has(next):
				seen[next] = true
				queue.append(next)
	return found


## A random free floor cell inside the room (used when slots run out).
func _random_free_cell(grid: LevelGrid, room: PlacedRoom, rng: RandomNumberGenerator, taken: Dictionary) -> Vector2i:
	var rect: Rect2i = room.get_rect().grow(-2)
	for _i in RANDOM_CELL_TRIES:
		var cell: Vector2i = Vector2i(rng.randi_range(rect.position.x, rect.end.x - 1),
				rng.randi_range(rect.position.y, rect.end.y - 1))
		if grid.is_floor(cell) and not taken.has(cell):
			return cell
	var near_middle: Array[Vector2i] = _free_cells_near(grid, room.get_rect().get_center(), 1, taken)
	return near_middle[0] if not near_middle.is_empty() else room.get_rect().get_center()


## Fisher-Yates shuffle driven by the section generator (Array.shuffle() would use
## the global random generator and break determinism).
func _shuffle(items: Array, rng: RandomNumberGenerator) -> void:
	for i in range(items.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var swap: Variant = items[i]
		items[i] = items[j]
		items[j] = swap
