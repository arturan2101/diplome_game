extends TestCase
## Headless test for stage 49, part 2: the enemies of the buried temple are bought only
## on sand floors; their art has the animations the code plays; the mummy's grip slows
## the player and wraps bandages round its legs; the scarab burrows when the player is
## far, cannot be hit under the sand, comes up beside the player and bites; the sand
## serpent lies hidden (untouchable, a ripple over it), creeps up, bursts out with a
## bite, can be hit while upright, is never pushed and sinks again.

const SETTINGS: String = "res://director/director_settings.tres"
const STYLES: String = "res://level/floor_styles.tres"
const ENEMY_SCENE: String = "res://actors/enemies/enemy.tscn"
const ENEMIES: String = "res://actors/enemies/%s.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const SAND: Array[StringName] = [&"mummy", &"scarab", &"sand_serpent"]
const OTHER_FLOORS: Array[StringName] = [&"drowned", &"tide_crab", &"ember_imp", &"magma_beetle",
		&"sporeling", &"spore_bat", &"vine_lurker"]
const TIMEOUT_FRAMES: int = 420
const OPEN_MAP: String = """##############
#............#
#............#
#............#
#............#
##############"""


func run() -> void:
	_test_buying()
	_test_art()
	await _test_mummy()
	await _test_scarab()
	await _test_serpent()


func _test_buying() -> void:
	var settings: DirectorSettings = (load(SETTINGS) as DirectorSettings).duplicate() as DirectorSettings
	var director: Director = RandomDirector.new(null, settings)
	var table: FloorStyleTable = load(STYLES) as FloorStyleTable
	check(not _has_any(_bought(director, 2), SAND), "without floor styles they are never bought")
	settings.floor_styles = table
	var sand_depth: int = 0
	while table.style_at(sand_depth) != &"sand":
		sand_depth += 1
	var sand: Dictionary = _bought(director, sand_depth)
	check(_has_all(sand, SAND) and not _has_any(sand, OTHER_FLOORS),
			"on the sand floors the mummy, the scarab swarm and the sand serpent: %s" % [sand.keys()])
	var elsewhere: bool = false
	for depth in sand_depth:
		elsewhere = elsewhere or _has_any(_bought(director, depth), SAND)
	check(not elsewhere and not _has_any(_bought(director, sand_depth + table.depths_per_style), SAND),
			"on the floors before and after none of them")


func _bought(director: Director, depth: int) -> Dictionary:
	var seen: Dictionary = {}
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = 49 + depth
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
		&"mummy": ["idle_down", "walk_left", "attack_up", "hurt_right", "death"],
		&"scarab": ["idle_down", "walk_left", "attack_up", "hurt_right", "burrow", "emerge", "death"],
		&"sand_serpent": ["hidden_down", "emerge_left", "sink_up", "hurt_right", "death"],
	}
	var ok: bool = true
	for id: StringName in needs:
		var data: EnemyData = load(ENEMIES % id) as EnemyData
		for anim: String in needs[id]:
			ok = ok and data.sprite_frames.has_animation(anim)
		var attack: StringName = &"emerge_down" if id == &"sand_serpent" else &"attack_down"
		ok = ok and data.attack_strike_frame < data.sprite_frames.get_frame_count(attack)
		ok = ok and data.floor_style == &"sand" and data.weapon != null
	check(ok, "their frames have every animation the code plays, the strike inside the attack")
	var mummy: EnemyData = load(ENEMIES % &"mummy") as EnemyData
	check(mummy.hit_slow_time > 0.0 and mummy.hit_slow_mark != null
			and (load(ENEMIES % &"drowned") as EnemyData).hit_slow_mark != null,
			"the mummy's and the drowned's grips show on the player's legs")
	var made: Array[Enemy] = [_spawn(&"scarab", Vector2.ZERO, false), _spawn(&"sand_serpent", Vector2.ZERO, false),
			_spawn(&"mummy", Vector2.ZERO, false)]
	check(made[0] is Scarab and made[1] is SandSerpent and made[2].get_script() == load("res://actors/enemies/enemy.gd"),
			"the scarab and the serpent have their own scenes, the mummy is a plain enemy")
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


func _open_level() -> Level:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(OPEN_MAP))
	return level


