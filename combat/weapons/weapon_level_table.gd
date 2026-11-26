class_name WeaponLevelTable
extends Resource
## Chances of each level for a weapon found in a chest or sold by a merchant, by depth
## (after stage 49: a weapon no longer grows with the player, it is found at its level).
## Row d of weights_by_depth holds the weights of level 1, 2, 3... at depth d (counted
## from 0); deeper than the last row, the last row is used. Weights need not sum to 100.

@export var weights_by_depth: Array[PackedFloat32Array] = []


## Weights of the levels at this depth (empty if the table is empty).
func weights_at(depth: int) -> PackedFloat32Array:
	if weights_by_depth.is_empty():
		return PackedFloat32Array()
	return weights_by_depth[clampi(depth, 0, weights_by_depth.size() - 1)]


## Chance (0-1) of this level (1 = the first) at this depth.
func chance(level: int, depth: int) -> float:
	var weights: PackedFloat32Array = weights_at(depth)
	var total: float = 0.0
	for weight: float in weights:
		total += weight
	if total <= 0.0 or level < 1 or level > weights.size():
		return 0.0
	return weights[level - 1] / total


## A random level (1 or more) for a weapon found at this depth; 1 if the table is
## empty. Always draws one number from rng (the section's loot or shop stream).
func pick(depth: int, rng: RandomNumberGenerator) -> int:
	var weights: PackedFloat32Array = weights_at(depth)
	if weights.is_empty():
		rng.randf()
		return 1
	return maxi(rng.rand_weighted(weights), 0) + 1
