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
@export var min_depth: int = 0
