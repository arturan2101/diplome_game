extends TestCase
## Headless test for the floor enemies of stage 42: the director buys them only on their
## own floors and only with floor styles on; the drowned's grip slows the player; the
## ember imp throws fireballs; the magma beetle leaves lava that hurts the player.

const SETTINGS: String = "res://director/director_settings.tres"
const STYLES: String = "res://level/floor_styles.tres"
const ENEMY_SCENE: String = "res://actors/enemies/enemy.tscn"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const ENEMIES: String = "res://actors/enemies/%s.tres"
const BUYS: int = 300
const TIMEOUT_FRAMES: int = 240


func run() -> void:
	_test_buying()
	await _test_drowned_grip()
	await _test_imp()
	await _test_magma_beetle()


func _test_buying() -> void:
	var settings: DirectorSettings = (load(SETTINGS) as DirectorSettings).duplicate() as DirectorSettings
	var director: Director = RandomDirector.new(null, settings)
	var by_depth: Dictionary = {}
	for depth: int in [0, 2, 4, 6]:
		by_depth[depth] = _bought(director, depth)
	var flooded: Array[StringName] = [&"drowned", &"tide_crab"]
	var fire: Array[StringName] = [&"ember_imp", &"magma_beetle"]
	check(not _has_any(by_depth[0], flooded + fire) and not _has_any(by_depth[2], flooded + fire),
			"without floor styles no floor enemy is ever bought")
	settings.floor_styles = load(STYLES) as FloorStyleTable
	for depth: int in [0, 2, 4, 6]:
		by_depth[depth] = _bought(director, depth)
	check(not _has_any(by_depth[0], flooded + fire) and not _has_any(by_depth[6], flooded + fire),
			"in the ruins (depths 1-2 and 7-8) none of them")
	check(_has_all(by_depth[2], flooded) and not _has_any(by_depth[2], fire),
			"in the flooded halls the drowned and the crabs, never the fire ones: %s" % [by_depth[2].keys()])
	check(_has_all(by_depth[4], fire) and not _has_any(by_depth[4], flooded),
			"in the burning depths the imps and the magma beetles: %s" % [by_depth[4].keys()])


func _bought(director: Director, depth: int) -> Dictionary:
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 42 + depth
	var seen: Dictionary = {}
	for _i in BUYS:
		for id: StringName in director.buy_enemies(12, rng, {}, depth):
			seen[id] = true
	return seen


func _has_any(seen: Dictionary, ids: Array[StringName]) -> bool:
	for id: StringName in ids:
		if seen.has(id):
			return true
	return false


func _has_all(seen: Dictionary, ids: Array[StringName]) -> bool:
	for id: StringName in ids:
		if not seen.has(id):
			return false
	return true


func _test_drowned_grip() -> void:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = Vector2(100.0, 100.0)
	add_child(player)
	var drowned: Enemy = _add_enemy("drowned", Vector2(100.0, 118.0))
	var frames: int = 0
	while not player.is_slowed() and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
	check(player.is_slowed() and player.health.hp < player.health.max_hp, "the drowned's blow lands and its grip slows the player")
	await _clean_up([player, drowned])


func _test_imp() -> void:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = Vector2(400.0, 100.0)
	add_child(player)
	var imp: Enemy = _add_enemy("ember_imp", Vector2(500.0, 100.0))
	var hits: Array[DamageInfo] = []
	player.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	var frames: int = 0
	while hits.is_empty() and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
	check(not hits.is_empty() and hits[0].source_id == &"ember_imp", "the imp's fireball hits the player from afar")
	await _clean_up([player, imp])


func _test_magma_beetle() -> void:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = Vector2(700.0, 300.0)
	add_child(player)
	var beetle: Enemy = _add_enemy("magma_beetle", Vector2(700.0, 304.0))
	await physics_frames(2)
	player.health.make_invulnerable(0.1)
	var hits: Array[DamageInfo] = []
	player.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	beetle.health.take_damage(DamageInfo.new(1000, null, &"test"))
	await physics_frames(2)
	var zones: int = 0
	for node: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		if node is SpellZone:
			zones += 1
	check(zones == 1, "a dead magma beetle leaves a lava puddle")
	player.health.end_invulnerability()
	await physics_frames(roundi(1.2 * Engine.physics_ticks_per_second))
	var lava: bool = false
	for info: DamageInfo in hits:
		if info.source_id == &"magma_beetle":
			lava = true
	check(lava, "the puddle burns the player standing in it (logged as magma_beetle)")
	for node: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		node.queue_free()
	await _clean_up([player])


func _add_enemy(id: String, at: Vector2) -> Enemy:
	var enemy: Enemy = (load(ENEMY_SCENE) as PackedScene).instantiate() as Enemy
	enemy.data = load(ENEMIES % id) as EnemyData
	enemy.position = at
	add_child(enemy)
	return enemy


func _clean_up(nodes: Array) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await physics_frames(2)
