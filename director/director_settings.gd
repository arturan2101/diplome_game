class_name DirectorSettings
extends Resource
## Every tunable number of the skill estimate and of the rule-based director, in one
## place (director/director_settings.tres). The formulas are in docs/design.md,
## "Детали реализации". Values are starting points to be tuned on bot runs.

@export_group("Skill estimate")
## Skill S at the start of a run.
@export_range(0.0, 1.0) var start_skill: float = 0.4
## Smoothing: S = (1 - alpha) * S + alpha * p.
@export_range(0.0, 1.0) var alpha: float = 0.3
## Damage norm per section D_max as a share of max HP (60 at 100 HP).
@export var damage_norm_fraction: float = 0.6
## Weights of the three parts of the section result p (damage, time, kills).
@export var damage_weight: float = 0.5
@export var time_weight: float = 0.25
@export var kills_weight: float = 0.25

@export_group("Danger budget")
## B = round((base + skill_factor * S + depth_factor * depth) * phase multiplier).
@export var budget_base: float = 7.0
@export var budget_skill_factor: float = 12.0
@export var budget_depth_factor: float = 0.5
## A section never gets less than this, except in the rest phase.
@export var min_budget: int = 4

@export_group("Tension wave")
## Budget multipliers of the phases: two build-up sections, a peak, a rest.
@export var build_multipliers: Array[float] = [0.8, 1.0]
@export var peak_multiplier: float = 1.3
@export var rest_multiplier: float = 0.3

@export_group("Frustration guard")
## The next section is forced into the rest phase if HP is below this share...
@export_range(0.0, 1.0) var low_hp_fraction: float = 0.25
## ...or if this many sections in a row had a result p below low_result.
@export var low_result_streak: int = 2
@export_range(0.0, 1.0) var low_result: float = 0.3

@export_group("Section contents")
@export var base_health_packs: int = 1
## One more health pack when HP is below this share.
@export_range(0.0, 1.0) var extra_pack_below_hp: float = 0.5
@export var coins_min: int = 4
@export var coins_max: int = 9
## Cover density in ordinary and in rest sections, 0-1.
@export_range(0.0, 1.0) var cover_density: float = 0.5
@export_range(0.0, 1.0) var rest_cover_density: float = 0.9
## An enemy type that dealt at least this share of recent damage counts as the
## player's problem enemy: fewer of it for a weak player, more for a strong one.
@export_range(0.0, 1.0) var problem_enemy_share: float = 0.5
@export var weak_player_below: float = 0.4
@export var strong_player_above: float = 0.7
@export var problem_enemy_weight_weak: float = 0.4
@export var problem_enemy_weight_strong: float = 1.6

@export_group("Chests and arenas")
## Chance of 0, 1 and 2 chests in a section (usually one).
@export var chest_count_weights: Array[float] = [0.15, 0.65, 0.2]
## Chance that a chest stands in its own side branch (a dead-end treasure room).
@export_range(0.0, 1.0) var chest_branch_chance: float = 0.75
## Rooms of an arena section: lead-in rooms plus the locked room at the end.
@export var arena_rooms: int = 3
## From this budget on, the arena comes in two waves.
@export var arena_two_waves_budget: int = 12

@export_group("Random mode")
## RandomDirector picks the budget uniformly from this range (plus depth growth).
@export var random_budget_min: int = 8
@export var random_budget_max: int = 20