func _test_mummy() -> void:
	var level: Level = _open_level()
	var player: Player = _player(level.cell_center(Vector2i(6, 2)), level)
	var mummy: Enemy = _spawn(&"mummy", level.cell_center(Vector2i(4, 2)), true, level)
	var slow_time: float = mummy.data.hit_slow_time
	var bandages: Texture2D = mummy.data.hit_slow_mark
	var hits: Array[DamageInfo] = []
	player.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	var frames: int = 0
	# The slow comes when the swing ends (Weapon.attack_performed), a little after the hit.
	while not player.is_slowed() and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
	var mark: StripSprite = player.get_node_or_null(^"SlowMark") as StripSprite
	check(not hits.is_empty() and hits[0].source_id == &"mummy" and player.is_slowed(),
			"the mummy's grip hurts and slows the player")
	check(mark != null and mark.visible and mark.texture == bandages, "bandages wrap the player's legs")
	mummy.queue_free()
	await physics_frames(roundi((slow_time + 0.2) * Engine.physics_ticks_per_second))
	check(not player.is_slowed() and mark != null and not mark.visible, "when the slow ends the bandages are gone")
	level.queue_free()
	await physics_frames(2)


func _test_scarab() -> void:
	var level: Level = _open_level()
	var player: Player = _player(level.cell_center(Vector2i(11, 2)), level)
	var scarab: Scarab = _spawn(&"scarab", level.cell_center(Vector2i(2, 2)), true, level) as Scarab
	var hits: Array[DamageInfo] = []
	player.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	var was_buried: bool = false
	var untouchable: bool = true
	var burrow_shown: bool = false
	var came_up_near: bool = false
	var frames: int = 0
	while hits.is_empty() and frames < TIMEOUT_FRAMES and is_instance_valid(scarab):
		await physics_frames(1)
		frames += 1
		var sprite: AnimatedSprite2D = scarab.visual as AnimatedSprite2D
		burrow_shown = burrow_shown or sprite.animation == &"burrow"
		if scarab.is_buried():
			if not was_buried:
				var hp: int = scarab.health.hp
				scarab.hurtbox.receive_hit(DamageInfo.new(5, player, &"test"))
				untouchable = scarab.health.hp == hp and scarab.hurtbox.collision_layer == 0 \
						and scarab.collision_layer == 0
			was_buried = true
		elif was_buried and not came_up_near:
			came_up_near = scarab.global_position.distance_to(player.global_position) <= 24.0
	check(was_buried and burrow_shown, "with the player far away it burrows")
	check(untouchable, "under the sand it cannot be hit and bumps into nothing but walls")
	check(came_up_near and not scarab.is_buried(), "it comes up beside the player")
	check(not hits.is_empty() and hits[0].source_id == &"scarab", "and bites")
	var hp_now: int = scarab.health.hp
	scarab.hurtbox.receive_hit(DamageInfo.new(1, player, &"test"))
	check(scarab.health.hp < hp_now, "on the surface it can be hit again")
	level.queue_free()
	await physics_frames(2)


func _test_serpent() -> void:
	var level: Level = _open_level()
	var player: Player = _player(level.cell_center(Vector2i(9, 2)), level)
	var spot: Vector2 = level.cell_center(Vector2i(3, 2))
	var serpent: SandSerpent = _spawn(&"sand_serpent", spot, true, level) as SandSerpent
	await physics_frames(5)
	var sprite: AnimatedSprite2D = serpent.visual as AnimatedSprite2D
	var ripple: StripSprite = serpent.get_node_or_null(^"Ripple") as StripSprite
	var hp: int = serpent.health.hp
	serpent.hurtbox.receive_hit(DamageInfo.new(5, player, &"test"))
	check(serpent.is_hidden() and String(sprite.animation).begins_with("hidden_") and ripple != null and ripple.visible,
			"it lies hidden under the sand with a ripple over it")
	check(serpent.health.hp == hp and serpent.hurtbox.collision_layer == 0, "hidden it cannot be hit")
	var hits: Array[DamageInfo] = []
	player.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	var crept: bool = false
	var emerged: bool = false
	var frames: int = 0
	while hits.is_empty() and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
		crept = crept or (serpent.is_hidden() and serpent.global_position.distance_to(spot) > 8.0)
		emerged = emerged or String(sprite.animation).begins_with("emerge_")
	check(crept, "it creeps towards the player under the sand")
	check(emerged and not serpent.is_hidden() and ripple != null and not ripple.visible, "it bursts out of the sand")
	check(not hits.is_empty() and hits[0].source_id == &"sand_serpent", "and bites the player")
	hp = serpent.health.hp
	var at: Vector2 = serpent.global_position
	serpent.hurtbox.receive_hit(DamageInfo.new(5, player, &"test", Vector2(300.0, 0.0)))
	await physics_frames(10)
	check(serpent.health.hp < hp and serpent.global_position.distance_to(at) < 0.5,
			"upright it can be hit, and no blow pushes it")
	var sank: bool = false
	frames = 0
	while not serpent.is_hidden() and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
		sank = sank or String(sprite.animation).begins_with("sink_")
	check(sank and serpent.is_hidden() and ripple.visible, "then it sinks back under the sand")
	level.queue_free()
	await physics_frames(2)
