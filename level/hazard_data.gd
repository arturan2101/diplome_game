class_name HazardData
extends Resource
## Numbers for floor hazards, shared by the player and enemies.

## Spikes that are always up (`^` in room maps and the director's static patches).
@export var static_spikes: SpikeTrapData
## Spikes that rise and hide on a cycle (the director's waves across tunnels).
@export var timed_spikes: SpikeTrapData
## Share of max HP lost by falling into a pit.
@export_range(0.0, 1.0) var pit_damage_fraction: float = 0.3
## Seconds between falling and reappearing on a safe tile.
@export var fall_delay: float = 0.5
