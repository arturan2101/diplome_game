extends Node
## Progress kept between runs (stage 33), registered as the autoload "Progress": ruin
## shards (dropped by elite enemies, the golem and the boss, spent only in the camp),
## the permanent skills bought with them, and the spells unlocked for the runs. Saved
## to SAVE_PATH as JSON after every change.
## For testing the whole game, unlock_all (on in debug builds) makes every spell
## unlocked and every skill bought to its top; nothing is saved for it.
## Tests and simulations turn persist off, so runs never leak into each other.

## Shards changed (new total).
signal shards_changed(shards: int)
## A skill was bought or a spell unlocked.
signal progress_changed

const SAVE_PATH: String = "user://progress.json"
const SAVE_VERSION: int = 1

## Ruin shards owned.
var shards: int = 0
## Shards picked up in the current run (shown on the death screen).
var run_shards: int = 0
## Permanent skills: {skill id: level}.
var perks: Dictionary = {}
## Spells unlocked for the runs, by id.
var unlocked_spells: Array[StringName] = []
## Everything unlocked and bought, for testing; default: on in debug builds.
var unlock_all: bool = OS.is_debug_build()
## Write changes to SAVE_PATH. Off in tests and simulations.
var persist: bool = true
## Where the save lives (tests point it elsewhere).
var save_path: String = SAVE_PATH


func _ready() -> void:
	load_progress()
	GameManager.run_started.connect(_on_run_started)


func add_shards(amount: int) -> void:
	if amount <= 0:
		return
	shards += amount
	run_shards += amount
	shards_changed.emit(shards)
	save_progress()


## Takes the shards if there are enough. Returns false (and takes nothing) if not.
func spend_shards(amount: int) -> bool:
	if amount < 0 or amount > shards:
		return false
	shards -= amount
	shards_changed.emit(shards)
	save_progress()
	return true


func is_spell_unlocked(spell_id: StringName) -> bool:
	return unlock_all or unlocked_spells.has(spell_id)


func unlock_spell(spell_id: StringName) -> void:
	if unlocked_spells.has(spell_id):
		return
	unlocked_spells.append(spell_id)
	progress_changed.emit()
	save_progress()


## Level of a permanent skill; with unlock_all its top level (max_level).
func perk_level(perk_id: StringName, max_level: int = 1) -> int:
	if unlock_all:
		return max_level
	return int(perks.get(perk_id, 0))


func set_perk_level(perk_id: StringName, level: int) -> void:
	perks[perk_id] = level
	progress_changed.emit()
	save_progress()


## Forgets everything (a new save).
func reset() -> void:
	shards = 0
	run_shards = 0
	perks = {}
	unlocked_spells = []
	shards_changed.emit(shards)
	progress_changed.emit()
	save_progress()


func to_dictionary() -> Dictionary:
	var spells: Array[String] = []
	for spell_id: StringName in unlocked_spells:
		spells.append(String(spell_id))
	var perk_levels: Dictionary = {}
	for perk_id: Variant in perks:
		perk_levels[String(perk_id)] = int(perks[perk_id])
	return {"version": SAVE_VERSION, "shards": shards, "perks": perk_levels, "spells": spells}


func from_dictionary(data: Dictionary) -> void:
	shards = maxi(0, int(data.get("shards", 0)))
	perks = {}
	var perk_levels: Variant = data.get("perks", {})
	if perk_levels is Dictionary:
		for perk_id: Variant in perk_levels:
			perks[StringName(str(perk_id))] = int(perk_levels[perk_id])
	unlocked_spells = []
	var spells: Variant = data.get("spells", [])
	if spells is Array:
		for spell_id: Variant in spells:
			unlocked_spells.append(StringName(str(spell_id)))


func save_progress() -> void:
	if not persist:
		return
	var file: FileAccess = FileAccess.open(save_path, FileAccess.WRITE)
	if file == null:
		push_warning("Progress: cannot write %s" % save_path)
		return
	file.store_string(JSON.stringify(to_dictionary(), "\t"))


func load_progress() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if parsed is Dictionary:
		from_dictionary(parsed)
	else:
		push_warning("Progress: %s is not a valid save, starting over" % save_path)


func _on_run_started() -> void:
	run_shards = 0
