class_name GolemData
extends EnemyData
## Numbers of the stone golem (stage 29). The EnemyData part gives its body, speed, HP,
## danger cost and windup; attack_range is how close the player must be for it to start
## the slam. The slam itself is a ring of damage around the golem.

@export_group("Slam")
## Everything inside this radius around the golem is hit when the windup ends.
@export var slam_radius: float = 40.0
@export var slam_damage: int = 20
## Push away from the golem, pixels per second.
@export var slam_knockback: float = 220.0
## Seconds the dust ring of the slam stays drawn.
@export var slam_flash_time: float = 0.3
## Hits do not push or stagger it (its windup cannot be broken).
@export var stagger_immune: bool = true
