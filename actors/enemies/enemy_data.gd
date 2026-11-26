class_name EnemyData
extends Resource
## Parameters of one enemy type. Enemy reads them; the director uses danger_cost.
## A new enemy type is a new .tres of this class (plus a weapon resource).

## Stable id of the type, used as DamageInfo.source_id and in telemetry, e.g. &"skeleton".
@export var id: StringName = &""
@export var display_name: String = ""
## Picture of the enemy. Empty keeps whatever the enemy scene shows.
@export var sprite: Texture2D
## Animations "<idle|walk>_<down|up|left|right>" (24x24 art). Empty: the enemy shows
## sprite as a still placeholder.
@export var sprite_frames: SpriteFrames
## Scale of the picture (beetles are smaller than a tile).
@export var sprite_scale: float = 1.0
## Row of the frames where the feet stand; -1 = the second-to-last row (the 24x24 and
## 48x48 art). The 96x96 boss stands on row 92.
@export var feet_row: int = -1
## Frame of the attack animation where the blow lands (stage 41): the frames before it
## are the wind-up, stretched over the windup and held on the last one, the rest plays
## when the attack comes. -1 = the whole animation is stretched over the windup.
@export var attack_strike_frame: int = -1
## Radius of the body collision in pixels; the hurtbox is one pixel larger.
@export var body_radius: float = 6.0
## Points of the director's danger budget one spawn of this type costs
## (for pack enemies: the whole pack).
@export var danger_cost: int = 1
## How many enemies one spawn creates (beetles come as a pack). Usually 1 and 1.
@export var pack_min: int = 1
@export var pack_max: int = 1
@export var max_hp: int = 30
## Movement speed in pixels per second.
@export var move_speed: float = 45.0
## The enemy notices the player within this distance, in pixels.
@export var detection_range: float = 160.0
## The enemy starts its attack when the player is this close and visible, in pixels.
@export var attack_range: float = 18.0
## Telegraph before the hit, in seconds: the enemy stops and lights up, the player can react.
@export var windup: float = 0.4
## Seconds after the attack before the enemy moves again.
@export var recovery: float = 0.6
## Ranged enemies step back when the player is closer than this, in pixels. 0 = never.
@export var preferred_distance: float = 0.0
## Longest single step back, in seconds.
@export var retreat_time: float = 0.6
## Seconds before the enemy may step back again.
@export var retreat_cooldown: float = 2.0
## How quickly knockback speed fades, in pixels per second squared.
@export var knockback_friction: float = 600.0
## Seconds between path recalculations while chasing.
@export var repath_interval: float = 0.3
## Weapon of this enemy. Its weapon_scene must target the player_hurtbox layer.
@export var weapon: WeaponData
## Scene created for this enemy type; empty = the common actors/enemies/enemy.tscn.
## A boss with its own behaviour has its own scene.
@export var scene: PackedScene
## Bosses are never bought from the danger budget; the director places them itself.
@export var is_boss: bool = false
## Elite variants (stage 23) are bought only where the series allows them
## (ExperimentConfig.elite_enemies), and only from depth min_depth on (0 = the first).
@export var is_elite: bool = false
## A type added after the comparison series (stage 29 on: the golem, the ghost): bought
## only with DirectorSettings.extra_enemies, from min_depth on.
@export var is_extra: bool = false
## A floor's own enemy (stage 42): bought only on floors of this style (TileTheme.style_id,
## &"flooded", &"fire"), with ExperimentConfig.floor_styles. &"" = any floor.
@export var floor_style: StringName = &""
## Its blow, when it lands, slows the player: walking at hit_slow_multiplier for
## hit_slow_time seconds (the drowned's grip). 0 = no slowing.
@export var hit_slow_multiplier: float = 1.0
@export var hit_slow_time: float = 0.0
## Shown round the player's legs while that slow lasts (a looping strip: the drowned's
## seaweed, the mummy's bandages); null = nothing shown.
@export var hit_slow_mark: Texture2D
@export var hit_slow_mark_frames: int = 4
@export var hit_slow_mark_fps: float = 8.0
## A patch left where it dies (the magma beetle's lava), hurting the player who steps
## in; null = none.
@export var death_zone: ZoneData
## Ruin shards it drops when killed, with the progress between runs on (stage 33).
@export var shard_drop: int = 0

@export_group("Sounds")
## Sound ids (stage 46): assets/audio/sfx/<id>.ogg or its variants <id>_1, _2...; &"" = silent.
## The blow lands (its strike frame), the wind-up starts, it is hurt by the player, it dies.
## Without hurt_sound a weapon hit sounds like a blade or an arrow on flesh.
@export var attack_sound: StringName = &""
@export var windup_sound: StringName = &""
@export var hurt_sound: StringName = &""
@export var death_sound: StringName = &""
@export_group("")
@export var min_depth: int = 0
