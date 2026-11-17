class_name FusionRecipe
extends Resource
## One pair of the fusion table: two spells, both at the top level, merge into a new
## spell at level 1 (stage 26). The order of the two does not matter. The result is a
## spell of its own with levels 1-3; it is never found or sold new, only made here.

@export var first: SpellData
@export var second: SpellData
@export var result: SpellData


## True if this recipe merges these two spells, in either order.
func matches(a: StringName, b: StringName) -> bool:
	if first == null or second == null:
		return false
	return (first.id == a and second.id == b) or (first.id == b and second.id == a)


## Short id for the log: fuse_<result id>.
func get_id() -> String:
	return "fuse_%s" % (result.id if result != null else &"")
