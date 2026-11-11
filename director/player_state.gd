class_name PlayerState
extends RefCounted
## What a director knows when it plans the next section: where the run is and how
## the player has been doing. Built by the game from GameManager and Telemetry;
## plain data, so directors can be tested without the game.

## Index of the section being planned, starting at 0.
var section_index: int = 0
var depth: int = 0
## Player HP as a share of max HP, 0-1, at the moment of planning.
var hp_fraction: float = 1.0
## How many weapons the player carries (a chest is useful while it is below 2).
var weapon_count: int = 1
## Generator for the director's own random choices about this section
## (GameManager.make_director_rng(section_index)).
var rng: RandomNumberGenerator = RandomNumberGenerator.new()
## Estimated skill S, 0-1 (smoothed result of past sections).
var skill: float = 0.4
## Result p (0-1) of each finished section of this run, oldest first.
var results: Array[float] = []
## Phase of each finished section of this run, oldest first.
var phases: Array[StringName] = []
## Damage taken in the last finished sections, by source id (enemy type or hazard).
var recent_damage: Dictionary = {}
## Share of attacks made with each weapon id in the last finished section.
var weapon_use: Dictionary = {}
