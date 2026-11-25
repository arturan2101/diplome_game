extends TestCase
## Headless test for stage 45: the boss of each floor style (Ruins Warden, Tide Warden
## on the flooded floors, Molten Warden on the fire floors, only with
## ExperimentConfig.elemental_bosses), their art, the Tide Warden's geysers in a line,
## the puddle that slows the player, the Molten Warden's meteors on the player and the
## lava cracks of its slam, and the boss chest's own picture.

const TIDE: String = "res://actors/enemies/tide_warden.tres"
const MOLTEN: String = "res://actors/enemies/molten_warden.tres"
const PUDDLE: String = "res://actors/enemies/boss_effects/tide_puddle.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const CLEAN: String = "res://experiment/clean.tres"
const BIG_HP: int = 100000
const PLAYER_HURTBOX_LAYER: int = 8
const ROOM_MAP: String = """###############
#.............#
#.............#
#.............#
#.............#
#.............#
#.............#
#.............#
#.............#
#.............#
###############"""
const DIRECTIONS: Array[String] = ["down", "left", "right", "up"]
const WARDEN_ANIMATIONS: Array[String] = ["idle", "walk", "slam", "throw", "wave", "summon", "roar", "hurt"]


func run() -> void:
	_test_boss_by_floor()
	_test_art()
	await _test_geysers()
	await _test_puddle()
	await _test_meteors()
	await _test_lava_slam()


func _test_boss_by_floor() -> void:
	var saved: ExperimentConfig = GameManager.config
	check(GameManager.config.elemental_bosses, "the default config has the elemental bosses on")
	var director: Director = GameManager.make_director()
	var ids: Array[StringName] = []
	# The last depth of each style (stage 48 moved the flooded and fire floors deeper).
	var table: FloorStyleTable = GameManager.floor_style_table()
	for style: StringName in [&"ruins", &"flooded", &"fire"]:
		var depth: int = 0
		while table.style_at(depth) != style:
			depth += 1
		ids.append(director.boss_for_depth(depth + table.depths_per_style - 1).id)
	check(ids == ([&"guardian", &"tide_warden", &"molten_warden"] as Array[StringName]),
			"ruins, flooded and fire floors end with their own boss: %s" % [ids])
	GameManager.config = load(CLEAN) as ExperimentConfig
	check(not GameManager.config.elemental_bosses, "the clean series has no elemental bosses")
	var clean: Director = GameManager.make_director()
	check(clean.boss_for_depth(3).id == &"guardian", "without them every boss is the Ruins Warden")
	GameManager.config = saved
	var catalog_ids: Array[StringName] = []
	for enemy_data: EnemyData in director.catalog.enemies:
		catalog_ids.append(enemy_data.id)
	check(catalog_ids.has(&"tide_warden") and catalog_ids.has(&"molten_warden"), "both are in the enemy catalog")


func _test_art() -> void:
	var tide: GuardianData = load(TIDE) as GuardianData
	var molten: GuardianData = load(MOLTEN) as GuardianData
	var complete: bool = true
	for boss: GuardianData in [tide, molten]:
		for anim: String in WARDEN_ANIMATIONS + [boss.special_animation]:
			for dir: String in DIRECTIONS:
				if not boss.sprite_frames.has_animation(StringName(anim + "_" + dir)):
					complete = false
		if not boss.sprite_frames.has_animation(&"death"):
			complete = false
	check(complete, "both have every Warden animation in four directions, death and their special attack")
	check(tide.floor_style == &"flooded" and molten.floor_style == &"fire" and tide.is_boss and molten.is_boss,
			"the Tide Warden belongs to the flooded floors, the Molten Warden to the fire floors")
	var chest: Chest = (load("res://actors/pickups/chest_boss.tscn") as PackedScene).instantiate() as Chest
	check((chest.sprite as Sprite2D).texture.resource_path.ends_with("chest_boss.png"), "the boss chest has its own picture")
	chest.free()


