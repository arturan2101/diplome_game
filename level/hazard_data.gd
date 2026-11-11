class_name HazardData
extends Resource
## Numbers for floor hazards, shared by the player and enemies.

## Damage of spikes when stepping on them and then every spikes_interval.
@export var spikes_damage: int = 8
## Seconds between spike hits while standing on spikes.
@export var spikes_interval: float = 0.5
## Share of max HP lost by falling into a pit.
@export_range(0.0, 1.0) var pit_damage_fraction: float = 0.3
## Seconds between falling and reappearing on a safe tile.
@export var fall_delay: float = 0.5
