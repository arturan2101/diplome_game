extends TestCase
## Headless test for stage 48, part 2: the enemies of the fungal catacombs are bought
## only on fungal floors; their art has the animations the code plays; a dead sporeling
## leaves spores that hurt the player; the spore bat flies over a pit to the player and
## bites in its dive; the vine lurker waits closed in the floor, comes out when the
## player is near (or hits it), lashes from afar and never moves.

const SETTINGS: String = "res://director/director_settings.tres"
const STYLES: String = "res://level/floor_styles.tres"
const ENEMY_SCENE: String = "res://actors/enemies/enemy.tscn"
const ENEMIES: String = "res://actors/enemies/%s.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const FUNGAL: Array[StringName] = [&"sporeling", &"spore_bat", &"vine_lurker"]
const OTHER_FLOORS: Array[StringName] = [&"drowned", &"tide_crab", &"ember_imp", &"magma_beetle"]
const TIMEOUT_FRAMES: int = 240
## A pit three cells wide between the left and the right part.
const PIT_MAP: String = """##############
#....~~~.....#
#....~~~.....#
#....~~~.....#
#....~~~.....#
##############"""
const OPEN_MAP: String = """############
#..........#
#..........#
#..........#
#..........#
############"""


func run() -> void:
	_test_buying()
	_test_art()
	await _test_sporeling()
	await _test_bat()
	await _test_lurker()


func _test_buying() -> void:
	var settings: DirectorSettings = (load(SETTINGS) as DirectorSettings).duplicate() as DirectorSettings
	var director: Director = RandomDirector.new(null, settings)
	var table: FloorStyleTable = load(STYLES) as FloorStyleTable
	check(not _has_any(_bought(director, 2), FUNGAL), "without floor styles they are never bought")
	settings.floor_styles = table
	var fungal_depth: int = 0
	while table.style_at(fungal_depth) != &"fungal":
		fungal_depth += 1
	var fungal: Dictionary = _bought(director, fungal_depth)
	check(_has_all(fungal, FUNGAL) and not _has_any(fungal, OTHER_FLOORS),
			"on the fungal floors the sporeling, the spore bats and the vine lurker: %s" % [fungal.keys()])
	check(not _has_any(_bought(director, 0), FUNGAL) and not _has_any(_bought(director, fungal_depth + table.depths_per_style), FUNGAL),
			"in the ruins and the flooded halls none of them")
	check(not _has_any(_bought(director, fungal_depth), [&"guardian"] as Array[StringName]), "bosses are never bought as enemies")


func _bought(director: Director, depth: int) -> Dictionary:
	var seen: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 48 + depth
	for _i in 60:
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


func _test_art() -> void:
	var needs: Dictionary = {
		&"sporeling": ["idle_down", "walk_left", "attack_up", "hurt_right", "death"],
		&"spore_bat": ["idle_down", "attack_left", "hurt_up", "death"],
		&"vine_lurker": ["hidden_down", "emerge_left", "idle_up", "attack_right", "hurt_down", "death"],
	}
	var ok: bool = true
	for id: StringName in needs:
		var data: EnemyData = load(ENEMIES % id) as EnemyData
		for anim: String in needs[id]:
			ok = ok and data.sprite_frames.has_animation(anim)
		ok = ok and data.attack_strike_frame < data.sprite_frames.get_frame_count(&"attack_down")
		ok = ok and data.floor_style == &"fungal" and data.weapon != null
	check(ok, "their frames have every animation the code plays, the strike inside the attack")
	var made: Array[Enemy] = [_spawn(&"spore_bat", Vector2.ZERO, false), _spawn(&"vine_lurker", Vector2.ZERO, false),
			_spawn(&"sporeling", Vector2.ZERO, false)]
	check(made[0] is SporeBat and made[1] is VineLurker and made[2].get_script() == load("res://actors/enemies/enemy.gd"),
			"the bat and the lurker have their own scenes, the sporeling is a plain enemy")
	for enemy: Enemy in made:
		enemy.free()


func _spawn(id: StringName, at: Vector2, add: bool = true, parent: Node = null) -> Enemy:
	var data: EnemyData = load(ENEMIES % id) as EnemyData
	var scene: PackedScene = data.scene if data.scene != null else load(ENEMY_SCENE) as PackedScene
	var enemy: Enemy = scene.instantiate() as Enemy
	enemy.data = data
	enemy.position = at
	if add:
		(parent if parent != null else self).add_child(enemy)
	return enemy


func _player(at: Vector2, parent: Node = null) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = at
	(parent if parent != null else self).add_child(player)
	return player


