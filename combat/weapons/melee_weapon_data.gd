class_name MeleeWeaponData
extends WeaponData
## Parameters of a melee weapon such as the sword. The behaviour lives in MeleeWeapon.

## Damage dealt to each target hit by one swing.
@export var damage: int = 10
## Hit distance from the wielder's centre, in pixels.
@export var reach: float = 24.0
## Full width of the swing arc in degrees, centred on the attack direction.
@export_range(10.0, 340.0) var arc_degrees: float = 120.0
## How long one swing can hit targets, in seconds.
@export var attack_duration: float = 0.15
## Minimum time between the starts of two swings, in seconds.
@export var cooldown: float = 0.35
