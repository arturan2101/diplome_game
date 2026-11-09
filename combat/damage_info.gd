class_name DamageInfo
extends RefCounted
## One instance of damage: how much and who dealt it.
## Travels weapon -> Hurtbox -> Health -> signals, so telemetry can count damage
## per enemy type and per weapon.

var amount: int = 0
## Node that dealt the damage (the player or an enemy). It may be freed later, so read it right away.
var source: Node = null
## Stable id of what dealt the damage: weapon id (&"sword") or enemy type (&"skeleton").
var source_id: StringName = &""


func _init(damage_amount: int = 0, damage_source: Node = null, damage_source_id: StringName = &"") -> void:
	amount = damage_amount
	source = damage_source
	source_id = damage_source_id
