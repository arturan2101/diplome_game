extends TestCase
## Headless test for the progress between runs (stage 33): the save (shards, skills,
## unlocked spells) survives a reload, shards are spent only when there are enough,
## "everything unlocked" for testing, elite enemies drop shards that the player picks
## up into the progress and the section's log line, and no shards in the clean series.

const GAME_SCENE: String = "res://main/main.tscn"
const TEST_SAVE: String = "user://test_progress.json"
const RUN_SEED: int = 33


func run() -> void:
	_test_save()
	await _test_drops("full", 1)
	await _test_drops("clean", 0)
	Progress.from_dictionary({})


func _test_save() -> void:
	var path_was: String = Progress.save_path
	Progress.save_path = TEST_SAVE
	Progress.persist = true
	Progress.reset()
	Progress.add_shards(7)
	Progress.unlock_spell(&"whirlwind")
	Progress.set_perk_level(&"health", 2)
	var saved: Dictionary = Progress.to_dictionary()
	Progress.from_dictionary({})
	Progress.load_progress()
	check(Progress.shards == 7 and Progress.is_spell_unlocked(&"whirlwind") and not Progress.is_spell_unlocked(&"water")
			and Progress.perk_level(&"health", 3) == 2 and Progress.to_dictionary() == saved,
			"shards, skills and unlocked spells survive a reload")
	check(not Progress.spend_shards(8) and Progress.shards == 7 and Progress.spend_shards(5) and Progress.shards == 2,
			"shards are spent only when there are enough")
	Progress.unlock_all = true
	check(Progress.is_spell_unlocked(&"water") and Progress.perk_level(&"speed", 3) == 3,
			"everything unlocked (testing): every spell open, every skill at its top")
	Progress.unlock_all = false
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SAVE))
	Progress.persist = false
	Progress.save_path = path_was
	Progress.from_dictionary({})


func _test_drops(series: String, expected: int) -> void:
	var write_was: bool = Telemetry.write_enabled
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config(series)
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	game.player.health.max_hp = 100000
	game.player.health.reset()
	var cell: Vector2i = game.level.cell_at(game.player.global_position + Vector2(40.0, 0.0))
	cell = game.level.nearest_floor_cell(cell)
	var elite: Enemy = game.spawn_enemy(game.get_enemy_data(&"skeleton_shield"), cell)
	await physics_frames(2)
	var at: Vector2 = elite.global_position
	elite.health.take_damage(DamageInfo.new(100000, null, &"test"))
	await physics_frames(3)
	var shards: Array[Node] = game.find_children("*", "Shard", true, false)
	check(shards.size() == expected, "%s series: a killed elite drops %d shard(s)" % [series, expected])
	if expected > 0 and not shards.is_empty():
		var before: int = Progress.shards
		game.player.teleport((shards[0] as Node2D).global_position)
		await physics_frames(4)
		var record: Dictionary = Telemetry.end_section(false)
		check(Progress.shards == before + 1 and Progress.run_shards >= 1 and int(record.get("shards", -1)) == 1,
				"picking a shard up adds it to the progress and to the section's log line")
	check(at != Vector2.ZERO, "the elite stood on the floor")
	game.queue_free()
	Telemetry.write_enabled = write_was
	GameManager.config = GameManager.DEFAULT_CONFIG
	await physics_frames(3)
