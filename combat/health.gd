class_name Health
extends Node
## Hit points of any actor: player, enemies, training dummy.
## Reports changes with signals, so it does not need to know who owns it.

## Emitted after damage is applied; hp is already reduced.
signal damaged(info: DamageInfo)
## Emitted once when hp reaches zero; info describes the killing blow.
signal died(info: DamageInfo)

@export var max_hp: int = 100

var hp: int = 0


func _ready() -> void:
	hp = max_hp


func take_damage(info: DamageInfo) -> void:
	if is_dead() or info.amount <= 0:
		return
	hp = maxi(hp - info.amount, 0)
	damaged.emit(info)
	if hp == 0:
		died.emit(info)


func is_dead() -> bool:
	return hp <= 0


## Restores full health (restored dummy, new run).
func reset() -> void:
	hp = max_hp
