class_name ShieldSkeletonData
extends EnemyData
## Numbers of the elite skeleton with a shield (ShieldSkeleton).

## The shield covers this arc in front of it (degrees).
@export var shield_arc_degrees: float = 120.0
## How fast the shield turns towards the player, radians per second; it does not
## turn at all while the skeleton swings or recovers.
@export var shield_turn_speed: float = 2.5
