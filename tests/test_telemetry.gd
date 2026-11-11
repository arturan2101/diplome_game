extends TestCase
## Headless test for Telemetry and SkillEstimator: the skill formulas, every field of
## a section record, and the log file (one valid JSON object per line).

const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const SWORD: String = "res://combat/weapons/sword.tres"
const BLOCK: String = "res://combat/skills/block.tres"
const RUN_SEED: int = 99
## Every key a log line must have.
const REQUIRED_KEYS: Array[String] = [
	"session", "run", "mode", "seed", "section", "depth", "phase", "budget", "enemies", "time",
	"t_ref", "damage", "damage_total", "blocked_damage", "hp_exit", "kills_ratio", "weapon_use",
	"skill_uses", "accuracy", "idle_time", "coins", "died", "p", "skill",
]


func run() -> void:
	_test_skill_estimator()
	await _test_section_record()


func _test_skill_estimator() -> void:
	var estimator: SkillEstimator = SkillEstimator.new(DirectorSettings.new())
	check(is_equal_approx(estimator.skill, 0.4), "skill starts at 0.4")
	var result: float = estimator.section_result(30, 100, 20.0, 20.0, 1.0, false)
	check(is_equal_approx(result, 0.75), "p = 0.5*(1 - 30/60) + 0.25*1 + 0.25*1 = 0.75")
	check(is_equal_approx(estimator.update(result), 0.505), "S = 0.7*0.4 + 0.3*0.75 = 0.505")
	check(is_equal_approx(estimator.section_result(90, 100, 40.0, 20.0, 0.5, false), 0.25),
			"damage above the norm gives 0 for damage; slow and half the kills: 0.25*0.5 + 0.25*0.5")
	check(is_equal_approx(estimator.section_result(0, 100, 5.0, 20.0, 1.0, true), 0.0), "death gives p = 0")
	estimator.update(0.0)
	check(is_equal_approx(estimator.skill, 0.3535), "a death pulls the skill down: 0.7*0.505")
	estimator.reset()
	check(is_equal_approx(estimator.skill, 0.4), "reset returns to the starting skill")


