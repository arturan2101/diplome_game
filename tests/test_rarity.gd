extends TestCase
## Headless test for weapon rarity: the chance table by depth, weapon copies with a
## rarity, damage and attack speed multipliers, the hint and outline of a weapon on the
## floor, chest loot from the seed, and the rarity in the player state and the log.

const TABLE: String = "res://combat/weapons/rarity_table.tres"
const SWORD: String = "res://combat/weapons/sword.tres"
const BOW: String = "res://combat/weapons/bow.tres"
const RARE: String = "res://combat/weapons/rarity/rare.tres"
const LEGENDARY: String = "res://combat/weapons/rarity/legendary.tres"
const PICKUP_SCENE: String = "res://actors/pickups/weapon_pickup.tscn"
const HUD_SCENE: String = "res://ui/hud.tscn"
const GAME_SCENE: String = "res://main/main.tscn"
const ENEMY_HURTBOX_LAYER: int = 16
const TARGET_HP: int = 1000
const TARGET_RADIUS: float = 8.0
const DRAWS: int = 4000
## Seeds tried until the first section has a chest.
const FIRST_SEED: int = 500
const SEED_TRIES: int = 20


func run() -> void:
	_test_table()
	_test_copies()
	await _test_melee()
	await _test_bow_draw()
	await _test_pickup_and_hint()
	await _test_chest_loot_and_state()


func _test_table() -> void:
	var table: RarityTable = load(TABLE) as RarityTable
	var ids: Array[StringName] = []
	for rarity: WeaponRarity in table.rarities:
		ids.append(rarity.id)
	check(ids == ([&"common", &"rare", &"legendary"] as Array[StringName]), "three rarities: common, rare, legendary")
	check(is_equal_approx(table.chance(0, 0), 0.85) and is_equal_approx(table.chance(1, 0), 0.14)
			and is_equal_approx(table.chance(2, 0), 0.01), "first depth: 85 / 14 / 1")
	var grows: bool = true
	for depth in range(1, table.weights_by_depth.size()):
		if table.chance(2, depth) < table.chance(2, depth - 1) or table.chance(0, depth) > table.chance(0, depth - 1):
			grows = false
	check(grows, "deeper, legendary weapons get likelier and common ones rarer")
	var last: int = table.weights_by_depth.size() - 1
	check(is_equal_approx(table.chance(2, last + 10), table.chance(2, last)), "below the last row the last row is used")

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 1
	var common_count: int = 0
	for _i in DRAWS:
		if table.pick(0, rng).id == &"common":
			common_count += 1
	var share: float = float(common_count) / DRAWS
	check(absf(share - 0.85) < 0.03, "drawn at the first depth, about 85%% are common (%.3f)" % share)
	var first: RandomNumberGenerator = RandomNumberGenerator.new()
	var second: RandomNumberGenerator = RandomNumberGenerator.new()
	first.seed = 77
	second.seed = 77
	var same: bool = true
	for _i in 50:
		if table.pick(3, first) != table.pick(3, second):
			same = false
	check(same, "the same seed gives the same rarities")


func _test_copies() -> void:
	var sword: WeaponData = load(SWORD) as WeaponData
	var rare_sword: WeaponData = sword.with_rarity(load(RARE) as WeaponRarity)
	check(sword.rarity == null and sword.get_rarity().id == &"common", "the base sword stays common")
	check(rare_sword.get_rarity().id == &"rare" and rare_sword.id == sword.id and rare_sword.get_full_name() == "Rare Sword",
			"a rare copy keeps the weapon id for the log and is called Rare Sword")
	check(is_equal_approx(rare_sword.get_damage_multiplier(), 1.3) and is_equal_approx(sword.get_damage_multiplier(), 1.0),
			"damage multipliers: rare 1.3, common 1.0")


