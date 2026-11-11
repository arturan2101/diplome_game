class_name SectionPlan
extends RefCounted
## What the director wants the next section to be. The director only fills this in;
## the generator (SectionBuilder) turns it into tiles and placements. Nothing here
## refers to the scene tree, so directors can be tested without the game.

## Phases of the tension wave (RuleDirector) and the marker of the random mode.
const PHASE_BUILD: StringName = &"build"
const PHASE_PEAK: StringName = &"peak"
const PHASE_REST: StringName = &"rest"
const PHASE_RANDOM: StringName = &"random"

var section_index: int = 0
var depth: int = 0
## Tension phase this section belongs to (written to the log).
var phase: StringName = PHASE_BUILD
## Danger budget spent on enemy_mix (written to the log).
var budget: int = 4
## Enemy type id -> number of spawns. One spawn of a pack enemy is the whole pack.
var enemy_mix: Dictionary = {&"skeleton": 2}
## Rooms in the main chain from the entrance to the gate, 3-5.
var room_count: int = 3
## Add a side branch with a treasure room.
var has_side_branch: bool = false
## Put a chest into the section (in the treasure room if there is a branch).
var has_chest: bool = false
## Tunnel width in tiles, 2-4 (doors are always 3 wide).
var corridor_width: int = 3
## How winding tunnels are: 0 = straight, 1 = wandering a lot.
var corridor_twist: float = 0.3
var health_packs: int = 1
## Number of coin pickups.
var coins: int = 6
## Share of cover slots that get cover, 0-1.
var cover_density: float = 0.5
## Room tags the director would like to see more often (e.g. cover, open, hazard).
var preferred_tags: Array[StringName] = []
## Room tags the director would like to see less often.
var avoided_tags: Array[StringName] = []


## Total number of enemy spawns in the plan.
func get_spawn_count() -> int:
	var total: int = 0
	for id: StringName in enemy_mix:
		total += int(enemy_mix[id])
	return total


## Plain data for logs and debugging.
func to_dictionary() -> Dictionary:
	return {
		"section": section_index,
		"depth": depth,
		"phase": String(phase),
		"budget": budget,
		"enemies": enemy_mix.duplicate(),
		"rooms": room_count,
		"branch": has_side_branch,
		"chest": has_chest,
		"corridor_width": corridor_width,
		"corridor_twist": corridor_twist,
		"health_packs": health_packs,
		"coins": coins,
		"cover_density": cover_density,
		"preferred_tags": preferred_tags.duplicate(),
		"avoided_tags": avoided_tags.duplicate(),
	}
