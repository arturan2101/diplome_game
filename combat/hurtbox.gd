class_name Hurtbox
extends Area2D
## Area that attacks can hit. Forwards every hit to the owner's Health.
## Put it on a hurtbox physics layer (player_hurtbox or enemy_hurtbox).

## Emitted for every hit after the damage is passed to Health.
## The owner reacts to it, for example by applying info.knockback.
signal hit_received(info: DamageInfo)

## Health that receives the damage, usually a sibling node.
@export var health: Health


func _ready() -> void:
	if health == null:
		push_warning("Hurtbox %s has no Health assigned" % get_path())


func receive_hit(info: DamageInfo) -> void:
	if health != null:
		health.take_damage(info)
	hit_received.emit(info)
