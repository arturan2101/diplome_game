extends TestCase
## Headless test for the camp between runs (stage 34): the map is read with its marks,
## the clearing is open from the start to the arch, the altar and the shelf; the arch,
## the altar and the shelf are stations the player can use; going through the arch
## starts a new run; the menu and the death screen lead to the camp only with the
## progress between runs on.

const CAMP_SCENE: String = "res://camp/camp.tscn"


func run() -> void:
	await _test_camp()
	_test_flow_switch()


func _test_camp() -> void:
	var camp: Camp = (load(CAMP_SCENE) as PackedScene).instantiate() as Camp
	camp.change_scene_on_enter = false
	add_child(camp)
	await physics_frames(3)
	var reached: Dictionary = camp.level.grid.reachable_floor(camp.marks[Camp.MARK_START])
	var all_marks: bool = true
	for mark: String in [Camp.MARK_ENTRANCE, Camp.MARK_FIRE, Camp.MARK_TENT, Camp.MARK_ALTAR, Camp.MARK_SHELF, Camp.MARK_START]:
		if not camp.marks.has(mark):
			all_marks = false
	check(all_marks and reached.has(camp.marks[Camp.MARK_ENTRANCE]) and reached.has(camp.marks[Camp.MARK_ALTAR] + Vector2i.DOWN)
			and reached.has(camp.marks[Camp.MARK_SHELF] + Vector2i.DOWN), "the camp map has every place, all reachable from the start")
	check(not camp.level.grid.paved.is_empty(), "the dirt path is drawn")
	camp.player.teleport(camp.altar.global_position)
	await physics_frames(3)
	check(camp.player.interaction_target == camp.altar and camp.altar.get_prompt() != "", "next to the altar the player can use it")
	var asked: Array[bool] = [false]
	camp.skills_requested.connect(func() -> void: asked[0] = true)
	camp.altar.interact(camp.player)
	check(asked[0], "using the altar asks for the skills")
	var entered: Array[bool] = [false]
	camp.entered_ruins.connect(func() -> void: entered[0] = true)
	var seed_before: int = GameManager.run_seed
	GameManager.forced_seed = seed_before + 1
	camp.entrance.interact(camp.player)
	check(entered[0] and GameManager.run_seed == seed_before + 1 and GameManager.section_index == 0,
			"going through the arch starts a new run")
	GameManager.forced_seed = GameManager.RANDOM_SEED
	camp.queue_free()
	await physics_frames(2)


func _test_flow_switch() -> void:
	check(GameManager.load_config("full").meta_progression and not GameManager.load_config("clean_soft").meta_progression,
			"the camp is part of the full game only (not the clean series or the playtest)")