## One sword per rarity hits a target in front: damage grows with rarity, and a
## legendary sword is ready for the next swing earlier.
func _test_melee() -> void:
	var sword: MeleeWeaponData = load(SWORD) as MeleeWeaponData
	var base_damage: int = sword.combo[0].damage
	var common_hits: Array[int] = await _swing_twice(sword.with_rarity(null) as MeleeWeaponData)
	var rare_hits: Array[int] = await _swing_twice(sword.with_rarity(load(RARE) as WeaponRarity) as MeleeWeaponData)
	var legendary_hits: Array[int] = await _swing_twice(sword.with_rarity(load(LEGENDARY) as WeaponRarity) as MeleeWeaponData)
	check(common_hits[0] == base_damage and rare_hits[0] == roundi(base_damage * 1.3)
			and legendary_hits[0] == roundi(base_damage * 1.7),
			"first swing damage: common %d, rare %d, legendary %d" % [common_hits[0], rare_hits[0], legendary_hits[0]])
	check(common_hits[1] == 1 and legendary_hits[1] == 2,
			"a second press just before the common sword recovers swings only with the faster legendary one")


## Returns [damage of the first swing, number of swings], pressing the second time
## between the end of a legendary swing and the end of a common one.
func _swing_twice(stats: MeleeWeaponData) -> Array[int]:
	# No input buffer, so a press during a swing is simply ignored.
	stats.buffer_window = 0.0
	var wielder: Node2D = Node2D.new()
	wielder.position = Vector2(100.0, 100.0)
	add_child(wielder)
	var weapon: MeleeWeapon = MeleeWeapon.new()
	weapon.setup(stats, wielder)
	var swings: Array[int] = [0]
	weapon.attack_performed.connect(func(_step: int, _hits: int) -> void: swings[0] += 1)
	wielder.add_child(weapon)
	var target: Hurtbox = _add_target(wielder.position + Vector2(20.0, 0.0))
	await physics_frames(2)
	var step: MeleeAttackStep = stats.combo[0]
	var common_busy: float = step.duration + step.recovery
	var legendary_busy: float = common_busy / (load(LEGENDARY) as WeaponRarity).attack_speed_multiplier
	var second_press_frame: int = ceili((common_busy + legendary_busy) * 0.5 * Engine.physics_ticks_per_second)
	weapon.try_attack(Vector2.RIGHT)
	await physics_frames(second_press_frame)
	var first_damage: int = TARGET_HP - target.health.hp
	weapon.try_attack(Vector2.RIGHT)
	await physics_frames(Engine.physics_ticks_per_second)
	wielder.queue_free()
	target.queue_free()
	await physics_frames(2)
	var result: Array[int] = [first_damage, swings[0]]
	return result


## A legendary bow draws 1.2 times faster than a common one.
func _test_bow_draw() -> void:
	var bow: BowWeaponData = load(BOW) as BowWeaponData
	var hold_frames: int = roundi((bow.tap_threshold + bow.draw_time * 0.5) * Engine.physics_ticks_per_second)
	var common: float = await _draw_progress(bow, hold_frames)
	var legendary: float = await _draw_progress(bow.with_rarity(load(LEGENDARY) as WeaponRarity), hold_frames)
	check(common > 0.4 and common < 0.6 and absf(legendary - common * 1.2) < 0.03,
			"halfway through the draw: common %.2f, legendary %.2f" % [common, legendary])


func _draw_progress(stats: WeaponData, frames: int) -> float:
	var wielder: Node2D = Node2D.new()
	add_child(wielder)
	var weapon: BowWeapon = BowWeapon.new()
	weapon.setup(stats, wielder)
	wielder.add_child(weapon)
	await physics_frames(1)
	weapon.try_attack(Vector2.RIGHT)
	await physics_frames(frames)
	var progress: float = weapon.get_draw_progress()
	weapon.cancel_attack()
	wielder.queue_free()
	await physics_frames(1)
	return progress


