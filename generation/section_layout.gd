class_name SectionLayout
extends RefCounted
## Result of the generator: the tile grid of one section and where things go.
## Pure data; the game scene turns it into a Level, enemies and pickups.

const ITEM_HEALTH_PACK: StringName = &"health_pack"
const ITEM_COIN: StringName = &"coin"
const ITEM_CHEST: StringName = &"chest"
const ITEM_SHRINE: StringName = &"shrine"
const ITEM_MERCHANT: StringName = &"merchant"

var grid: LevelGrid = null
## Cell where the player starts.
var entrance: Vector2i = Vector2i.ZERO
## Cell of the gate with the portal to the next section.
var exit: Vector2i = Vector2i.ZERO
## One entry per enemy: {"id": StringName, "cell": Vector2i, "room": int, "wave": int}.
## Pack members are listed one by one. wave 0 is there from the start; later waves
## (arena only) appear when the previous one is dead.
var enemies: Array[Dictionary] = []
## One entry per pickup: {"id": StringName (ITEM_*), "cell": Vector2i, "room": int}.
var items: Array[Dictionary] = []
## Rectangles of the placed rooms in grid cells: the main path first, then branches.
var room_rects: Array[Rect2i] = []
## Names of the room templates, in the same order as room_rects.
var room_names: Array[StringName] = []
## How many of the rooms belong to the main path (the rest are side branches).
var path_room_count: int = 0
## Index of the locked room of an arena section in room_rects, -1 otherwise.
var arena_room: int = -1
## Door cells of the arena room that are walled up while the fight goes on.
var arena_doors: Array[Vector2i] = []
## The secret room, or empty: {"crack": the wall cell to break (Vector2i), "front": unit
## vector from the crack towards the room of the path (Vector2i), "rect": its floor
## (Rect2i, still rock in the grid until the crack is broken), "room": index of the room
## of the path it hides behind}. Its items are in items with "secret": true; they appear
## when the room opens, and the way through the section never needs them.
var secret: Dictionary = {}
## Props without collision (the glade): {"prop": index into GladeData.props, "cell": Vector2i}.
var decor: Array[Dictionary] = []
## Combat rooms: {"room": index in room_rects, "doors": Array[Vector2i], "waves": int}.
## Their enemies (the entries with that room) wait until the player walks in.
var combat_rooms: Array[Dictionary] = []
## Spike traps actually placed: trap id -> number of groups (a trap that found no
## place is skipped).
var traps: Dictionary = {}
## Reference time to clear the section, in seconds (the director's T_ref).
var reference_time: float = 0.0
## How many tries the generator needed (1 = first try).
var attempts: int = 1


## Number of enemies per type id (all waves).
func count_enemies() -> Dictionary:
	var counts: Dictionary = {}
	for entry: Dictionary in enemies:
		counts[entry["id"]] = int(counts.get(entry["id"], 0)) + 1
	return counts


func count_items(item_id: StringName) -> int:
	var count: int = 0
	for entry: Dictionary in items:
		if entry["id"] == item_id:
			count += 1
	return count


## Number of waves the enemies come in (1 for ordinary sections).
func wave_count() -> int:
	var last_wave: int = 0
	for entry: Dictionary in enemies:
		last_wave = maxi(last_wave, int(entry["wave"]))
	return last_wave + 1


## Everything as text: two layouts are the same section if and only if this matches.
func to_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(grid.to_text())
	lines.append("entrance %s exit %s arena %d" % [entrance, exit, arena_room])
	for entry: Dictionary in enemies:
		lines.append("enemy %s %s wave %d" % [entry["id"], entry["cell"], entry["wave"]])
	for entry: Dictionary in items:
		lines.append("item %s %s" % [entry["id"], entry["cell"]])
	return "\n".join(lines)
