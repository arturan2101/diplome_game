class_name SporeBatData
extends EnemyData
## Numbers of the spore bat (stage 48, SporeBat): it flies over pits and spikes, and
## after its wind-up (rising) it dives at the player and bites on the way.

@export_group("Dive")
## Speed and length of the dive; it bites once when the player is within bite_reach.
@export var dive_speed: float = 170.0
@export var dive_time: float = 0.22
@export var bite_reach: float = 14.0
