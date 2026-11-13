class_name RarityTable
extends Resource
## Chances of each rarity for a weapon found in a chest, by depth.
## Row d of weights_by_depth holds the weights of `rarities` at depth d (depth counted
## from 0); deeper than the last row, the last row is used. Weights need not sum to 100.

@export var rarities: Array[WeaponRarity] = []
@export var weights_by_depth: Array[PackedFloat32Array] = []


## Weights of the rarities at this depth (empty if the table is empty).
func weights_at(depth: int) -> PackedFloat32Array:
	if weights_by_depth.is_empty():
		return PackedFloat32Array()
	return weights_by_depth[clampi(depth, 0, weights_by_depth.size() - 1)]


## Chance (0-1) of the rarity with this index at this depth.
func chance(index: int, depth: int) -> float:
	var weights: PackedFloat32Array = weights_at(depth)
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	if total <= 0.0 or index < 0 or index >= weights.size():
		return 0.0
	return weights[index] / total


## A random rarity for a weapon found at this depth, or null if the table is empty.
## rng is the loot generator of the section, so the same seed gives the same loot.
func pick(depth: int, rng: RandomNumberGenerator) -> WeaponRarity:
	var weights: PackedFloat32Array = weights_at(depth)
	if rarities.is_empty() or weights.size() != rarities.size():
		return null
	var index: int = rng.rand_weighted(weights)
	return rarities[index] if index >= 0 else null
