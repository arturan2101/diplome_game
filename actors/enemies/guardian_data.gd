class_name GuardianData
extends EnemyData
## Numbers of the boss, the Guardian of the Ruins. The EnemyData part describes its
## slam (weapon, attack_range, windup, recovery); this adds the thrown stone, the
## second phase with its shockwave, and the servants it calls.

@export_group("Thrown stone")
## Throws when the player keeps at least this far and at most throw_range away.
@export var throw_min_distance: float = 56.0
@export var throw_range: float = 150.0
@export var throw_windup: float = 0.7
@export var throw_cooldown: float = 3.0
@export var throw_damage: int = 12
@export var throw_speed: float = 170.0
## The stone: an Arrow scene that hurts the player's hurtbox.
@export var projectile_scene: PackedScene

@export_group("Second phase")
## The second phase starts at this share of max HP.
@export_range(0.0, 1.0) var phase_two_at: float = 0.5
## Seconds the Guardian stands and roars when the second phase starts.
@export var roar_time: float = 1.0
@export var phase_two_speed_multiplier: float = 1.35
@export var phase_two_recovery_multiplier: float = 0.7

@export_group("Shockwave (second phase)")
## Every second close attack of the second phase is a ring around the Guardian.
@export var shockwave_radius: float = 56.0
@export var shockwave_windup: float = 1.0
@export var shockwave_damage: int = 14
@export var shockwave_knockback: float = 220.0

@export_group("Servants (second phase)")
## Enemy id of the servants, how many come at a time, how often, and at most alive.
@export var summon_id: StringName = &"skeleton"
@export var summon_count: int = 2
@export var summon_interval: float = 9.0
@export var summon_max_alive: int = 4