func _test_section_record() -> void:
	GameManager.director_mode = GameManager.DirectorMode.RULES
	GameManager.start_run(RUN_SEED)
	var log_path: String = Telemetry.get_log_path()
	if FileAccess.file_exists(log_path):
		DirAccess.remove_absolute(log_path)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = Vector2(-300.0, -300.0)
	add_child(player)
	player.add_weapon(load(SWORD) as WeaponData)
	player.set_skill(load(BLOCK) as SkillData)
	player.health.invulnerability_time = 0.0

	var plan: SectionPlan = SectionPlan.new()
	plan.section_index = 0
	plan.depth = 0
	plan.phase = SectionPlan.PHASE_PEAK
	plan.budget = 7
	var layout: SectionLayout = SectionLayout.new()
	layout.reference_time = 30.0
	for id: StringName in [&"skeleton", &"skeleton", &"archer", &"beetle"]:
		layout.enemies.append({"id": id, "cell": Vector2i.ZERO})
	Telemetry.begin_section(plan, layout, player)

	var attacker: Node2D = Node2D.new()
	attacker.position = player.position + Vector2(20.0, 0.0)
	add_child(attacker)
	player.hurtbox.receive_hit(_hit(10, attacker, &"skeleton"))
	player.hurtbox.receive_hit(_hit(8, attacker, &"archer"))
	player.hurtbox.receive_hit(_hit(10, attacker, &"skeleton"))
	player.health.take_damage(DamageInfo.new(8, null, &"spikes"))
	# A blocked hit: the shield is up and the attacker stands in front.
	player.facing = Vector2.RIGHT
	player.skill.press(Vector2.RIGHT)
	player.hurtbox.receive_hit(_hit(12, attacker, &"skeleton"))
	player.skill.release()
	# Four attacks, three of them hit.
	for hits: int in [1, 2, 0, 1]:
		player.weapon.attack_performed.emit(0, hits)
	for _i in 3:
		Telemetry.record_kill()
	GameManager.add_coins(5)
	await physics_frames(60)
	var record: Dictionary = Telemetry.end_section(false)

	var has_all_keys: bool = true
	for key: String in REQUIRED_KEYS:
		if not record.has(key):
			has_all_keys = false
	check(has_all_keys, "the record has every field of the log format")
	check(record["mode"] == "RULES" and record["seed"] == RUN_SEED and record["section"] == 0 and record["depth"] == 0
			and record["phase"] == "peak" and record["budget"] == 7 and record["session"] == Telemetry.session_id,
			"run and plan fields are copied")
	check(record["enemies"] == {"skeleton": 2, "archer": 1, "beetle": 1}, "enemies are counted by type")
	check(record["damage"] == {"skeleton": 20, "archer": 8, "spikes": 8} and record["damage_total"] == 36,
			"damage is counted by source, hazards included")
	check(record["blocked_damage"] == 12, "blocked damage is counted apart from damage taken")
	check(record["hp_exit"] == 64, "hp_exit is the player's HP at the end")
	check(is_equal_approx(record["kills_ratio"], 0.75), "kills_ratio = 3 of 4")
	check(record["weapon_use"] == {"sword": 1.0} and is_equal_approx(record["accuracy"], 0.75),
			"weapon use and accuracy come from attack_performed (3 of 4 attacks hit)")
	check(record["skill_uses"] == 1 and record["coins"] == 5 and record["died"] == false, "skill uses, coins and death flag")
	check(record["time"] >= 0.9 and record["time"] <= 1.2 and record["idle_time"] >= 0.9 and is_equal_approx(record["t_ref"], 30.0),
			"time and idle time are measured in game seconds")
	check(record["p"] > 0.0 and record["p"] < 1.0 and is_equal_approx(record["skill"], snappedf(Telemetry.estimator.skill, 0.001)),
			"the record carries p and the updated skill")
	check(Telemetry.recent_damage(3) == {&"skeleton": 20, &"archer": 8, &"spikes": 8}, "recent damage is summed for the director")

	# Second section of the same run, ending in death.
	plan.section_index = 1
	Telemetry.begin_section(plan, layout, player)
	player.weapon.attack_performed.emit(0, 0)
	await physics_frames(5)
	var death_record: Dictionary = Telemetry.end_section(true)
	check(death_record["died"] == true and is_equal_approx(death_record["p"], 0.0) and death_record["section"] == 1
			and death_record["weapon_use"] == {"sword": 1.0} and is_equal_approx(death_record["accuracy"], 0.0),
			"a section that ends in death has died = true and p = 0; attacks are not counted twice")
	check(Telemetry.history.size() == 2, "the run history holds both sections")

	var lines: PackedStringArray = FileAccess.get_file_as_string(log_path).strip_edges().split("\n")
	var all_parse: bool = lines.size() == 2
	for line: String in lines:
		var parsed: Variant = JSON.parse_string(line)
		if not parsed is Dictionary:
			all_parse = false
			continue
		for key: String in REQUIRED_KEYS:
			if not (parsed as Dictionary).has(key):
				all_parse = false
	check(all_parse, "the log file has one valid JSON object per section with every field (%s)" % log_path)

	GameManager.start_run(RUN_SEED + 1)
	check(Telemetry.history.is_empty() and is_equal_approx(Telemetry.estimator.skill, Telemetry.settings.start_skill)
			and Telemetry.run_number >= 2, "a new run clears the history and resets the skill")
	DirAccess.remove_absolute(log_path)
	player.queue_free()
	attacker.queue_free()
	await physics_frames(2)


func _hit(amount: int, attacker: Node2D, source_id: StringName) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new(amount, attacker, source_id)
	info.direction = Vector2.LEFT
	return info
