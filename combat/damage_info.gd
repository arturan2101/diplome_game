class_name DamageInfo
extends RefCounted
## One instance of damage: how much, who dealt it and how hard it pushes.
## Travels weapon -> Hurtbox -> Health -> signals, so telemetry can count damage
## per enemy type and per weapon.

var amount: int = 0
## Node that dealt the damage (the player or an enemy). It may be freed later, so read it right away.
var source: Node = null
## Stable id of what dealt the damage: weapon id (&"sword") or enemy type (&"skeleton").
var source_id: StringName = &""
## Velocity in pixels per second to give the target. Zero for hits without knockback.
var knockback: Vector2 = Vector2.ZERO


func _init(damage_amount: int = 0, damage_source: Node = null, damage_source_id: StringName = &"",
		damage_knockback: Vector2 = Vector2.ZERO) -> void:
	amount = damage_amount
	source = damage_source
	source_id = damage_source_id
	knockback = damage_knockback
