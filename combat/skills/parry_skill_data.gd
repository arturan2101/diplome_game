class_name ParrySkillData
extends SkillData
## Parameters of the parry (stage 39): a short window in which a hit from the front is
## turned aside. The attacker is stunned and the player's next hit is a sure critical hit.

## Seconds the parry window lasts after the press.
@export var window: float = 0.5
## Full width of the parried arc in degrees, centred on the look direction.
@export_range(10.0, 360.0) var arc_degrees: float = 180.0
## Wielder speed multiplier during the window.
@export_range(0.0, 1.0) var move_speed_multiplier: float = 0.8
## An attacker closer than stun_range is stunned this long and pushed back (bosses and
## stagger-immune enemies are not).
@export var stun_time: float = 1.2
@export var stun_range: float = 48.0
@export var push_speed: float = 90.0
## After a successful parry: invulnerability (a volley does not hit right after), the
## sure critical hit's time limit and a short cooldown instead of the full one.
@export var invulnerability_after: float = 0.3
@export var sure_crit_time: float = 1.5
@export var success_cooldown: float = 0.3
## A parried projectile (arrow, fireball, boulder) flies back at its shooter (stage 44):
## this many times its damage and speed, hurting these physics layers (enemy_hurtbox).
@export var reflect_damage_multiplier: float = 2.0
@export var reflect_speed_multiplier: float = 1.3
@export_flags_2d_physics var reflect_mask: int = 16
## The flash where the blow was parried (a strip played once), its frames and speed.
@export var flash: Texture2D
@export var flash_frames: int = 4
@export var flash_fps: float = 12.0
## How far in front of the wielder the flash appears, in pixels.
@export var flash_distance: float = 8.0
