extends TestCase
## Headless test for playtests: the order plan, a whole session (three blocks with
## surveys), the player and block in every log line, the survey screen, the end of a
## block at a gate, the hidden menu button after a death, and the log export.
## Scene changes are off: the test runner is the current scene.

const GAME_SCENE: String = "res://main/main.tscn"
const SURVEY_SCENE: String = "res://ui/survey.tscn"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const EXPORT_LOGS: String = "user://test_export_logs"
const EXPORT_OUT: String = "user://test_export_out"
const PLAYER_ID: int = 4

var _surveys: Array[Dictionary] = []


func run() -> void:
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	Playtest.scene_changes_enabled = false
	Telemetry.survey_logged.connect(_on_survey_logged)
	_test_order_plan()
	await _test_session()
	await _test_survey_screen()
	await _test_gate_and_death()
	_test_export()
	Telemetry.survey_logged.disconnect(_on_survey_logged)
	Playtest.cancel()
	Playtest.scene_changes_enabled = true
	Telemetry.write_enabled = write_was
	GameManager.config = GameManager.DEFAULT_CONFIG
	GameManager.director_mode = GameManager.DirectorMode.RULES


func _on_survey_logged(record: Dictionary) -> void:
	_surveys.append(record)


func _test_order_plan() -> void:
	var modes: Array[String] = Playtest.settings.modes
	var orders: Dictionary = {}
	var counts: Dictionary = {}
	for id in range(1, 7):
		var order: Array[GameManager.DirectorMode] = Playtest.order_for(id, modes)
		orders[str(order)] = true
		for position in order.size():
			var key: String = "%d@%d" % [order[position], position]
			counts[key] = int(counts.get(key, 0)) + 1
	var balanced: bool = counts.size() == 9
	for key: String in counts:
		if counts[key] != 2:
			balanced = false
	check(orders.size() == 6 and balanced, "six players get all six orders: every mode twice in every position")
	check(Playtest.order_for(7, modes) == Playtest.order_for(1, modes), "the plan repeats every six players")


func _test_session() -> void:
	var finished: Array[bool] = [false]
	var on_finished: Callable = func() -> void: finished[0] = true
	Playtest.session_finished.connect(on_finished)
	Playtest.start(PLAYER_ID)
	var order: Array[GameManager.DirectorMode] = Playtest.order_for(PLAYER_ID, Playtest.settings.modes)
	check(Playtest.is_active and Playtest.block == 0 and GameManager.director_mode == order[0]
			and GameManager.config == Playtest.settings.config and GameManager.starting_weapon == Playtest.settings.weapon
			and Telemetry.playtest_player == PLAYER_ID and Telemetry.playtest_block == 0,
			"a session starts with the first mode of the player's order, the playtest series and loadout")
	var limit: float = Playtest.settings.block_minutes * 60.0
	Playtest.add_play_time(limit - 1.0)
	var early: bool = Playtest.is_block_over()
	Playtest.add_play_time(2.0)
	check(not early and Playtest.is_block_over(), "a block is over after its minutes of play")
	for block in order.size():
		Playtest.record_survey({"interest": 4, "fatigue": 2})
		Playtest.next_block()
	var last: Dictionary = _surveys.back() if not _surveys.is_empty() else {}
	check(_surveys.size() == 3 and _surveys[0]["type"] == "survey" and _surveys[0]["player"] == PLAYER_ID
			and _surveys[1]["block"] == 1 and _surveys[2]["mode"] == GameManager.DirectorMode.keys()[order[2]]
			and last.get("answers", {}) == {"interest": 4, "fatigue": 2}, "every block's survey goes to the log with player, block and mode")
	check(finished[0] and not Playtest.is_active and Telemetry.playtest_player == -1, "after the third survey the session ends")
	Playtest.session_finished.disconnect(on_finished)

	Playtest.start(PLAYER_ID)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = Vector2(-500.0, -500.0)
	add_child(player)
	await physics_frames(2)
	Telemetry.begin_section(SectionPlan.new(), SectionLayout.new(), player)
	var record: Dictionary = Telemetry.end_section(false)
	check(record.get("player") == PLAYER_ID and record.get("block") == 0, "section lines carry the player id and the block")
	player.queue_free()
	Playtest.cancel()
	await physics_frames(2)


func _test_survey_screen() -> void:
	_surveys.clear()
	Playtest.start(PLAYER_ID)
	var survey: SurveyScreen = (load(SURVEY_SCENE) as PackedScene).instantiate() as SurveyScreen
	var answered: Array[Dictionary] = []
	survey.answered.connect(func(answers: Dictionary) -> void: answered.append(answers))
	add_child(survey)
	await physics_frames(1)
	var buttons: Array[Button] = survey.get_answer_buttons()
	check(buttons.size() == 5 and survey.questions.size() == Playtest.settings.questions.size()
			and survey.header.text.contains("1 из 3"), "the survey shows five answer buttons and only the block number")
	for i in survey.questions.size():
		survey.get_answer_buttons()[(i % 5)].pressed.emit()
	var answers: Dictionary = answered[0] if not answered.is_empty() else {}
	var in_range: bool = answers.size() == survey.questions.size()
	for key: String in answers:
		if int(answers[key]) < 1 or int(answers[key]) > 5:
			in_range = false
	check(in_range and survey.next_panel.visible and _surveys.size() == 1, "after the last answer the survey is logged at once")
	survey.next_button.pressed.emit()
	check(Playtest.block == 1, "the button after the survey starts the next block")
	survey.queue_free()
	Playtest.cancel()
	await physics_frames(2)


func _test_gate_and_death() -> void:
	Playtest.start(PLAYER_ID)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	add_child(game)
	await physics_frames(2)
	var section: int = GameManager.section_index
	Playtest.add_play_time(Playtest.settings.block_minutes * 60.0 + 1.0)
	await game._on_gate_entered(game.player)
	check(GameManager.section_index == section, "when the block's time is up, the gate leads to the survey, not to a new section")
	game.queue_free()
	await physics_frames(3)

	Playtest.cancel()
	Playtest.start(PLAYER_ID)
	game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	add_child(game)
	await physics_frames(2)
	game.player.health.take_damage(DamageInfo.new(1000, null, &"test"))
	await get_tree().create_timer(GameManager.DEATH_SCREEN_DELAY + 0.3).timeout
	check(game.death_screen.panel.visible and not game.death_screen.menu_button.visible,
			"a death inside a block offers a new run but no way to the menu")
	game.queue_free()
	Playtest.cancel()
	await physics_frames(3)


func _test_export() -> void:
	var directory_was: String = Telemetry.log_directory
	Telemetry.log_directory = EXPORT_LOGS
	DirAccess.make_dir_recursive_absolute(EXPORT_LOGS)
	for name: String in ["a.jsonl", "b.jsonl"]:
		var file: FileAccess = FileAccess.open(EXPORT_LOGS.path_join(name), FileAccess.WRITE)
		file.store_string("{\"x\": 1}\n{\"x\": 2}\n")
		file.close()
	var path: String = Telemetry.export_logs(EXPORT_OUT)
	var lines: PackedStringArray = FileAccess.get_file_as_string(path).split("\n", false) if path != "" else PackedStringArray()
	check(path.begins_with(EXPORT_OUT) and lines.size() == 4, "export puts every log line of the device into one file")
	Telemetry.log_directory = directory_was
	for directory: String in [EXPORT_LOGS, EXPORT_OUT]:
		for name: String in DirAccess.get_files_at(directory):
			DirAccess.remove_absolute(directory.path_join(name))
		DirAccess.remove_absolute(directory)
