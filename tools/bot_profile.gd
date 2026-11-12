class_name BotProfile
extends Resource
## How well a bot plays. Weak, mid and strong bots (tools/bots/*.tres) differ only in
## these numbers, so the director can be compared on players of different skill.

## Name written to the log ("bot" field), e.g. &"mid".
@export var id: StringName = &"mid"
## Seconds before the bot reacts to something new: a new nearest enemy, a windup.
@export var reaction_time: float = 0.35
## Chance to get out of the way of a telegraphed attack it has noticed.
@export_range(0.0, 1.0) var dodge_chance: float = 0.5
## When dodging, chance to use the basic skill (dash away / raise the shield)
## instead of just stepping aside.
@export_range(0.0, 1.0) var skill_use_chance: float = 0.5
## How long a dodge step lasts, in seconds.
@export var dodge_time: float = 0.35
## Chance that an attack is started too early, from out of reach (a wasted swing).
@export_range(0.0, 1.0) var miss_chance: float = 0.15
## Random turn of the movement direction, up to this many degrees, changed every
## jitter_interval seconds.
@export var move_jitter_degrees: float = 15.0
@export var jitter_interval: float = 0.3
## Chance per second to hesitate (stand still) for hesitation_time seconds.
@export var hesitation_chance: float = 0.05
@export var hesitation_time: float = 0.4
## Chance, each time the path is planned, to walk straight to the goal for a while
## instead (and maybe over spikes or into a pit).
@export_range(0.0, 1.0) var hazard_blind_chance: float = 0.08
## The bot goes for a health pack below this share of max HP.
@export_range(0.0, 1.0) var heal_below: float = 0.5
## Melee: attack when the enemy is this close, in pixels.
@export var melee_attack_distance: float = 22.0
## Bow: shoot from at most this far, holding the draw this long, in seconds.
@export var bow_attack_distance: float = 120.0
@export var bow_hold_time: float = 0.6
## Bow: step back when an enemy is closer than this, in pixels (0 = never).
@export var bow_keep_distance: float = 0.0
