extends Node
## Thesis data, registered as the autoload "Telemetry".
## Measures each section while it is played and appends one JSON line per section to
## user://logs/<session>.jsonl. The game scene tells it when a section begins and
## ends; in between it listens to the player's signals itself.
## It also owns the skill estimate, because that is computed from the same numbers
## and written to the same line.
## The log format is fixed (see docs/design.md); the analysis scripts depend on it.

## Emitted after a section's record is complete (and written, if writing is on).
signal section_logged(record: Dictionary)
## Emitted after a playtest survey is recorded.
signal survey_logged(record: Dictionary)

const SETTINGS_PATH: String = "res://director/director_settings.tres"
const LOG_EXTENSION: String = "jsonl"
## Where export_logs() puts the file when the shared Downloads folder cannot be written.
const EXPORT_FALLBACK_DIR: String = "user://export"
## The player counts as idle below this speed, in pixels per second.
const IDLE_SPEED: float = 5.0
## Decimal places kept for times and for shares.
const TIME_STEP: float = 0.1
const SHARE_STEP: float = 0.001

## Folder of the log files. Tests point it somewhere else.
var log_directory: String = "user://logs"
## Switch for writing files (the record is still built and emitted).
var write_enabled: bool = true
## Id of this launch of the game: one log file, possibly several runs.
var session_id: String = ""
## Number of the run inside this session, starting at 1.
var run_number: int = 0
## Playtest: the player's id and the index of the block (set by the Playtest autoload),
## -1 outside a playtest.
var playtest_player: int = -1
var playtest_block: int = -1
## Bot profile playing this run ("weak", "mid", "strong"), empty for a person.
var bot_profile: String = ""
var settings: DirectorSettings = null
var estimator: SkillEstimator = null
var _catalog: EnemyCatalog = null
## Records of the finished sections of the current run, oldest first.
var history: Array[Dictionary] = []

var _is_section_active: bool = false
var _player: Player = null
var _plan: SectionPlan = null
var _reference_time: float = 0.0
var _enemies: Dictionary = {}
var _enemy_total: int = 0
var _kills: int = 0
var _time: float = 0.0
var _idle_time: float = 0.0
var _damage: Dictionary = {}
var _blocked_damage: int = 0
var _attacks: Dictionary = {}
var _attacks_that_hit: int = 0
var _skill_uses: int = 0
## Spell casts and spell damage by spell id, apart from weapon attacks.
var _spell_uses: Dictionary = {}
var _spell_damage: Dictionary = {}
var _coins_at_start: int = 0


func _ready() -> void:
	settings = load(SETTINGS_PATH) as DirectorSettings
	estimator = SkillEstimator.new(settings)
	session_id = _make_session_id()
	GameManager.run_started.connect(_on_run_started)
	_on_run_started()


func _physics_process(delta: float) -> void:
	if not _is_section_active or not is_instance_valid(_player):
		return
	_time += delta
	if _player.velocity.length() < IDLE_SPEED:
		_idle_time += delta


## Starts measuring a section. Called by the game when the player is at the entrance.
func begin_section(plan: SectionPlan, layout: SectionLayout, player: Player) -> void:
	_track(player)
	_plan = plan
	_reference_time = layout.reference_time
	_enemies = layout.count_enemies()
	_enemy_total = layout.enemies.size()
	_kills = 0
	_time = 0.0
	_idle_time = 0.0
	_damage = {}
	_blocked_damage = 0
	_attacks = {}
	_attacks_that_hit = 0
	_skill_uses = 0
	_spell_uses = {}
	_spell_damage = {}
	_coins_at_start = GameManager.coins
	_is_section_active = true


## Called by the game for every enemy the player kills.
func record_kill() -> void:
	if _is_section_active:
		_kills += 1


