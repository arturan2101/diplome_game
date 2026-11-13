class_name SpellPool
extends Resource
## Spells that can turn up in a run: offered at shrines and found as scrolls in chests.
## A new spell becomes findable by adding its resource to combat/spells/spell_pool.tres.

@export var spells: Array[SpellData] = []


## count different spells in random order (all of them if the pool is smaller).
func offer(count: int, rng: RandomNumberGenerator) -> Array[SpellData]:
	var left: Array[SpellData] = spells.duplicate()
	var picked: Array[SpellData] = []
	while picked.size() < count and not left.is_empty():
		picked.append(left.pop_at(rng.randi_range(0, left.size() - 1)))
	return picked


## One random spell, or null if the pool is empty.
func pick(rng: RandomNumberGenerator) -> SpellData:
	if spells.is_empty():
		return null
	return spells[rng.randi_range(0, spells.size() - 1)]
