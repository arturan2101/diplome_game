extends Node
## Playtest sessions with people, registered as the autoload "Playtest".
## The experimenter types the player's id in the hidden menu panel and starts. The
## player then plays one block per director mode - block_minutes of play each, ending
## at the first gate or death after that - and answers the survey after every block.
## The player never learns the mode: the screens only say "block 2 of 3".
## The order of the modes comes from the player's id and the rows of ORDERS: all six
## orders of three modes (a Williams design). With a multiple of six players every mode
## is played first, second and third equally often and follows every other mode
## equally often, so learning and tiredness do not favour any mode.

## The last survey of the session was recorded.
signal session_finished

const SETTINGS: PlaytestSettings = preload("res://experiment/playtest.tres")
const GAME_SCENE: String = "res://main/main.tscn"
const SURVEY_SCENE: String = "res://ui/survey.tscn"
const MENU_SCENE: String = "res://ui/main_menu.tscn"
## Rows of the plan: indexes into settings.modes. Rows 0-2 are a Latin square, rows 3-5
## the same rows reversed.
const ORDERS: Array = [[0, 1, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0], [1, 0, 2], [0, 2, 1]]

var settings: PlaytestSettings = SETTINGS
var is_active: bool = false
var player_id: int = -1
## Director modes of this player, in play order.
var order: Array[GameManager.DirectorMode] = []
## Index of the current block in order, -1 outside a session.
var block: int = -1
## Seconds played in the current block (pauses and menus do not count).
var block_time: float = 0.0
## Tests switch scene changes off: the test runner is the current scene.
var scene_changes_enabled: bool = true


## The modes for this player id, in play order.
static func order_for(id: int, modes: Array[String]) -> Array[GameManager.DirectorMode]:
	var result: Array[GameManager.DirectorMode] = []
	for index: int in ORDERS[posmod(id, ORDERS.size())]:
		result.append(GameManager.DirectorMode[modes[index]])
	return result


## Starts a session for a player: the first block begins at once.
func start(id: int) -> void:
	is_active = true
	player_id = id
	order = order_for(id, settings.modes)
	block = 0
	_begin_block()


## Called by the game every physics frame of play.
func add_play_time(delta: float) -> void:
	if is_active:
		block_time += delta


func is_block_over() -> bool:
	return is_active and block_time >= settings.block_minutes * 60.0


## The block's time is up (the game calls this at a gate or a death): survey time.
func finish_block() -> void:
	if scene_changes_enabled:
		get_tree().change_scene_to_file(SURVEY_SCENE)


## Writes the survey of the current block to the log.
func record_survey(answers: Dictionary) -> Dictionary:
	return Telemetry.log_survey(answers, block_time, order_names())


## After the survey: the next block, or the end of the session.
func next_block() -> void:
	block += 1
	if block < order.size():
		_begin_block()
		return
	is_active = false
	Telemetry.playtest_player = -1
	Telemetry.playtest_block = -1
	session_finished.emit()


func is_last_block() -> bool:
	return block >= order.size() - 1


## After the last survey: back to the main menu.
func return_to_menu() -> void:
	if scene_changes_enabled:
		get_tree().change_scene_to_file(MENU_SCENE)


## Leaves the session (the experimenter went back to the menu).
func cancel() -> void:
	is_active = false
	player_id = -1
	block = -1
	order.clear()
	Telemetry.playtest_player = -1
	Telemetry.playtest_block = -1


func order_names() -> Array[String]:
	var names: Array[String] = []
	for mode: GameManager.DirectorMode in order:
		names.append(GameManager.DirectorMode.keys()[mode])
	return names


func _begin_block() -> void:
	block_time = 0.0
	GameManager.director_mode = order[block]
	GameManager.config = settings.config
	GameManager.forced_seed = GameManager.RANDOM_SEED
	if settings.weapon != null:
		GameManager.starting_weapon = settings.weapon
	if settings.skill != null:
		GameManager.starting_skill = settings.skill
	Telemetry.playtest_player = player_id
	Telemetry.playtest_block = block
	GameManager.start_run()
	if scene_changes_enabled:
		get_tree().change_scene_to_file(GAME_SCENE)
