class_name MeleeAttackStep
extends Resource
## One hit of a melee combo. MeleeWeaponData holds a list of these,
## so every hit of a combo can have its own numbers.

## Damage dealt to each target hit by this step.
@export var damage: int = 10
## Hit distance from the wielder's centre, in pixels.
@export var reach: float = 24.0
## Full width of the swing arc in degrees, centred on the attack direction.
@export_range(10.0, 340.0) var arc_degrees: float = 120.0
## How long this step can hit targets, in seconds.
@export var duration: float = 0.12
## Pause after the hit window before the next step can start, in seconds.
@export var recovery: float = 0.15
## Speed in pixels per second given to each target, away from the wielder. 0 = no knockback.
@export var knockback: float = 0.0
