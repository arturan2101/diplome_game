class_name Hurtbox
extends Area2D
## Area that attacks can hit. Forwards every hit to the owner's Health.
## Put it on a hurtbox physics layer (player_hurtbox or enemy_hurtbox).
## Guards (the shield) can stop a hit before it reaches Health.

## Emitted for every hit that Health accepted (not absorbed, not blocked).
## The owner reacts to it, for example by applying info.knockback.
signal hit_received(info: DamageInfo)
## Emitted when a guard stopped a hit that would otherwise have done damage.
## Telemetry counts info.amount as blocked damage.
signal hit_blocked(info: DamageInfo)

## Health that receives the damage, usually a sibling node.
@export var health: Health

## Callables (info: DamageInfo) -> bool; true means "I blocked this hit".
var _guards: Array[Callable] = []


func _ready() -> void:
	if health == null:
		push_warning("Hurtbox %s has no Health assigned" % get_path())


## Returns true if the hit was accepted. An absorbed hit (invulnerable or dead owner)
## or a blocked hit has no effect at all, not even knockback.
func receive_hit(info: DamageInfo) -> bool:
	if health != null and not health.can_take_damage(info):
		return false
	for guard: Callable in _guards:
		if guard.call(info):
			hit_blocked.emit(info)
			return false
	if health != null:
		health.take_damage(info)
	hit_received.emit(info)
	return true


func add_guard(guard: Callable) -> void:
	_guards.append(guard)


func remove_guard(guard: Callable) -> void:
	_guards.erase(guard)
