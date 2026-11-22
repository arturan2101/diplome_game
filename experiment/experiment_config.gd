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
## Merging two spells at the top level into a new one at the merchant (stage 26).
## Needs spells. Off in the clean series and the playtest.
@export var spell_fusion: bool = true
## Every depth harder than the one before, whatever the player can do (stage 28): a
## budget floor growing with depth for every director, enemies growing faster
## (DirectorSettings.depth_pressure). Off in the clean series and the playtest.
@export var depth_pressure: bool = true
## Enemy types added after the comparison series: the stone golem (stage 29), the ghost.
## Off in the clean series and the playtest.
@export var extra_enemies: bool = true
## Progress between runs (stage 33 on): ruin shards from elite enemies, the golem and
## the boss, the camp's permanent skills and spell unlocks. Off in the clean series
## and the playtest.
@export var meta_progression: bool = true
## Tuning of the full game after the author's playtest (stage 38): fewer health packs
## and coins, a dearer shop, cover not in neat rows, no chest opened next to enemies
## that chase the player, no secret wall broken before its room's fight is over. Off in
## the clean series and the playtest.
@export var full_game_tuning: bool = true
## Batch 8 (stage 39): weapon levels that grow after every boss, critical hits, the
## spear, the daggers and the crossbow in chests and the shop, parry and teleport as
## basic skills. Off in the clean series and the playtest.
@export var arsenal: bool = true
## Floors of different styles by depth (stage 42): ruins, flooded ruins, fire ruins,
## one style for every two depths. Only the look changes (tiles, deep water or lava in
## the pits, floor decals, a banner); the sections are built the same. Off in the clean
## series and the playtest.
@export var floor_styles: bool = true
## Goods of the merchant (stage 42): whetstone (the weapon in hand gains a level), heart
## elixir (+max HP), lucky charm (rarer chest weapons), rune key (the next secret room
## opens by itself) and dice (new goods). Off in the clean series and the playtest.
@export var shop_goods: bool = true
## Stage 43: until the first boss falls, a legendary weapon is rare in every chest and
## shop whatever the chest luck (Game.early_legendary_chance); the fallen boss leaves a
## chest with a rare or legendary weapon (Game.boss_rarity_table). Needs the boss. Off
## in the clean series and the playtest.
@export var boss_chest: bool = true
## Stage 45: the boss of the flooded floors is the Tide Warden, of the fire floors the
## Molten Warden (their own throws, rings, summons and a special attack: geysers,
## meteors). Needs the boss and floor styles. Off in the clean series and the playtest.
@export var elemental_bosses: bool = true
## Soft tension waves of the rules director: a peak of x1.15 and a rest of x0.5
## (DirectorSettings.soft_peak_multiplier, soft_rest_multiplier) instead of x1.3 and
## x0.3. The other modes have no wave and do not change.
@export var soft_waves: bool = false


## The switches as plain data for the log.
func to_dictionary() -> Dictionary:
	return {"boss": boss_enabled, "spells": spells_enabled, "rarity": rarity_enabled, "soft_waves": soft_waves,
			"spike_traps": spike_traps, "combat_rooms": combat_rooms, "elite_enemies": elite_enemies,
			"secret_rooms": secret_rooms, "merchant_glade": merchant_glade, "spell_fusion": spell_fusion,
			"depth_pressure": depth_pressure, "extra_enemies": extra_enemies, "meta_progression": meta_progression,
			"full_game_tuning": full_game_tuning, "arsenal": arsenal, "floor_styles": floor_styles, "shop_goods": shop_goods,
			"boss_chest": boss_chest, "elemental_bosses": elemental_bosses}
