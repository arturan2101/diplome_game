extends Node
## Manual preview of the breakable obstacles (stage 47): the real full game; the player
## stands next to an obstacle of the first section and hits it until it breaks; saves
## cover_before.png, cover_hit.png and cover_after.png. Not part of the test suite.
## Usage: godot --path . res://tests/manual/cover_preview.tscn -- <folder>

const GAME_SCENE: PackedScene = preload("res://main/main.tscn")
const SWORD: WeaponData = preload("res://combat/weapons/sword.tres")

var _out_dir: String = "user://cover_preview"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config("full")
	GameManager.start_run(4703)
	var game: Game = GAME_SCENE.instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await _frames(20)
	for enemy: Enemy in game.get_enemies():
		enemy.process_mode = Node.PROCESS_MODE_DISABLED
	game.player.health.make_invulnerable(60.0)
	var target: BreakableCover = null
	for node: Node in game._contents.get_children():
		var cover: BreakableCover = node as BreakableCover
		if cover != null and game.level.grid.is_floor(cover.cells[0] + Vector2i.DOWN):
			target = cover
			break
	if target == null:
		print("no obstacle with floor below")
		get_tree().quit()
		return
	var below: Vector2i = target.cells[0] + Vector2i.DOWN
	game.player.teleport(game.level.cell_center(below))
	await _frames(10)
	await _save("cover_before.png")
	game.player.weapon.try_attack(Vector2.UP)
	game.player.weapon.release_attack(Vector2.UP)
	await _frames(4)
	await _save("cover_hit.png")
	await _frames(40)
	game.player.weapon.try_attack(Vector2.UP)
	game.player.weapon.release_attack(Vector2.UP)
	await _frames(40)
	print("cell now: ", game.level.grid.get_cell(target.cells[0] if is_instance_valid(target) else below + Vector2i.UP), " cover valid: ", is_instance_valid(target),
			" hp: ", target.health.hp if is_instance_valid(target) else -1, " piece: ", game.level.cover_piece(below + Vector2i.UP))
	await _save("cover_after.png")
	get_tree().quit()


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
