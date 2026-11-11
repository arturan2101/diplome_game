class_name Hurtbox
extends Area2D
## Area that attacks can hit. Forwards every hit to the owner's Health.
## Put it on a hurtbox physics layer (player_hurtbox or enemy_hurtbox).

## Emitted for every hit that Health accepted (not absorbed by invulnerability or death).
## The owner reacts to it, for example by applying info.knockback.
signal hit_received(info: DamageInfo)

## Health that receives the damage, usually a sibling node.
@export var health: Health


func _ready() -> void:
	if health == null:
		push_warning("Hurtbox %s has no Health assigned" % get_path())


## Returns true if the hit was accepted. An absorbed hit (invulnerable or dead owner)
## has no effect at all, not even knockback.
func receive_hit(info: DamageInfo) -> bool:
	if health != null and not health.take_damage(info):
		return false
	hit_received.emit(info)
	return true
