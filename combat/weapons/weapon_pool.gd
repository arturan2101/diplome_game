class_name WeaponPool
extends Resource
## Weapons that can be found in chests. A new weapon becomes findable by adding its
## resource to the list in combat/weapons/chest_weapons.tres.

@export var weapons: Array[WeaponData] = []


## A random weapon from the list, or null if the list is empty.
func pick(rng: RandomNumberGenerator) -> WeaponData:
	if weapons.is_empty():
		return null
	return weapons[rng.randi_range(0, weapons.size() - 1)]
