extends TestCase
## Headless test for stage 48, part 3: the Mycelium Mother, boss of the fungal floors.
## Her art has every animation the Guardian class plays under her own names; close by
## she bursts spores all round (a blow and a lingering cloud at her feet); at a distance
## roots burst from the floor in a line towards the player after a warning; she never
## throws; below half HP she roars, calls sporelings, and her shockwave is a spore ring.

const MOTHER: String = "res://actors/enemies/mycelium_mother.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const BIG_HP: int = 100000
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
const ANIMATIONS: Array[String] = ["idle", "walk", "spores", "roots", "summon", "roar", "hurt"]


func run() -> void:
	_test_data()
	await _test_spore_burst()
	await _test_roots()
	await _test_no_throw()
	await _test_phase_two()


func _test_data() -> void:
	var stats: GuardianData = load(MOTHER) as GuardianData
	var complete: bool = stats.sprite_frames.has_animation(&"death")
	for anim: String in ANIMATIONS:
		for dir: String in DIRECTIONS:
			complete = complete and stats.sprite_frames.has_animation(StringName(anim + "_" + dir))
	check(complete, "her frames have idle, walk, spores, roots, summon, roar and hurt in four directions and death")
	check(stats.is_boss and stats.floor_style == &"fungal" and stats.projectile_scene == null and stats.summon_id == &"sporeling",
			"a boss of the fungal floors, without a throw, calling sporelings")
	check(stats.special_animation == "roots" and stats.slam_animation == "spores" and stats.wave_animation == "roar",
			"her attacks use her own animations")
	var step: MeleeAttackStep = (stats.weapon as MeleeWeaponData).combo[0]
	check(is_equal_approx(step.arc_degrees, 360.0), "the spore burst hits all round her")
	var frames: SpriteFrames = stats.special_zone.frames
	check(frames.has_animation(stats.special_zone.shadow_animation) and frames.has_animation(stats.special_zone.impact_animation)
			and stats.shockwave_ring != null, "the roots have their warning and spike, the shockwave its spore ring")
	check(FileAccess.file_exists(Sound.MUSIC_DIR + String(stats.boss_music) + ".ogg")
			and FileAccess.file_exists(Sound.SFX_DIR + String(stats.roar_sound) + ".ogg")
			and FileAccess.file_exists(Sound.SFX_DIR + String(stats.special_zone.impact_sound) + ".ogg"),
			"her music, roar and roots sound exist")


func _test_spore_burst() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(7, 5))
	var boss: Guardian = _add_boss(level, Vector2i(8, 5))
	await physics_frames(3)
	check(boss.state == Enemy.State.WINDUP and boss.attack == Guardian.Attack.SLAM and boss.get_attack_animation() == "spores",
			"close by she winds up a spore burst")
	await physics_frames(roundi((boss.data.windup + 0.1) * Engine.physics_ticks_per_second))
	check(player.health.hp < BIG_HP, "the burst hits the player")
	var cloud: bool = false
	for zone: SpellZone in _zones():
		cloud = cloud or (zone.global_position.distance_to(boss.global_position) < 1.0 and not zone.is_falling())
	check(cloud, "and leaves a spore cloud at her feet")
	await _clean_up([boss, player, level])


func _test_roots() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(3, 5))
	var boss: Guardian = _add_boss(level, Vector2i(9, 5))
	boss._special_cooldown_left = 0.0
	await physics_frames(3)
	check(boss.state == Enemy.State.WINDUP and boss.attack == Guardian.Attack.SPECIAL and boss.get_attack_animation() == "roots",
			"at a distance she winds up her roots")
	var stats: GuardianData = boss.data as GuardianData
	await physics_frames(roundi((stats.special_windup + 0.1) * Engine.physics_ticks_per_second))
	var zones: Array[SpellZone] = _zones()
	var in_line: bool = zones.size() >= 4
	for zone: SpellZone in zones:
		in_line = in_line and absf(zone.global_position.y - boss.global_position.y) <= 1.0 and zone.is_falling()
	check(in_line, "cracks open in a line towards the player (%d)" % zones.size())
	check(player.health.hp == BIG_HP, "the warning does not hurt")
	await physics_frames(roundi((stats.special_zone.impact_delay + stats.special_stagger * stats.special_count + 0.1)
			* Engine.physics_ticks_per_second))
	check(BIG_HP - player.health.hp >= stats.special_zone.impact_damage[0],
			"a root under the player hits (%d)" % [BIG_HP - player.health.hp])
	await _clean_up([boss, player, level])


func _test_no_throw() -> void:
	var level: Level = _add_level()
	# Within sight (150 px) but out of reach of the burst: a Warden would throw here.
	var player: Player = _add_player(level, Vector2i(3, 5))
	var boss: Guardian = _add_boss(level, Vector2i(12, 5))
	boss._special_cooldown_left = 100.0
	player.set_physics_process(false)
	var wound_up: bool = false
	for _i in roundi(1.5 * Engine.physics_ticks_per_second):
		await physics_frames(1)
		wound_up = wound_up or boss.state == Enemy.State.WINDUP
	check(not wound_up and boss.global_position.x < level.cell_center(Vector2i(12, 5)).x,
			"while her roots wait she walks closer and throws nothing")
	await _clean_up([boss, player, level])


func _test_phase_two() -> void:
	var level: Level = _add_level()
	var player: Player = _add_player(level, Vector2i(2, 5))
	var boss: Guardian = _add_boss(level, Vector2i(12, 5))
	await physics_frames(2)
	var summoned: Array[int] = []
	boss.summon_requested.connect(func(_boss: Guardian, count: int) -> void: summoned.append(count))
	boss.health.take_damage(DamageInfo.new(boss.health.max_hp / 2 + 1, player, &"test"))
	check(boss.phase == 2 and boss.is_roaring() and summoned == [(boss.data as GuardianData).summon_count],
			"below half HP she roars and calls sporelings")
	boss.attack = Guardian.Attack.SHOCKWAVE
	check(boss.get_attack_animation() == "roar", "her shockwave is a spore blast")
	boss._show_ring()
	var ring: bool = false
	for child: Node in boss.get_parent().get_children():
		ring = ring or (child is StripSprite and (child as StripSprite).texture == (boss.data as GuardianData).shockwave_ring)
	check(ring, "with the spore ring")
	for child: Node in boss.get_parent().get_children():
		if child is StripSprite:
			child.queue_free()
	await _clean_up([boss, player, level])
	# Let the long roar finish, so its sound is not still playing when the tests quit.
	await get_tree().create_timer(3.0).timeout


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


func _add_boss(level: Level, cell: Vector2i) -> Guardian:
	var stats: GuardianData = load(MOTHER) as GuardianData
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
