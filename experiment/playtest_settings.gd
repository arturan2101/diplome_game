class_name PlaytestSettings
extends Resource
## How a playtest session runs (experiment/playtest.tres): which game series is
## played, how long each director mode lasts, and the survey after each mode.

## Director modes a player tries, in the order of the first row of the plan.
@export var modes: Array[String] = ["RANDOM", "RULES", "LEARNED"]
## Minutes of play per mode. The block ends at the first gate or death after that.
@export var block_minutes: float = 8.0
## The game series played (the clean series, like the main bot comparison).
@export var config: ExperimentConfig
## The same loadout for every player and block (what the bots play with), so only the
## director differs.
@export var weapon: WeaponData
@export var skill: SkillData
## Asked after every mode, in this order.
@export var questions: Array[SurveyQuestion] = []
