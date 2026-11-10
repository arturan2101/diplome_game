class_name Weapon
extends Node2D
## Base class for weapon behaviour. The player creates it from WeaponData.weapon_scene,
## calls its methods (downward) and listens to its signals (upward).
## Only the active weapon attacks. The weapon in the other slot is inactive: hidden and
## ignoring input, while its cooldown keeps running. The check lives here, in one place.

## Emitted after every attack (every step of a combo) when its hit window ends.
## step_index is the step in the combo (0 for weapons without a combo);
## hits is how many targets took damage. Telemetry uses it for accuracy.
@warning_ignore("unused_signal")
signal attack_performed(step_index: int, hits: int)

## Parameters of this weapon (a WeaponData subclass).
var data: WeaponData = null
## Actor holding the weapon; becomes DamageInfo.source.
var wielder: Node2D = null
## False while the weapon is in the other slot.
var is_active: bool = true


## Called by the wielder right after creating the weapon, before adding it to the tree.
func setup(weapon_data: WeaponData, weapon_wielder: Node2D) -> void:
	data = weapon_data
	wielder = weapon_wielder


## Called when the attack button is pressed. direction is the aim at that moment.
func try_attack(direction: Vector2) -> void:
	if is_active:
		_on_attack_pressed(direction)


## Called when the attack button is released. direction is the aim at that moment.
func release_attack(direction: Vector2) -> void:
	if is_active:
		_on_attack_released(direction)


## Takes the weapon in hand (true) or puts it away (false). Putting it away cancels
## the attack in progress; cooldowns keep running either way.
func set_active(value: bool) -> void:
	if not value:
		cancel_attack()
	is_active = value
	visible = value


## Stops the attack in progress (sword swing, bow draw, buffered press).
## Damage already dealt stays. Subclasses implement it.
func cancel_attack() -> void:
	pass


## Multiplier for the wielder's movement speed: 1.0 = no effect (a drawn bow slows down).
func get_move_speed_multiplier() -> float:
	return 1.0


## Subclasses react to a press of the attack button here. Only called when active.
func _on_attack_pressed(_direction: Vector2) -> void:
	pass


## Subclasses react to a release of the attack button here. Only called when active.
## Weapons that act on press (sword) ignore it.
func _on_attack_released(_direction: Vector2) -> void:
	pass
