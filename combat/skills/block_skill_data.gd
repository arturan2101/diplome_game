class_name BlockSkillData
extends SkillData
## Parameters of the shield block: while the shield is up, hits from the front are stopped.

## Full width of the blocked arc in degrees, centred on the look direction.
@export_range(10.0, 360.0) var arc_degrees: float = 120.0
## Wielder speed multiplier while the shield is up.
@export_range(0.0, 1.0) var move_speed_multiplier: float = 0.7
## True: the shield stays up while the button is held (up to max_hold_time).
## False: a press raises it for tap_duration (variant kept for playtests).
@export var hold_mode: bool = true
## Longest time the shield stays up in hold mode, in seconds.
@export var max_hold_time: float = 1.5
## How long the shield stays up in tap mode, in seconds.
@export var tap_duration: float = 0.5
## Speed in pixels per second given to an enemy whose hit was blocked.
@export var push_speed: float = 120.0
## Only attackers closer than this are pushed back (not archers far away), in pixels.
@export var push_range: float = 40.0
