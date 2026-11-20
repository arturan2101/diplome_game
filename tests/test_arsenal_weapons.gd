extends TestCase
## Headless test for batch 8's new weapons (stage 39): the spear's long narrow thrust,
## the daggers' quick short combo, the crossbow's instant shot, reload, held fire and
## piercing bolt, and the chest pool that holds them only with ExperimentConfig.arsenal.

const SPEAR: String = "res://combat/weapons/spear.tres"
const DAGGERS: String = "res://combat/weapons/daggers.tres"
const CROSSBOW: String = "res://combat/weapons/crossbow.tres"
const CLEAN: String = "res://experiment/clean.tres"
const GAME_SCENE: String = "res://main/main.tscn"
const ENEMY_HURTBOX_LAYER: int = 16
const TARGET_HP: int = 1000
const TARGET_RADIUS: float = 4.0
const ORIGIN: Vector2 = Vector2(100.0, 100.0)


func run() -> void:
	await _test_spear()
	await _test_daggers()
	await _test_crossbow()
	await _test_chest_pool()


func _test_spear() -> void:
	var spear: MeleeWeaponData = load(SPEAR) as MeleeWeaponData
	check(spear.attack_animation == &"spear" and spear.combo.size() == 2, "the spear: two thrusts and its own animation")
	var far: Hurtbox = _add_target(ORIGIN + Vector2(38.0, 0.0))
	var aside: Hurtbox = _add_target(ORIGIN + Vector2(25.0, 25.0))
	var weapon: MeleeWeapon = await _wield(spear)
	weapon.try_attack(Vector2.RIGHT)
	await physics_frames(3)
	var slash: Sprite2D = weapon.get_node_or_null("Slash") as Sprite2D
	check(slash != null and slash.offset == Vector2(24.0, 0.0), "the thrust picture starts at the wielder (left edge)")
	await physics_frames(20)
	check(far.health.hp == TARGET_HP - spear.combo[0].damage, "the thrust hits 38 pixels ahead")
	check(aside.health.hp == TARGET_HP, "but not an enemy 45 degrees to the side")
	await _clean_up([weapon.get_parent(), far, aside])


func _test_daggers() -> void:
	var daggers: MeleeWeaponData = load(DAGGERS) as MeleeWeaponData
	check(daggers.combo.size() == 4 and is_equal_approx(daggers.get_crit_chance(), 0.2),
			"the daggers: four stabs and a 20% crit chance")
	var close: Hurtbox = _add_target(ORIGIN + Vector2(16.0, 0.0))
	var far: Hurtbox = _add_target(ORIGIN + Vector2(30.0, 0.0))
	var weapon: MeleeWeapon = await _wield(daggers)
	var steps: Array[int] = [0]
	weapon.attack_performed.connect(func(_step: int, _hits: int) -> void: steps[0] += 1)
	# Press every few frames for a second: the whole combo runs.
	for _i in 15:
		weapon.try_attack(Vector2.RIGHT)
		await physics_frames(4)
	check(steps[0] >= 4, "a second of pressing stabs at least four times (%d)" % steps[0])
	check(close.health.hp < TARGET_HP and far.health.hp == TARGET_HP, "the daggers reach 16 pixels, not 30")
	await _clean_up([weapon.get_parent(), close, far])


func _test_crossbow() -> void:
	var crossbow: CrossbowWeaponData = load(CROSSBOW) as CrossbowWeaponData
	var first: Hurtbox = _add_target(ORIGIN + Vector2(40.0, 0.0))
	var second: Hurtbox = _add_target(ORIGIN + Vector2(80.0, 0.0))
	var third: Hurtbox = _add_target(ORIGIN + Vector2(120.0, 0.0))
	var weapon: CrossbowWeapon = (crossbow.weapon_scene.instantiate()) as CrossbowWeapon
	var wielder: Node2D = Node2D.new()
	wielder.position = ORIGIN
	add_child(wielder)
	weapon.setup(crossbow, wielder)
	wielder.add_child(weapon)
	var shots: Array[int] = [0, 0]
	weapon.attack_performed.connect(func(_step: int, hits: int) -> void:
		shots[0] += 1
		shots[1] += hits)
	await physics_frames(1)
	check(weapon.is_ranged() and weapon.is_loaded(), "the crossbow shoots and starts loaded")
	weapon.try_attack(Vector2.RIGHT)
	check(not weapon.is_loaded() and weapon.get_reload_fraction() > 0.9, "a press shoots at once, then it reloads")
	await physics_frames(roundi(0.5 * Engine.physics_ticks_per_second))
	check(first.health.hp == TARGET_HP - crossbow.damage and second.health.hp == TARGET_HP - crossbow.damage
			and third.health.hp == TARGET_HP, "the bolt flies through one enemy, hits the next and stops there")
	check(shots[0] == 1 and shots[1] == 1, "one shot reported, as a hit")
	# Still held: it shoots again by itself once loaded.
	await physics_frames(roundi(crossbow.reload_time * Engine.physics_ticks_per_second))
	check(shots[0] == 2, "held down, it shoots again as soon as it is loaded (%d shots)" % shots[0])
	weapon.release_attack(Vector2.RIGHT)
	await physics_frames(roundi((crossbow.reload_time + 0.6) * Engine.physics_ticks_per_second))
	check(shots[0] == 2, "released, it does not shoot")
	var lines: Array[String] = []
	for line: Dictionary in crossbow.get_card_stats():
		lines.append(line["name"])
	var expected: Array[String] = ["Damage", "Reload", "Range", "Pierce", "Crit"]
	check(lines == expected, "the crossbow's card lines: %s" % [lines])
	await _clean_up([wielder, first, second, third])


## The full game's chests and shop hold the new weapons; the clean series' do not.
func _test_chest_pool() -> void:
	var saved: ExperimentConfig = GameManager.config
	var ids: Array[StringName] = await _chest_pool_ids()
	check(ids.has(&"spear") and ids.has(&"daggers") and ids.has(&"crossbow") and ids.size() == 5,
			"with batch 8 chests hold five kinds of weapons")
	GameManager.config = load(CLEAN) as ExperimentConfig
	var clean_ids: Array[StringName] = await _chest_pool_ids()
	check(clean_ids == ([&"sword", &"bow"] as Array[StringName]), "the clean series keeps the sword and the bow")
	GameManager.config = saved


func _chest_pool_ids() -> Array[StringName]:
	GameManager.start_run(777)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(1)
	var ids: Array[StringName] = []
	for weapon_data: WeaponData in game.chest_weapons.weapons:
		ids.append(weapon_data.id)
	game.queue_free()
	await physics_frames(2)
	return ids


func _wield(stats: WeaponData) -> MeleeWeapon:
	var wielder: Node2D = Node2D.new()
	wielder.position = ORIGIN
	add_child(wielder)
	var weapon: MeleeWeapon = stats.weapon_scene.instantiate() as MeleeWeapon
	weapon.setup(stats, wielder)
	wielder.add_child(weapon)
	await physics_frames(2)
	return weapon


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


func _clean_up(nodes: Array) -> void:
	for node: Node in nodes:
		node.queue_free()
	await physics_frames(2)
