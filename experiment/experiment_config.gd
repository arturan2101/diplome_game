class_name ExperimentConfig
extends Resource
## Which parts of the game a run includes. One .tres per experiment series in
## res://experiment/ (full.tres: the whole game, clean.tres: plain sections for the
## main comparison of the directors, clean_soft.tres: the same with the soft waves of
## the rules director). The active one is GameManager.config; every log
## line carries its name and switches, so the analysis can tell the series apart.

## Name written to the log, e.g. "full" or "clean".
@export var series: String = "full"
## The Guardian of the Ruins on the arena of every second depth.
@export var boss_enabled: bool = true
## Shrines, spell scrolls in chests and the spell reward after the boss.
@export var spells_enabled: bool = true
## Rare and legendary weapons in chests; when off every found weapon is common.
@export var rarity_enabled: bool = true
## Spike traps the director buys from the danger budget (static patches and timed
## waves). Off in the clean series and the playtest, so their results stay comparable;
## the spikes drawn into room maps are always there.
@export var spike_traps: bool = true
## Combat rooms: a room of an ordinary section locks its doors and sends its enemies in
## waves (stage 23). Off in the clean series and the playtest.
@export var combat_rooms: bool = true
## Elite enemies (shield skeleton, triple-shot archer) from the second depth on.
## Off in the clean series and the playtest.
@export var elite_enemies: bool = true
## The merchant's glade after every arena (stage 25); spells are then bought there: no
## shrines, no spell after the boss, scrolls only in secret chests. Off in the clean
## series and the playtest.
@export var merchant_glade: bool = true
## Secret rooms behind cracked walls (stage 24). Off in the clean series and the playtest.
@export var secret_rooms: bool = true
## Soft tension waves of the rules director: a peak of x1.15 and a rest of x0.5
## (DirectorSettings.soft_peak_multiplier, soft_rest_multiplier) instead of x1.3 and
## x0.3. The other modes have no wave and do not change.
@export var soft_waves: bool = false


## The switches as plain data for the log.
func to_dictionary() -> Dictionary:
	return {"boss": boss_enabled, "spells": spells_enabled, "rarity": rarity_enabled, "soft_waves": soft_waves,
			"spike_traps": spike_traps, "combat_rooms": combat_rooms, "elite_enemies": elite_enemies,
			"secret_rooms": secret_rooms, "merchant_glade": merchant_glade}
