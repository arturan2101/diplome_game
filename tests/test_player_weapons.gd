extends SceneTree
## Headless test for the player's weapon slots: start state, swapping, weapon_changed,
## cancelling a drawn bow on swap, and a single weapon making swap a no-op.
## Builds everything in code, so it does not depend on .tscn files.
## Exit code = number of failed checks.
## Run: godot --headless --path . --script res://tests/test_player_weapons.gd

## Frames that surely cover a full bow draw with default BowWeaponData (0.15 + 0.8 s).
const FULL_DRAW_FRAMES: int = 60

var _failures: int = 0
## One entry per weapon_changed signal: [slot, weapon id].
var _changes: Array = []
var _solo_changes: Array = []


func _initialize() -> void:
	await process_frame
	# The player polls this action; the test may run before it is added in the editor.
	if not InputMap.has_action("swap_weapon"):
		InputMap.add_action("swap_weapon")

	var sword_data: MeleeWeaponData = MeleeWeaponData.new()
	sword_data.id = &"sword"
	sword_data.combo = [MeleeAttackStep.new()] as Array[MeleeAttackStep]
	sword_data.weapon_scene = _pack(MeleeWeapon.new())
	var bow_data: BowWeaponData = BowWeaponData.new()
	bow_data.id = &"bow"
	bow_data.arrow_scene = _pack(Arrow.new())
	bow_data.weapon_scene = _pack(BowWeapon.new())

	var player: Player = _new_player()
	player.starting_weapons = [sword_data, bow_data] as Array[WeaponData]
	player.weapon_changed.connect(func(slot: int, data: WeaponData) -> void: _changes.append([slot, data.id]))
	root.add_child(player)
	await _physics_frames(2)

	var sword: Weapon = player.weapon
	_check(sword != null and sword.data == sword_data and sword.visible, "first slot is active at start")
	_check(_changes.is_empty(), "no weapon_changed at start")

	player.swap_weapon()
	var bow: BowWeapon = player.weapon as BowWeapon
	_check(bow != null and bow.visible and not sword.visible and not sword.is_active,
			"swap puts the sword away and takes the bow")
	_check(_changes == [[1, &"bow"]], "swap emits weapon_changed(1, bow)")

	# Swapping away from a drawn bow removes the slowdown at once.
	bow.try_attack(Vector2.RIGHT)
	await _physics_frames(FULL_DRAW_FRAMES)
	_check(bow.get_move_speed_multiplier() < 1.0, "drawn bow slows the player")
	player.swap_weapon()
	_check(player.weapon == sword and is_equal_approx(player.weapon.get_move_speed_multiplier(), 1.0)
			and is_equal_approx(bow.get_move_speed_multiplier(), 1.0),
			"swapping away from a drawn bow removes the slowdown")
	# Give a wrongly kept draw time to grow while the bow is put away.
	await _physics_frames(FULL_DRAW_FRAMES)
	player.swap_weapon()
	_check(player.weapon == bow and is_equal_approx(bow.get_draw_progress(), 0.0),
			"bow is not drawn after swapping back")
	_check(_changes == [[1, &"bow"], [0, &"sword"], [1, &"bow"]], "every swap emits weapon_changed")

	# With one weapon the swap does nothing.
	var solo: Player = _new_player()
	solo.starting_weapons = [sword_data] as Array[WeaponData]
	solo.weapon_changed.connect(func(slot: int, data: WeaponData) -> void: _solo_changes.append([slot, data.id]))
	root.add_child(solo)
	await _physics_frames(1)
	var solo_weapon: Weapon = solo.weapon
	solo.swap_weapon()
	_check(solo.weapon == solo_weapon and solo_weapon.is_active and _solo_changes.is_empty(),
			"with one weapon swap does nothing and emits nothing")

	# Without weapons the swap is safe too.
	var unarmed: Player = _new_player()
	root.add_child(unarmed)
	unarmed.swap_weapon()
	_check(unarmed.weapon == null, "unarmed player can press swap safely")

	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(_failures)


## Packs a node into a scene the way a .tscn would hold it, then frees the template.
func _pack(node: Node) -> PackedScene:
	var scene: PackedScene = PackedScene.new()
	scene.pack(node)
	node.free()
	return scene


func _physics_frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		print("FAIL: ", description)
		_failures += 1


## A player with the Health its scene would have.
func _new_player() -> Player:
	var player: Player = Player.new()
	var health: Health = Health.new()
	player.add_child(health)
	player.health = health
	return player