## The Tide Warden's special attack: geysers in a line towards the player, a warning first.
func _test_geysers() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(4, 5))
	var boss: Guardian = _add_boss(TIDE, level, Vector2i(9, 5))
	boss._special_cooldown_left = 0.0
	await physics_frames(3)
	check(boss.state == Enemy.State.WINDUP and boss.attack == Guardian.Attack.SPECIAL and boss.get_attack_animation() == "geyser",
			"at a distance the Tide Warden winds up its geysers")
	var stats: GuardianData = boss.data as GuardianData
	await physics_frames(roundi((stats.special_windup + 0.1) * Engine.physics_ticks_per_second))
	var zones: Array[SpellZone] = _zones()
	var in_line: bool = zones.size() == stats.special_count
	for zone: SpellZone in zones:
		if absf(zone.global_position.y - boss.global_position.y) > 1.0 or not zone.is_falling():
			in_line = false
	check(in_line, "%d geysers wait in a line towards the player (%d)" % [stats.special_count, zones.size()])
	check(player.health.hp == BIG_HP, "the warning does not hurt")
	await physics_frames(roundi((stats.special_zone.impact_delay + stats.special_stagger * stats.special_count) * Engine.physics_ticks_per_second))
	check(BIG_HP - player.health.hp == stats.special_zone.impact_damage[0], "a geyser under the player hits for %d (%d)"
			% [stats.special_zone.impact_damage[0], BIG_HP - player.health.hp])
	await _clean_up([boss, player, level])


## The water orb's puddle only slows the player.
func _test_puddle() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(4, 5))
	await physics_frames(2)
	SpellZone.spawn(level, player.global_position, load(PUDDLE) as ZoneData, 1, null, &"tide_warden",
			PLAYER_HURTBOX_LAYER, 1)
	await physics_frames(roundi(0.3 * Engine.physics_ticks_per_second))
	check(player.is_slowed() and player.health.hp == BIG_HP, "standing in the puddle slows, without damage")
	await _clean_up([player, level])


## The Molten Warden's meteors: the first falls on the player, the rest around them.
func _test_meteors() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(4, 5))
	var boss: Guardian = _add_boss(MOLTEN, level, Vector2i(10, 5))
	boss._special_cooldown_left = 0.0
	await physics_frames(3)
	check(boss.attack == Guardian.Attack.SPECIAL and boss.get_attack_animation() == "meteor", "the Molten Warden winds up its meteors")
	var stats: GuardianData = boss.data as GuardianData
	await physics_frames(roundi((stats.special_windup + 0.1) * Engine.physics_ticks_per_second))
	var zones: Array[SpellZone] = _zones()
	var on_player: bool = false
	for zone: SpellZone in zones:
		if zone.global_position.distance_to(player.global_position) < 1.0:
			on_player = true
	check(zones.size() >= 2 and zones.size() <= stats.special_count and on_player,
			"meteors fall on the player and around them (%d)" % zones.size())
	await physics_frames(roundi((stats.special_zone.impact_delay + 0.1) * Engine.physics_ticks_per_second))
	check(BIG_HP - player.health.hp >= stats.special_zone.impact_damage[0], "the one on the player hits")
	await _clean_up([boss, player, level])


## The Molten Warden's slam leaves lava cracks in front of it.
func _test_lava_slam() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(7, 5))
	var boss: Guardian = _add_boss(MOLTEN, level, Vector2i(8, 5))
	await physics_frames(3)
	check(boss.attack == Guardian.Attack.SLAM, "close by it slams")
	await physics_frames(roundi((boss.data.windup + 0.1) * Engine.physics_ticks_per_second))
	var cracks: bool = false
	for zone: SpellZone in _zones():
		if zone.global_position.x < boss.global_position.x and not zone.is_falling():
			cracks = true
	check(cracks, "and leaves lava cracks in front of it")
	await _clean_up([boss, player, level])


func _zones() -> Array[SpellZone]:
	var found: Array[SpellZone] = []
	for node: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		if node is SpellZone:
			found.append(node as SpellZone)
	return found


func _add_level() -> Level:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(ROOM_MAP))
	return level


func _add_player(level: Level, cell: Vector2i) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.global_position = level.cell_center(cell)
	player.health.max_hp = BIG_HP
	player.health.reset()
	return player


func _add_boss(path: String, level: Level, cell: Vector2i) -> Guardian:
	var stats: GuardianData = load(path) as GuardianData
	var boss: Guardian = stats.scene.instantiate() as Guardian
	boss.data = stats
	add_child(boss)
	boss.global_position = level.cell_center(cell)
	return boss


func _clean_up(nodes: Array) -> void:
	for node: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		node.queue_free()
	for node: Node in nodes:
		node.queue_free()
	await physics_frames(2)
