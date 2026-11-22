class_name GuardianData
extends EnemyData
## Numbers of the boss (the Ruins Warden since stage 41; the class keeps its old name). The EnemyData part describes its
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

## Where the special attack's strikes fall (stage 45): in a line from the boss towards
## the player (geysers), or on the player and around them (meteors).
enum SpecialPattern { LINE, AROUND_TARGET }

@export_group("Element (stage 45)")
## A patch the slam leaves in front of the boss (the Molten Warden's lava cracks),
## this far ahead; null = none.
@export var slam_zone: ZoneData
@export var slam_zone_distance: float = 20.0
## A ring drawn by the shockwave: a strip of square frames whose ring reaches
## shockwave_ring_art_radius pixels at the end (scaled to shockwave_radius); null = none.
@export var shockwave_ring: Texture2D
@export var shockwave_ring_frames: int = 6
@export var shockwave_ring_fps: float = 14.0
@export var shockwave_ring_art_radius: float = 30.0
## The shockwave also slows the player it hits (the Tide Warden's water); 0 s = no.
@export_range(0.0, 1.0) var shockwave_slow_multiplier: float = 1.0
@export var shockwave_slow_time: float = 0.0

@export_group("Sounds by attack (stage 46)")
## The slam is EnemyData.attack_sound; the thrown projectile lands with throw_land_sound.
@export var throw_sound: StringName = &""
@export var throw_land_sound: StringName = &""
@export var shockwave_sound: StringName = &""
@export var special_sound: StringName = &""
@export var roar_sound: StringName = &""
@export var summon_sound: StringName = &""
## Music while it fights.
@export var boss_music: StringName = &"boss_warden"

@export_group("Special attack (stage 45)")
## The strikes of the special attack: each is a patch that falls after a warning on the
## floor (geyser, meteor). null = the boss has no special attack.
@export var special_zone: ZoneData
## Animation of the special attack ("<name>_<dir>"), with its wind-up and strike frame
## like the other attacks (attack_strike_frame).
@export var special_animation: String = ""
@export var special_pattern: SpecialPattern = SpecialPattern.LINE
## How many strikes; LINE: the distance between them (the first this far from the boss);
## AROUND_TARGET: the first on the player, the rest within special_spread of them.
@export var special_count: int = 4
@export var special_count_phase_two: int = 5
@export var special_spacing: float = 26.0
@export var special_spread: float = 44.0
## Seconds between one strike landing and the next.
@export var special_stagger: float = 0.15
@export var special_windup: float = 0.9
@export var special_cooldown: float = 7.0
## Used when the player is at least special_min_distance and at most special_range away.
@export var special_min_distance: float = 40.0
@export var special_range: float = 170.0
