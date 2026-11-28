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
## The stone: an Arrow scene that hurts the player's hurtbox. Null = the boss never
## throws (the Mycelium Mother, stage 48).
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

@export_group("Attack patterns (stage 50)")
## Room-wide patterns (BossPattern) of each phase: one at a time, while the player is
## within pattern_range, picked at random but never the same twice in a row. The boss
## stands still while it plays. Empty phase one = the boss has none (the Wardens); empty
## phase two = phase one's go on.
@export var patterns_phase_one: Array[BossPattern] = []
@export var patterns_phase_two: Array[BossPattern] = []
@export var pattern_range: float = 220.0
## Seconds from the end of one pattern to the next wind-up, by phase; the first waits
## first_pattern_delay after the boss wakes.
@export var pattern_cooldown: float = 3.5
@export var pattern_cooldown_phase_two: float = 2.0
@export var first_pattern_delay: float = 2.0
## Seconds of the wind-up before the pattern's warning shows.
@export var pattern_windup: float = 0.5
## A pattern cast at home (sweeps): the boss walks back to where it woke for at most
## home_walk_time seconds (then casts where it is); within home_reach pixels it is there.
@export var home_walk_time: float = 3.0
@export var home_reach: float = 8.0

@export_group("Burrowing (stage 50)")
## Second phase (the Sun Pharaoh): before each pattern the boss sinks into the floor,
## travels under it and comes up at a new spot to cast from: the middle of its arena for
## a pattern cast at home, else a floor spot within burrow_radius of the middle and at
## least burrow_min_distance from the player. Under the floor nothing can hit it.
@export var burrow_in_phase_two: bool = false
@export var sink_animation: String = "sink"
@export var emerge_animation: String = "emerge"
@export var sink_time: float = 0.6
@export var emerge_time: float = 0.6
@export var burrow_radius: float = 120.0
@export var burrow_min_distance: float = 64.0
@export var sink_sound: StringName = &""
@export var emerge_sound: StringName = &""

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

@export_group("Own animations (stage 48)")
## Animation names ("<name>_<dir>") of the slam and the shockwave for a boss whose art
## names them differently from the Warden's "slam" and "wave"; empty = the Warden's.
@export var slam_animation: String = ""
@export var wave_animation: String = ""

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
