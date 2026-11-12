extends TestCase
## Headless test for the screens: main menu (loadout choice, hidden experiment panel),
## HUD, pause, and the death screen with the results of the run.

const MENU_SCENE: String = "res://ui/main_menu.tscn"
const GAME_SCENE: String = "res://main/main.tscn"
const BOW: String = "res://combat/weapons/bow.tres"
const BLOCK: String = "res://combat/skills/block.tres"
const RUN_SEED: int = 31337


func run() -> void:
	await _test_menu()
	_test_forced_seed()
	await _test_hud_pause_and_death()


func _test_menu() -> void:
	var default_weapon: WeaponData = GameManager.starting_weapon
	var default_skill: SkillData = GameManager.starting_skill
	var menu: Control = (load(MENU_SCENE) as PackedScene).instantiate() as Control
	add_child(menu)
	await physics_frames(2)
	check(menu.title_screen.visible and not menu.loadout_screen.visible and not menu.debug_panel.visible,
			"the menu opens on the title screen; the experiment panel is hidden")
	menu.play_button.pressed.emit()
	check(menu.loadout_screen.visible and not menu.title_screen.visible, "Play leads to the loadout choice")
	check(menu.weapon_row.get_child_count() == 2 and menu.skill_row.get_child_count() == 2,
			"there is a button for each starting weapon and each basic skill")
	var bow_button: Button = menu.weapon_row.get_child(1) as Button
	var block_button: Button = menu.skill_row.get_child(1) as Button
	bow_button.pressed.emit()
	block_button.pressed.emit()
	check(menu._selected_weapon == load(BOW) and menu._selected_skill == load(BLOCK),
			"pressing the buttons selects bow and shield block")
	check(bow_button.icon != null and bow_button.text == "Bow", "buttons show the name and icon from the data")

	var toggle: InputEventAction = InputEventAction.new()
	toggle.action = &"debug_menu"
	toggle.pressed = true
	menu._unhandled_input(toggle)
	check(menu.debug_panel.visible, "F1 opens the hidden experiment panel")
	check(menu.mode_option.item_count == 3 and menu.mode_option.get_item_text(0) == "RANDOM",
			"the panel offers RANDOM, RULES and LEARNED")
	var mode_before: int = GameManager.director_mode
	menu.mode_option.item_selected.emit(GameManager.DirectorMode.RANDOM)
	menu.seed_edit.text_changed.emit("4321")
	check(GameManager.director_mode == GameManager.DirectorMode.RANDOM and GameManager.forced_seed == 4321,
			"the panel sets the director mode and the seed")
	menu.seed_edit.text_changed.emit("")
	check(GameManager.forced_seed == GameManager.RANDOM_SEED, "an empty seed field means a random seed")
	GameManager.director_mode = mode_before as GameManager.DirectorMode
	GameManager.starting_weapon = default_weapon
	GameManager.starting_skill = default_skill
	menu.queue_free()
	await physics_frames(2)


func _test_forced_seed() -> void:
	GameManager.forced_seed = 555
	GameManager.start_run()
	var forced_ok: bool = GameManager.run_seed == 555
	GameManager.start_run()
	forced_ok = forced_ok and GameManager.run_seed == 555
	GameManager.forced_seed = GameManager.RANDOM_SEED
	GameManager.start_run()
	var first_random: int = GameManager.run_seed
	GameManager.start_run()
	check(forced_ok and GameManager.run_seed != first_random, "a forced seed repeats every run; without it each run gets a new seed")


func _test_hud_pause_and_death() -> void:
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	add_child(game)
	await physics_frames(3)
	var hud: Hud = game.hud
	check(hud.hp_label.text == "100 / 100" and hud.weapon_icons[0].texture == GameManager.starting_weapon.icon
			and hud.weapon_icons[1].texture == null and hud.skill_icon.texture == GameManager.starting_skill.icon,
			"the HUD shows HP, the weapon in slot 1, an empty slot 2 and the skill")
	game.player.add_weapon(load(BOW) as WeaponData)
	game.player.swap_weapon()
	check(hud.weapon_icons[1].texture != null and hud.weapon_icons[1].modulate == Color.WHITE
			and hud.weapon_icons[0].modulate != Color.WHITE, "the active weapon slot is highlighted after a swap")
	game.player.health.take_damage(DamageInfo.new(30, null, &"test"))
	GameManager.add_coins(7)
	check(hud.hp_label.text == "70 / 100" and hud.coins_label.text == "7", "HP and coins follow the game")
	game.player.skill.press(Vector2.RIGHT)
	await physics_frames(20)
	check(hud.skill_cooldown.anchor_top < 1.0, "the skill icon shows the cooldown")

	game.pause_menu.set_paused(true)
	var paused_ok: bool = get_tree().paused and game.pause_menu.panel.visible
	game.pause_menu.set_paused(false)
	check(paused_ok and not get_tree().paused and not game.pause_menu.panel.visible, "pause stops the game and resume continues it")
	var pause_event: InputEventAction = InputEventAction.new()
	pause_event.action = &"pause"
	pause_event.pressed = true
	game.pause_menu._unhandled_input(pause_event)
	var action_paused: bool = get_tree().paused
	game.pause_menu.toggle()
	check(action_paused and not get_tree().paused, "the pause action (Esc, HUD button) opens the pause menu")

	await physics_frames(60)
	GameManager.kills = 4
	game.player.health.take_damage(DamageInfo.new(1000, null, &"skeleton"))
	check(GameManager.is_run_over and not game.death_screen.panel.visible, "death ends the run; the screen comes after a short delay")
	game.pause_menu.set_paused(true)
	check(not get_tree().paused, "the game cannot be paused after death")
	await get_tree().create_timer(GameManager.DEATH_SCREEN_DELAY + 0.3).timeout
	var stats: String = game.death_screen.stats_label.text
	check(game.death_screen.panel.visible and stats.contains("Depth reached: 1") and stats.contains("Sections cleared: 0")
			and stats.contains("Enemies defeated: 4") and stats.contains("Coins: 7") and stats.contains("Time: 0:0"),
			"the death screen shows depth, sections, time, kills and coins")
	var summary: Dictionary = GameManager.get_run_summary()
	check(summary["seed"] == RUN_SEED and float(summary["time"]) > 1.0 and float(summary["time"]) < 5.0,
			"the run summary has the seed and the time played")
	check(not Telemetry.history.is_empty() and Telemetry.history[Telemetry.history.size() - 1]["died"] == true,
			"the death is logged")
	game.queue_free()
	await physics_frames(3)