## Finishes the section: builds its record, updates the skill estimate, writes the
## line. died = the player died in this section. Returns the record.
func end_section(died: bool) -> Dictionary:
	if not _is_section_active:
		return {}
	_is_section_active = false
	var max_hp: int = _player.health.max_hp if is_instance_valid(_player) else 100
	var hp_exit: int = _player.health.hp if is_instance_valid(_player) else 0
	var damage_total: int = 0
	for source: StringName in _damage:
		damage_total += int(_damage[source])
	var kills_ratio: float = 1.0 if _enemy_total == 0 else float(_kills) / float(_enemy_total)
	var result: float = estimator.section_result(damage_total, max_hp, _time, _reference_time, kills_ratio, died,
			_plan.budget, _depth_multiplier(_plan.depth))
	var skill: float = estimator.update(result)
	var in_hand: WeaponData = _weapon_in_hand()
	var record: Dictionary = {
		"session": session_id,
		"run": run_number,
		"mode": GameManager.get_mode_name(),
		"series": GameManager.config.series,
		"config": GameManager.config.to_dictionary(),
		"player": playtest_player,
		"block": playtest_block,
		"bot": bot_profile,
		"seed": GameManager.run_seed,
		"section": _plan.section_index,
		"depth": _plan.depth,
		"phase": String(_plan.phase),
		"budget": _plan.budget,
		"action": _plan.action,
		"context": _rounded(_plan.context),
		"enemies": _string_keys(_enemies),
		"time": snappedf(_time, TIME_STEP),
		"t_ref": snappedf(_reference_time, TIME_STEP),
		"damage": _string_keys(_damage),
		"damage_total": damage_total,
		"blocked_damage": _blocked_damage,
		"hp_exit": hp_exit,
		"kills_ratio": snappedf(kills_ratio, SHARE_STEP),
		"weapon_use": _weapon_shares(),
		"weapon_rarity": String(in_hand.get_rarity().id) if in_hand != null else "",
		"weapon_multiplier": in_hand.get_damage_multiplier() if in_hand != null else 1.0,
		"skill_uses": _skill_uses,
		"spell_uses": _string_keys(_spell_uses),
		"spell_damage": _string_keys(_spell_damage),
		"accuracy": snappedf(_accuracy(), SHARE_STEP),
		"idle_time": snappedf(_idle_time, TIME_STEP),
		"coins": GameManager.coins - _coins_at_start,
		"died": died,
		"p": snappedf(result, SHARE_STEP),
		"skill": snappedf(skill, SHARE_STEP),
	}
	history.append(record)
	if write_enabled:
		_append_line(JSON.stringify(record))
	section_logged.emit(record)
	return record


## Data of the weapon the player holds (null if there is no player or no weapon).
func _weapon_in_hand() -> WeaponData:
	if not is_instance_valid(_player) or _player.weapon == null:
		return null
	return _player.weapon.data


## How much stronger enemies are at this depth: their HP multiplier times their damage
## multiplier. The skill estimate measures damage against danger of this strength.
func _depth_multiplier(depth: int) -> float:
	if _catalog == null:
		_catalog = load(Director.CATALOG_PATH) as EnemyCatalog
	return _catalog.hp_multiplier(depth) * _catalog.damage_multiplier(depth)


## Writes one survey to the log, as a line of type "survey" next to the section lines.
## answers: {question id: 1-5}. Returns the record.
func log_survey(answers: Dictionary, play_time: float, order: Array[String]) -> Dictionary:
	var record: Dictionary = {
		"type": "survey",
		"session": session_id,
		"run": run_number,
		"player": playtest_player,
		"block": playtest_block,
		"mode": GameManager.get_mode_name(),
		"series": GameManager.config.series,
		"order": order,
		"time": snappedf(play_time, TIME_STEP),
		"answers": answers,
	}
	if write_enabled:
		_append_line(JSON.stringify(record))
	survey_logged.emit(record)
	return record


## Copies every log line of this device (all sessions) into one file in target_dir -
## by default the shared Downloads folder - and returns the file's path. If that folder
## cannot be written (no permission on the phone), the file goes to EXPORT_FALLBACK_DIR
## instead. Returns "" if there is nothing to export or nothing could be written.
func export_logs(target_dir: String = "") -> String:
	if target_dir == "":
		if OS.get_name() == "Android":
			# Older Android versions ask the user for access to shared storage.
			OS.request_permissions()
		target_dir = OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	var lines: PackedStringArray = PackedStringArray()
	for file_name: String in DirAccess.get_files_at(log_directory):
		if file_name.get_extension() == LOG_EXTENSION:
			lines.append_array(FileAccess.get_file_as_string(log_directory.path_join(file_name)).split("\n", false))
	if lines.is_empty():
		return ""
	var stamp: String = Time.get_datetime_string_from_system(false, true).replace(":", "-").replace(" ", "_")
	var file_name: String = "ruins_logs_%s.%s" % [stamp, LOG_EXTENSION]
	for directory: String in [target_dir, EXPORT_FALLBACK_DIR]:
		if directory == "":
			continue
		DirAccess.make_dir_recursive_absolute(directory)
		var file: FileAccess = FileAccess.open(directory.path_join(file_name), FileAccess.WRITE)
		if file != null:
			file.store_string("\n".join(lines) + "\n")
			file.close()
			return directory.path_join(file_name)
	return ""


func get_log_path() -> String:
	return log_directory.path_join("%s.%s" % [session_id, LOG_EXTENSION])


