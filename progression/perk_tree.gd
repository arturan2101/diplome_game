class_name PerkTree
extends Resource
## The camp's tree of permanent skills (progression/perks.tres): every PerkData, and
## the rules of buying them with the levels kept in Progress.

@export var perks: Array[PerkData] = []


func get_by_id(perk_id: StringName) -> PerkData:
	for perk: PerkData in perks:
		if perk.id == perk_id:
			return perk
	return null


func level_of(perk: PerkData) -> int:
	return Progress.perk_level(perk.id, perk.max_level())


## True if the next level can be bought now: not at the top, the required skill
## bought, and enough shards.
func can_buy(perk: PerkData) -> bool:
	var level: int = level_of(perk)
	var cost: int = perk.cost_after(level)
	if cost < 0 or cost > Progress.shards:
		return false
	return perk.requires == null or level_of(perk.requires) > 0


## Buys the next level. Returns false (and changes nothing) if it cannot be bought.
func buy(perk: PerkData) -> bool:
	if not can_buy(perk):
		return false
	var level: int = level_of(perk)
	if not Progress.spend_shards(perk.cost_after(level)):
		return false
	Progress.set_perk_level(perk.id, level + 1)
	return true


## The summed value of every bought level of an effect.
func total(effect: PerkData.Effect) -> float:
	var sum: float = 0.0
	for perk: PerkData in perks:
		if perk.effect == effect:
			sum += perk.value_at(level_of(perk))
	return sum


## Levels of every perk bought: {id: level} (for the log and the director).
func levels() -> Dictionary:
	var bought: Dictionary = {}
	for perk: PerkData in perks:
		var level: int = level_of(perk)
		if level > 0:
			bought[perk.id] = level
	return bought
