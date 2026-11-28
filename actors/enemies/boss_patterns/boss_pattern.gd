class_name BossPattern
extends Resource
## One room-wide attack pattern of a boss (stage 50): rays from the boss, arms sweeping
## round the room, a field of floor cells. Every pattern first shows exactly where it
## will hurt (a warning on the floor for warn_time), then strikes there; the rest of the
## floor stays safe. A subclass places its BossHazard nodes in cast(); the hazards do
## the timing, drawing and damage, and tell the bots where danger is coming
## (BossHazard.threatens).

## Seconds the warning shows before the strike.
@export var warn_time: float = 0.8
## Damage of one hit (times the boss's damage multiplier) and how hard it pushes.
@export var damage: int = 12
@export var knockback: float = 140.0
## Played when the warning appears and when the strike lands (Sound ids).
@export var warn_sound: StringName = &""
@export var strike_sound: StringName = &""
@export_group("Boss")
## The boss's animation while it casts the pattern ("<name>_<dir>"): its wind-up, then
## held on the last frame while the pattern plays. Empty = the boss's plain attack.
@export var cast_animation: String = ""
## The boss first walks back to where it woke (the middle of its arena) and casts from
## there: a sweep round the whole room.
@export var cast_at_home: bool = false
@export_group("Look")
## The warning on the floor: a strip of 16x16 frames (a crack along a line, a lit cell).
## Without it a band in warn_color is drawn.
@export var warn_texture: Texture2D
@export var warn_frames: int = 2
@export var warn_fps: float = 6.0
@export var warn_color: Color = Color(0.42, 0.88, 0.75, 0.45)
## What strikes: a strip of 16x16 frames (a vine segment, a spore burst), and for a
## line its tip. Without it a band in strike_color is drawn.
@export var strike_texture: Texture2D
@export var strike_frames: int = 4
@export var strike_fps: float = 10.0
@export var tip_texture: Texture2D
@export var strike_color: Color = Color(0.48, 0.29, 0.17, 1.0)
## A flash of square frames centred where a line ends while it strikes (a beam meeting
## the wall); null = none.
@export var end_texture: Texture2D
@export var end_frames: int = 4
@export var end_fps: float = 12.0


## Places the pattern's hazards under host, from origin (the boss), aimed with target
## (the player's position). damage_scale: the boss's damage multiplier; target_mask:
## physics layers it hurts (player_hurtbox); rng: the gameplay stream. Returns the hazards.
func cast(_host: Node, _origin: Vector2, _target: Vector2, _caster: Node, _source_id: StringName,
		_damage_scale: float, _target_mask: int, _rng: RandomNumberGenerator) -> Array[BossHazard]:
	return []


## Seconds from cast() until the last hazard has struck (the boss waits that long).
func get_duration() -> float:
	return warn_time


## The hit of one strike after the boss's depth scaling.
func scaled_damage(damage_scale: float) -> int:
	return maxi(1, roundi(damage * damage_scale))
