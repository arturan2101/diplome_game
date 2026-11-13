class_name ExperimentConfig
extends Resource
## Which parts of the game a run includes. One .tres per experiment series in
## res://experiment/ (full.tres: the whole game, clean.tres: plain sections for the
## main comparison of the directors). The active one is GameManager.config; every log
## line carries its name and switches, so the analysis can tell the series apart.

## Name written to the log, e.g. "full" or "clean".
@export var series: String = "full"
## The Guardian of the Ruins on the arena of every second depth.
@export var boss_enabled: bool = true
## Shrines, spell scrolls in chests and the spell reward after the boss.
@export var spells_enabled: bool = true
## Rare and legendary weapons in chests; when off every found weapon is common.
@export var rarity_enabled: bool = true


## The switches as plain data for the log.
func to_dictionary() -> Dictionary:
	return {"boss": boss_enabled, "spells": spells_enabled, "rarity": rarity_enabled}
