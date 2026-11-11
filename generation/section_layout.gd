class_name SectionLayout
extends RefCounted
## Result of the generator: the tile grid of one section and where things go.
## Pure data; the game scene turns it into a Level, enemies and pickups.

const ITEM_HEALTH_PACK: StringName = &"health_pack"
const ITEM_COIN: StringName = &"coin"
const ITEM_CHEST: StringName = &"chest"

var grid: LevelGrid = null
## Cell where the player starts.
var entrance: Vector2i = Vector2i.ZERO
## Cell of the gate with the portal to the next section.
var exit: Vector2i = Vector2i.ZERO
## One entry per enemy: {"id": StringName, "cell": Vector2i}. Pack members are listed one by one.
var enemies: Array[Dictionary] = []
## One entry per pickup: {"id": StringName (ITEM_*), "cell": Vector2i}.
var items: Array[Dictionary] = []
## Rectangles of the placed rooms in grid cells, main chain first.
var room_rects: Array[Rect2i] = []
## Names of the room templates, in the same order as room_rects.
var room_names: Array[StringName] = []
## Reference time to clear the section, in seconds (the director's T_ref).
var reference_time: float = 0.0
## How many tries the generator needed (1 = first try).
var attempts: int = 1


## Number of enemies per type id.
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


## Everything as text: two layouts are the same section if and only if this matches.
func to_text() -> String:
	var lines: PackedStringArray = PackedStringArray()
	lines.append(grid.to_text())
	lines.append("entrance %s exit %s" % [entrance, exit])
	for entry: Dictionary in enemies:
		lines.append("enemy %s %s" % [entry["id"], entry["cell"]])
	for entry: Dictionary in items:
		lines.append("item %s %s" % [entry["id"], entry["cell"]])
	return "\n".join(lines)
