class_name EnemyCatalog
extends Resource
## List of every enemy type the game can spawn. The director picks from it by
## danger cost, the level spawns from it by id.

@export var enemies: Array[EnemyData] = []


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