## Damage taken in the last `sections` finished sections of this run, by source id.
func recent_damage(sections: int) -> Dictionary:
	var total: Dictionary = {}
	for record: Dictionary in history.slice(maxi(0, history.size() - sections)):
		var damage: Dictionary = record["damage"]
		for source: String in damage:
			total[StringName(source)] = int(total.get(StringName(source), 0)) + int(damage[source])
	return total


func _on_run_started() -> void:
	run_number += 1
	history.clear()
	_is_section_active = false
	if estimator != null:
		estimator.reset()


## Connects to the signals of the player (once per player object).
func _track(player: Player) -> void:
	if player == _player:
		_connect_weapons()
		return
	_player = player
	player.health.damaged.connect(_on_player_damaged)
	if player.hurtbox != null:
		player.hurtbox.hit_blocked.connect(_on_hit_blocked)
	player.weapon_changed.connect(_on_weapon_changed)
	if player.skill != null:
		player.skill.used.connect(_on_skill_used)
	if player.spell_book != null:
		player.spell_book.spell_cast.connect(_on_spell_cast)
		player.spell_book.spell_damage_dealt.connect(_on_spell_damage)
	_connect_weapons()


## Weapons are child nodes of the player; new ones appear when a chest is opened.
func _connect_weapons() -> void:
	for child: Node in _player.get_children():
		var weapon: Weapon = child as Weapon
		if weapon == null:
			continue
		var handler: Callable = _on_attack_performed.bind(weapon.data.id)
		if not weapon.attack_performed.is_connected(handler):
			weapon.attack_performed.connect(handler)


func _on_weapon_changed(_slot: int, _data: WeaponData) -> void:
	_connect_weapons()


func _on_player_damaged(info: DamageInfo) -> void:
	if _is_section_active:
		_damage[info.source_id] = int(_damage.get(info.source_id, 0)) + info.amount


func _on_hit_blocked(info: DamageInfo) -> void:
	if _is_section_active:
		_blocked_damage += info.amount


func _on_attack_performed(_step_index: int, hits: int, weapon_id: StringName) -> void:
	if not _is_section_active:
		return
	_attacks[weapon_id] = int(_attacks.get(weapon_id, 0)) + 1
	if hits > 0:
		_attacks_that_hit += 1


func _on_skill_used() -> void:
	if _is_section_active:
		_skill_uses += 1


func _on_spell_cast(spell_id: StringName) -> void:
	if _is_section_active:
		_spell_uses[spell_id] = int(_spell_uses.get(spell_id, 0)) + 1


func _on_spell_damage(spell_id: StringName, amount: int) -> void:
	if _is_section_active:
		_spell_damage[spell_id] = int(_spell_damage.get(spell_id, 0)) + amount


func _attack_total() -> int:
	var total: int = 0
	for weapon_id: StringName in _attacks:
		total += int(_attacks[weapon_id])
	return total


## Share of attacks (sword swings, arrows) that hit at least one target.
func _accuracy() -> float:
	var total: int = _attack_total()
	return 0.0 if total == 0 else float(_attacks_that_hit) / float(total)


## Share of attacks made with each weapon.
func _weapon_shares() -> Dictionary:
	var shares: Dictionary = {}
	var total: int = _attack_total()
	for weapon_id: StringName in _attacks:
		shares[String(weapon_id)] = snappedf(float(_attacks[weapon_id]) / float(total), SHARE_STEP)
	return shares


## JSON keys must be plain strings.
## Features as a plain array with SHARE_STEP precision, for a short log line.
func _rounded(values: PackedFloat32Array) -> Array:
	var result: Array = []
	for value: float in values:
		result.append(snappedf(value, SHARE_STEP))
	return result


func _string_keys(source: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key: Variant in source:
		result[String(key)] = source[key]
	return result


func _append_line(line: String) -> void:
	DirAccess.make_dir_recursive_absolute(log_directory)
	var path: String = get_log_path()
	var file: FileAccess = FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE)
	if file == null:
		push_error("Telemetry: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return
	file.seek_end()
	file.store_line(line)
	file.close()


## Date, time and a random tail: unique per launch and sortable by time.
func _make_session_id() -> String:
	var random: RandomNumberGenerator = RandomNumberGenerator.new()
	random.randomize()
	var stamp: String = Time.get_datetime_string_from_system().replace("-", "").replace(":", "").replace("T", "_")
	# The process id keeps games started in the same second apart (parallel simulations).
	stamp += "_%d" % OS.get_process_id()
	return "%s_%04x" % [stamp, random.randi_range(0, 0xFFFF)]