func _test_pickup_and_hint() -> void:
	var legendary: WeaponRarity = load(LEGENDARY) as WeaponRarity
	var pickup: WeaponPickup = (load(PICKUP_SCENE) as PackedScene).instantiate() as WeaponPickup
	pickup.weapon_data = (load(SWORD) as WeaponData).with_rarity(legendary)
	add_child(pickup)
	await physics_frames(1)
	check(pickup.get_prompt() == "Take [color=#%s]Legendary Sword[/color]" % legendary.color.to_html(false),
			"the hint names the weapon with its rarity, in gold")
	var outline: Array[Sprite2D] = []
	for child: Node in pickup.sprite.get_children():
		if child is Sprite2D:
			outline.append(child)
	var material: ShaderMaterial = outline[0].material as ShaderMaterial if not outline.is_empty() else null
	check(outline.size() == 4 and outline[0].show_behind_parent and outline[0].texture == pickup.sprite.texture
			and material != null and material.get_shader_parameter(&"color") == legendary.color,
			"four gold copies of the sprite behind it make the outline")

	var hud: Hud = (load(HUD_SCENE) as PackedScene).instantiate() as Hud
	add_child(hud)
	await physics_frames(1)
	hud._on_interaction_changed(pickup)
	check(hud.interact_prompt.visible and hud.interact_prompt.get_parsed_text() == "Take Legendary Sword  [E]",
			"the HUD shows the hint as rich text: '%s'" % hud.interact_prompt.get_parsed_text())
	hud.queue_free()
	pickup.queue_free()
	await physics_frames(2)


## A chest in the first section holds a weapon with a rarity, the same one for the same
## seed; the player state reports the rarity of the weapon in hand.
func _test_chest_loot_and_state() -> void:
	var found_seed: int = -1
	var loot: WeaponData = null
	for run_seed in range(FIRST_SEED, FIRST_SEED + SEED_TRIES):
		loot = await _first_chest_loot(run_seed)
		if loot != null:
			found_seed = run_seed
			break
	check(found_seed >= 0 and loot.rarity != null, "a chest weapon gets a rarity")
	if found_seed < 0:
		return
	var again: WeaponData = await _first_chest_loot(found_seed)
	check(again != null and again.id == loot.id and again.get_rarity() == loot.get_rarity(),
			"the same seed gives the same chest weapon and rarity (%s %s)" % [loot.get_rarity().id, loot.id])

	GameManager.start_run(found_seed)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	var state: PlayerState = game._make_player_state()
	check(state.weapon_rarity == &"common" and is_equal_approx(state.weapon_multiplier, 1.0),
			"the starting weapon is common in the player state")
	game.player.add_weapon((load(SWORD) as WeaponData).with_rarity(load(RARE) as WeaponRarity))
	game.player.swap_weapon()
	state = game._make_player_state()
	check(state.weapon_rarity == &"rare" and is_equal_approx(state.weapon_multiplier, 1.3),
			"with a rare sword in hand the player state says rare, multiplier 1.3")
	game.queue_free()
	await physics_frames(3)


func _first_chest_loot(run_seed: int) -> WeaponData:
	GameManager.start_run(run_seed)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	var loot: WeaponData = null
	for pickup: Pickup in game.get_pickups():
		if pickup is Chest and (pickup as Chest).loot_weapon != null:
			loot = (pickup as Chest).loot_weapon
			break
	game.queue_free()
	await physics_frames(3)
	return loot


func _add_target(at: Vector2) -> Hurtbox:
	var hurtbox: Hurtbox = Hurtbox.new()
	hurtbox.position = at
	hurtbox.collision_layer = ENEMY_HURTBOX_LAYER
	hurtbox.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = TARGET_RADIUS
	shape.shape = circle
	hurtbox.add_child(shape)
	var health: Health = Health.new()
	health.max_hp = TARGET_HP
	hurtbox.add_child(health)
	hurtbox.health = health
	add_child(hurtbox)
	return hurtbox