func _test_sporeling() -> void:
	var player: Player = _player(Vector2(300.0, 300.0))
	var sporeling: Enemy = _spawn(&"sporeling", Vector2(300.0, 304.0))
	await physics_frames(2)
	player.health.make_invulnerable(0.1)
	var hits: Array[DamageInfo] = []
	player.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	sporeling.health.take_damage(DamageInfo.new(1000, null, &"test"))
	await physics_frames(2)
	var zones: Array[SpellZone] = []
	for node: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		if node is SpellZone:
			zones.append(node)
	check(zones.size() == 1, "a dead sporeling bursts into a spore cloud")
	if not zones.is_empty():
		player.global_position = zones[0].global_position + Vector2(0.0, -8.0)
	player.health.end_invulnerability()
	await physics_frames(roundi(1.2 * Engine.physics_ticks_per_second))
	var spores: bool = false
	for info: DamageInfo in hits:
		spores = spores or info.source_id == &"sporeling"
	check(spores, "the spores hurt the player standing in them (logged as sporeling): %s" % [hits.map(func(i: DamageInfo) -> String: return "%s %d" % [i.source_id, i.amount])])
	for node: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		node.queue_free()
	player.queue_free()
	await physics_frames(2)


func _test_bat() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(PIT_MAP))
	var player: Player = _player(level.cell_center(Vector2i(11, 2)), level)
	var bat: SporeBat = _spawn(&"spore_bat", level.cell_center(Vector2i(2, 2)), true, level) as SporeBat
	var hits: Array[DamageInfo] = []
	player.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	var over_pit: bool = false
	var flew_idle: bool = true
	var dived: bool = false
	var frames: int = 0
	while hits.is_empty() and frames < TIMEOUT_FRAMES and is_instance_valid(bat):
		await physics_frames(1)
		frames += 1
		over_pit = over_pit or level.cell_type_at(bat.global_position) == LevelGrid.Cell.PIT
		dived = dived or bat.is_diving()
		var sprite: AnimatedSprite2D = bat.visual as AnimatedSprite2D
		if bat.state == Enemy.State.CHASE and bat.velocity.length() > 5.0:
			flew_idle = flew_idle and String(sprite.animation).begins_with("idle_")
	check(over_pit and is_instance_valid(bat) and bat.state != Enemy.State.FALLING, "the bat flies over the pit without falling")
	check(flew_idle, "it flies with its idle (flight) animation")
	check(dived and not hits.is_empty() and hits[0].source_id == &"spore_bat", "it dives and bites the player")
	level.queue_free()
	await physics_frames(2)


func _test_lurker() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(OPEN_MAP))
	var spot: Vector2 = level.cell_center(Vector2i(3, 2))
	var player: Player = _player(level.cell_center(Vector2i(10, 2)), level)
	var lurker: VineLurker = _spawn(&"vine_lurker", spot, true, level) as VineLurker
	await physics_frames(10)
	var sprite: AnimatedSprite2D = lurker.visual as AnimatedSprite2D
	check(lurker.is_hidden() and String(sprite.animation).begins_with("hidden_"), "far from the player it waits closed in the floor")
	var hits: Array[DamageInfo] = []
	player.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	# Within reach of the lash but not of a sword: it comes out and lashes.
	player.global_position = spot + Vector2(40.0, 0.0)
	player.set_physics_process(false)
	var emerged: bool = false
	var lash_shown: bool = false
	var frames: int = 0
	while hits.is_empty() and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
		emerged = emerged or String(sprite.animation).begins_with("emerge_")
		for child: Node in level.get_children():
			lash_shown = lash_shown or (child is StripSprite and (child as StripSprite).texture == (lurker.data as VineLurkerData).lash_effect)
	check(emerged and not lurker.is_hidden(), "the player close by makes it come out")
	check(not hits.is_empty() and hits[0].source_id == &"vine_lurker" and lash_shown, "its vine lashes the player 40 pixels away")
	lurker.health.take_damage(DamageInfo.new(1, player, &"test", Vector2(300.0, 0.0)))
	lurker.apply_knockback(Vector2(300.0, 0.0))
	await physics_frames(10)
	check(lurker.global_position.distance_to(spot) < 0.5, "blows never push it off its cell")
	var second: VineLurker = _spawn(&"vine_lurker", level.cell_center(Vector2i(9, 4)), true, level) as VineLurker
	player.global_position = level.cell_center(Vector2i(1, 1))
	await physics_frames(2)
	second.hurtbox.receive_hit(DamageInfo.new(1, player, &"test"))
	await physics_frames(roundi(0.6 * Engine.physics_ticks_per_second))
	check(not second.is_hidden() and second.get_pose() == &"", "a hit from afar wakes a hidden one too")
	level.queue_free()
	await physics_frames(2)
