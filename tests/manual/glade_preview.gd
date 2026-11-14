extends Node
## Manual preview of the merchant's glade: the real game in the full series, walked
## through its gates until the glade after the first arena. Saves the glade
## (glade.png) and its shop (glade_shop.png), then quits. Not part of the test suite.
## Usage: godot --path . res://tests/manual/glade_preview.tscn -- <folder>

const GAME_SCENE: PackedScene = preload("res://main/main.tscn")
const RUN_SEED: int = 25
const MAX_GATES: int = 6
const SETTLE_FRAMES: int = 30

var _out_dir: String = "user://glade_preview"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config("full")
	GameManager.start_run(RUN_SEED)
	var game: Game = GAME_SCENE.instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await _frames(2)
	game.player.health.max_hp = 100000
	game.player.health.reset()
	for _gate in MAX_GATES:
		if game.is_in_glade():
			break
		await game._on_gate_entered(game.player)
	if not game.is_in_glade():
		print("No glade reached")
		get_tree().quit()
		return
	var merchants: Array[Node] = game.level.find_children("*", "Merchant", true, false)
	if not merchants.is_empty():
		game.player.teleport((merchants[0] as Node2D).global_position + Vector2(0.0, 40.0))
	await _frames(SETTLE_FRAMES)
	await _save("glade.png")
	GameManager.add_coins(60)
	if not merchants.is_empty():
		(merchants[0] as Merchant).interact(game.player)
	await _save("glade_shop.png")
	game.shop_screen.close()
	GameManager.config = GameManager.DEFAULT_CONFIG
	get_tree().quit()


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))
