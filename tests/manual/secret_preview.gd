extends Node
## Manual preview of a secret room: the real game in the full series with a secret room
## (and a wandering merchant) forced into the first sections. Saves three screenshots:
## the player at the crack (secret_crack.png), the room after the wall crumbled
## (secret_open.png) and the merchant's shop (secret_shop.png), then quits.
## Not part of the test suite.
## Usage: godot --path . res://tests/manual/secret_preview.tscn -- <folder>

const GAME_SCENE: PackedScene = preload("res://main/main.tscn")
const FIRST_SEED: int = 24
const SEEDS: int = 8
const SETTLE_FRAMES: int = 8

var _out_dir: String = "user://secret_preview"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config("full")
	var game: Game = null
	for run_seed in range(FIRST_SEED, FIRST_SEED + SEEDS):
		GameManager.start_run(run_seed)
		game = GAME_SCENE.instantiate() as Game
		game.death_screen_enabled = false
		add_child(game)
		await _frames(2)
		var settings: DirectorSettings = game._director.settings.duplicate() as DirectorSettings
		var data: SecretRoomData = settings.secret_room.duplicate() as SecretRoomData
		data.chance = 1.0
		data.merchant_chance = 1.0
		settings.secret_room = data
		game._director.settings = settings
		game._start_section()
		await _frames(2)
		if not game.layout.secret.is_empty():
			break
		game.queue_free()
		game = null
		await _frames(2)
	if game == null:
		print("No secret room found")
		get_tree().quit()
		return
	for enemy: Enemy in game.get_enemies():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.health.max_hp = 100000
	game.player.health.reset()
	GameManager.add_coins(40)
	var crack: Vector2i = game.layout.secret["crack"]
	var front: Vector2i = game.layout.secret["front"]
	game.player.teleport(game.level.cell_center(crack + front * 2))
	await _frames(SETTLE_FRAMES)
	await _save("secret_crack.png")
	game.player.teleport(game.level.cell_center(crack + front))
	await _frames(2)
	game.player.weapon.try_attack(Vector2(-front))
	await _frames(40)
	var room: Rect2i = game.layout.secret["rect"]
	game.player.teleport(game.level.cell_center(crack))
	await _frames(SETTLE_FRAMES * 3)
	await _save("secret_open.png")
	for node: Node in game.level.find_children("*", "Merchant", true, false):
		(node as Merchant).interact(game.player)
		break
	await RenderingServer.frame_post_draw
	await _save("secret_shop.png")
	print("secret room %s, crack %s" % [room, crack])
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
