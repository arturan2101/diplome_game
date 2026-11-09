class_name Weapon
extends Node2D
## Base class for weapon behaviour. The player creates it from WeaponData.weapon_scene,
## calls its methods (downward) and listens to its signals (upward).

## Emitted after every attack (every step of a combo) when its hit window ends.
## step_index is the step in the combo (0 for weapons without a combo);
## hits is how many targets took damage. Telemetry uses it for accuracy.
@warning_ignore("unused_signal")
signal attack_performed(step_index: int, hits: int)

## Parameters of this weapon (a WeaponData subclass).
var data: WeaponData = null
## Actor holding the weapon; becomes DamageInfo.source.
var wielder: Node2D = null


## Called by the wielder right after creating the weapon, before adding it to the tree.
func setup(weapon_data: WeaponData, weapon_wielder: Node2D) -> void:
	data = weapon_data
	wielder = weapon_wielder


## Called when the attack button is pressed. direction is the aim at that moment.
## Starts an attack if the weapon is ready. Subclasses implement it.
func try_attack(_direction: Vector2) -> void:
	pass


## Called when the attack button is released. direction is the aim at that moment.
## Weapons that act on press (sword) ignore it.
func release_attack(_direction: Vector2) -> void:
	pass


## Multiplier for the wielder's movement speed: 1.0 = no effect (a drawn bow slows down).
func get_move_speed_multiplier() -> float:
	return 1.0
