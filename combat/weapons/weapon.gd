class_name Weapon
extends Node2D
## Base class for weapon behaviour. The player creates it from WeaponData.weapon_scene,
## calls its methods (downward) and listens to its signals (upward).

## Emitted when an attack ends. targets_hit is how many targets took damage (for accuracy).
@warning_ignore("unused_signal")
signal attack_finished(targets_hit: int)

## Parameters of this weapon (a WeaponData subclass).
var data: WeaponData = null
## Actor holding the weapon; becomes DamageInfo.source.
var wielder: Node2D = null


## Called by the wielder right after creating the weapon, before adding it to the tree.
func setup(weapon_data: WeaponData, weapon_wielder: Node2D) -> void:
	data = weapon_data
	wielder = weapon_wielder


## Starts an attack towards direction if the weapon is ready. Subclasses implement it.
func try_attack(_direction: Vector2) -> void:
	pass
