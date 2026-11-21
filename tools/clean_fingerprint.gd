extends SceneTree
## Fingerprint of the clean series: plans and built sections (no boss, no shrines, no
## spike traps, no floor enemies) for RULES, RANDOM and LEARNED over 240 varied player
## states, one line each, written to the file named by the first user argument. Run on
## two versions of the code to check that a change kept the clean series exactly the
## same; the SHA-256 of the reference output is in docs/progress.md.
## Usage: godot --headless --path . --script res://tools/clean_fingerprint.gd -- <file>


func _init() -> void:
	var settings: DirectorSettings = (load("res://director/director_settings.tres") as DirectorSettings).duplicate() as DirectorSettings
	settings.boss_every_depths = 0
	settings.shrine_chance = 0.0
	settings.set("trap_chance", 0.0)
	for key: String in ["combat_room_chance_peak", "combat_room_chance_build", "combat_room_chance_random"]:
		settings.set(key, 0.0)
	settings.set("elites_enabled", false)
	settings.set("secret_room", null)
	var builder: SectionBuilder = SectionBuilder.new()
	var lines: PackedStringArray = PackedStringArray()
	for mode: String in ["rules", "random", "learned"]:
		var director: Director = RuleDirector.new(null, settings)
		if mode == "random":
			director = RandomDirector.new(null, settings)
		elif mode == "learned":
			director = LearnedDirector.new(null, settings)
		for i in 240:
			var state: PlayerState = PlayerState.new()
			state.section_index = i % 9
			state.depth = i % 7
			state.hp_fraction = float((i * 37) % 100) / 100.0
			state.skill = 0.3 + float((i * 13) % 60) / 100.0
			state.is_depth_end = i % 4 == 3
			state.rng.seed = i * 7919
			for k in i % 5:
				state.results.append(float((i + k) % 10) / 10.0)
				state.phases.append([&"build", &"peak", &"rest"][(i + k) % 3])
			state.recent_damage = {&"skeleton": i % 30, &"archer": (i * 3) % 40, &"pit": i % 7}
			var plan: SectionPlan = director.choose_next(state)
			var data: Dictionary = plan.to_dictionary()
			for key: String in ["traps", "combat_rooms", "combat_waves"]:
				data.erase(key)
			var rng: RandomNumberGenerator = RandomNumberGenerator.new()
			rng.seed = 100003 * i + 17
			var layout: SectionLayout = builder.build(plan, rng)
			lines.append("%s %s | %s | %s | %s" % [mode, JSON.stringify(data), layout.grid.to_text().sha256_text(),
					JSON.stringify(layout.enemies), JSON.stringify(layout.items)])
	var file: FileAccess = FileAccess.open(OS.get_cmdline_user_args()[0], FileAccess.WRITE)
	file.store_string("\n".join(lines))
	file.close()
	quit()
