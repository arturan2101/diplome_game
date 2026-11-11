class_name DamageInfo
extends RefCounted
## One instance of damage: how much, who dealt it, where it comes from and how hard it pushes.
## Travels attacker -> Hurtbox -> Health -> signals, so telemetry can count damage
## per enemy type, weapon and hazard.

var amount: int = 0
## Node that dealt the damage (the player or an enemy), null for hazards.
## It may be freed later, so read it right away.
var source: Node = null
## Stable id of what dealt the damage: weapon id (&"sword"), enemy type (&"skeleton")
## or hazard (&"pit", &"spikes").
var source_id: StringName = &""
## Velocity in pixels per second to give the target. Zero for hits without knockback.
var knockback: Vector2 = Vector2.ZERO
## Unit vector the hit travels along (from the attacker towards the target).
## Zero when unknown (hazards). The shield compares it with the look direction.
var direction: Vector2 = Vector2.ZERO
## True for damage that invulnerability does not absorb (falling into a pit).
var ignores_invulnerability: bool = false


func _init(damage_amount: int = 0, damage_source: Node = null, damage_source_id: StringName = &"",
		damage_knockback: Vector2 = Vector2.ZERO) -> void:
	amount = damage_amount
	source = damage_source
	source_id = damage_source_id
	knockback = damage_knockback
