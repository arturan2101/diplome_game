class_name EnemyData
extends Resource
## Parameters of one enemy type. Enemy reads them; the director will use danger_cost.
## A new enemy type is mostly a new .tres of this class plus a scene.

## Stable id of the type, used as DamageInfo.source_id and in telemetry, e.g. &"skeleton".
@export var id: StringName = &""
@export var display_name: String = ""
## Points of the director's danger budget this enemy costs.
@export var danger_cost: int = 1
@export var max_hp: int = 30
## Movement speed in pixels per second.
@export var move_speed: float = 45.0
## The enemy notices the player within this distance, in pixels.
@export var detection_range: float = 160.0
## The enemy starts its attack when the player is this close, in pixels.
@export var attack_range: float = 18.0
## Telegraph before the hit, in seconds: the enemy stops and lights up, the player can react.
@export var windup: float = 0.4
## Seconds after the attack before the enemy moves again.
@export var recovery: float = 0.6
## How quickly knockback speed fades, in pixels per second squared.
@export var knockback_friction: float = 600.0
## Weapon of this enemy. Its weapon_scene must target the player_hurtbox layer.
@export var weapon: WeaponData
