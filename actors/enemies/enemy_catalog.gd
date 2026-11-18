class_name EnemyCatalog
extends Resource
## List of every enemy type the game can spawn. The director picks from it by
## danger cost, the level spawns from it by id.

@export var enemies: Array[EnemyData] = []
## Enemy HP and damage grow with the depth: multiplier = 1 + growth * depth
## (depth counted from 0).
@export var hp_growth_per_depth: float = 0.15
@export var damage_growth_per_depth: float = 0.1
## The same with the depth pressure of the full game (DirectorSettings.depth_pressure):
## the player's strength has a ceiling (top rarity, spells at level 3), this has none.
@export var pressure_hp_growth_per_depth: float = 0.25
@export var pressure_damage_growth_per_depth: float = 0.15


func hp_multiplier(depth: int, pressure: bool = false) -> float:
	return 1.0 + (pressure_hp_growth_per_depth if pressure else hp_growth_per_depth) * depth


func damage_multiplier(depth: int, pressure: bool = false) -> float:
	return 1.0 + (pressure_damage_growth_per_depth if pressure else damage_growth_per_depth) * depth


## Data of the enemy type with this id, or null.
func get_by_id(id: StringName) -> EnemyData:
	for enemy_data: EnemyData in enemies:
		if enemy_data.id == id:
			return enemy_data
	return null


func get_ids() -> Array[StringName]:
	var ids: Array[StringName] = []
	for enemy_data: EnemyData in enemies:
		ids.append(enemy_data.id)
	return ids
