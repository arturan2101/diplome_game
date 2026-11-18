extends Node
## Manual preview of the camp, its skill altar and spell shelf (stages 34-36): saves
## camp.png, skill_tree.png (a few skills bought, the next ones open, the rest locked)
## and spell_shelf.png, then quits.
## The real save is not touched. Not part of the test suite.
## Usage: godot --path . res://tests/manual/skill_tree_preview.tscn -- <folder>

const CAMP_SCENE: PackedScene = preload("res://camp/camp.tscn")
const SETTLE_FRAMES: int = 20

var _out_dir: String = "user://skill_tree_preview"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Progress.persist = false
	Progress.unlock_all = false
	Progress.from_dictionary({"shards": 23, "perks": {"health": 2, "damage": 1, "speed": 1, "start_coins": 3, "coin_magnet": 1}})
	var camp: Camp = CAMP_SCENE.instantiate() as Camp
	camp.change_scene_on_enter = false
	add_child(camp)
	for _i in SETTLE_FRAMES:
		await get_tree().physics_frame
	await _save("camp.png")
	camp.skill_screen.open(camp.perk_tree)
	camp.skill_screen.select(camp.perk_tree.get_by_id(&"armor"))
	await _save("skill_tree.png")
	camp.skill_screen.close()
	camp.shelf_screen.open(camp.spell_pool)
	await _save("spell_shelf.png")
	camp.shelf_screen.close()
	get_tree().quit()


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))
