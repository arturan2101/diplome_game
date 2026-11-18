extends Node
## Manual preview of the integrated art (stage 30) in the real game, full series: the
## pickups (chest closed and open, coin, potion), a shrine, the gate closed and open, a
## sword swing, the bow drawn and an arrow in flight, the shield raised, a dash. Saves one PNG per view into the folder, then quits.
## Not part of the test suite.
## Usage: godot --path . res://tests/manual/world_art_preview.tscn -- <folder>

const GAME_SCENE: PackedScene = preload("res://main/main.tscn")
const SHRINE_SCENE: PackedScene = preload("res://actors/pickups/shrine.tscn")
const COIN_SCENE: PackedScene = preload("res://actors/pickups/coin.tscn")
const POTION_SCENE: PackedScene = preload("res://actors/pickups/health_pack.tscn")
const CHEST_SCENE: PackedScene = preload("res://actors/pickups/chest.tscn")
const BOW: WeaponData = preload("res://combat/weapons/bow.tres")
const BLOCK: SkillData = preload("res://combat/skills/block.tres")
const DASH: SkillData = preload("res://combat/skills/dash.tres")
const RUN_SEED: int = 5000
const SETTLE_FRAMES: int = 12

var _out_dir: String = "user://world_art_preview"
var _game: Game = null


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config("full")
	GameManager.start_run(RUN_SEED)
	_game = GAME_SCENE.instantiate() as Game
	_game.death_screen_enabled = false
	add_child(_game)
	await _frames(2)
	var player: Player = _game.player
	player.health.max_hp = 100000
	player.health.reset()
	for enemy: Enemy in _game.get_enemies():
		enemy.queue_free()
	# A row of things next to the start: chest, coin, potion, shrine.
	var start: Vector2 = player.global_position
	var cells: Array[Vector2i] = _game.level.free_floor_cells_near(start + Vector2(24.0, 0.0), 2)
	var chest: Chest = CHEST_SCENE.instantiate() as Chest
	var things: Array[Node2D] = [chest, COIN_SCENE.instantiate() as Node2D, POTION_SCENE.instantiate() as Node2D,
			SHRINE_SCENE.instantiate() as Node2D]
	for i in mini(things.size(), cells.size()):
		_game.add_section_node(things[i])
		things[i].global_position = _game.level.cell_center(cells[i])
	await _frames(SETTLE_FRAMES)
	await _save("pickups.png")
	chest._collect(player)
	await _frames(SETTLE_FRAMES)
	await _save("chest_open.png")
	await _swing(player)
	player.add_weapon(BOW)
	player.swap_weapon()
	await _frames(2)
	Input.action_press(&"attack")
	await _frames(30)
	await _save("bow_draw.png")
	await _frames(10)
	Input.action_release(&"attack")
	await _frames(4)
	await _save("arrow.png")
	await _frames(20)
	player.set_skill(BLOCK)
	Input.action_press(&"skill")
	await _frames(12)
	await _save("block.png")
	Input.action_release(&"skill")
	await _frames(30)
	player.set_skill(DASH)
	Input.action_press(&"move_left")
	await _frames(2)
	Input.action_press(&"skill")
	await _frames(4)
	await _save("dash.png")
	Input.action_release(&"skill")
	Input.action_release(&"move_left")
	await _frames(20)
	player.teleport(_game.gate.global_position + Vector2(-40.0, 0.0))
	await _frames(SETTLE_FRAMES)
	await _save("gate_closed.png")
	_game.gate.open()
	await _frames(3)
	await _save("gate_opening.png")
	await _frames(30)
	await _save("gate_open.png")
	GameManager.config = GameManager.DEFAULT_CONFIG
	get_tree().quit()


## A sword swing caught in the middle.
func _swing(player: Player) -> void:
	Input.action_press(&"attack")
	await _frames(3)
	await _save("sword_swing.png")
	Input.action_release(&"attack")
	await _frames(20)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))
