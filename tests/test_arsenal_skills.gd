extends TestCase
## Headless test for batch 8's basic skills (stage 39): the parry (a blow from the front
## within the window is turned aside, the attacker is stunned, the next hit is a sure
## critical hit, a miss costs the full cooldown) and the short teleport (over a pit,
## never through a wall, stays put when there is nowhere to land), and the menu that
## offers them only with ExperimentConfig.arsenal.

const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const PARRY: String = "res://combat/skills/parry.tres"
const TELEPORT: String = "res://combat/skills/teleport.tres"
const MENU_SCENE: String = "res://ui/main_menu.tscn"
const CLEAN: String = "res://experiment/clean.tres"
const TILE: float = 16.0
## A corridor with a pit two cells wide, ending in a wall.
const PIT_MAP: String = """############
#..~~.....##
############"""
## Only pit ahead, then a wall: nowhere to land.
const ALL_PIT_MAP: String = """##########
#.~~~~~~~#
##########"""


func run() -> void:
	await _test_parry()
	await _test_stun()
	await _test_teleport()
	await _test_menu()


func _test_parry() -> void:
	var parry: ParrySkillData = load(PARRY) as ParrySkillData
	var player: Player = await _add_player(Vector2(100.0, 100.0), parry)
	var skill: ParrySkill = player.skill as ParrySkill
	var enemy: Enemy = TestFactory.enemy(TestFactory.melee_enemy_data(&"test_skeleton"))
	enemy.position = Vector2(124.0, 100.0)
	add_child(enemy)
	await physics_frames(1)
	var full_hp: int = player.health.hp
	check(player.hurtbox.receive_hit(_blow(enemy, Vector2.LEFT)) and player.health.hp == full_hp - 10,
			"without a parry the blow lands")
	player.health.reset()
	var parried: Array[int] = [0]
	skill.parried.connect(func(_info: DamageInfo) -> void: parried[0] += 1)
	skill.press(Vector2.RIGHT)
	check(skill.is_active() and skill.blocks_attacks() and is_equal_approx(skill.get_move_speed_multiplier(), parry.move_speed_multiplier),
			"the window is open: slowed, no attacks")
	var blocked: Array[int] = [0]
	player.hurtbox.hit_blocked.connect(func(info: DamageInfo) -> void: blocked[0] += info.amount)
	check(not player.hurtbox.receive_hit(_blow(enemy, Vector2.LEFT)) and player.health.hp == full_hp
			and parried[0] == 1 and blocked[0] == 10, "a blow from the front is parried and counted as blocked")
	check(enemy.is_stunned() and player.health.is_invulnerable() and not skill.is_active(),
			"the attacker is stunned, the player briefly invulnerable, the window closed")
	check(skill.get_cooldown_fraction() > 0.0 and skill.get_cooldown_fraction() <= parry.success_cooldown / parry.cooldown + 0.01,
			"a successful parry has only a short cooldown")
	check(player.consume_sure_crit() and not player.consume_sure_crit(), "the next hit is a sure critical hit")
	await physics_frames(roundi(0.5 * Engine.physics_ticks_per_second))
	player.health.end_invulnerability()

	skill.press(Vector2.RIGHT)
	check(player.hurtbox.receive_hit(_blow(enemy, Vector2.RIGHT)) and player.health.hp < full_hp,
			"a blow from behind goes through the parry")
	await physics_frames(roundi((parry.window + 0.05) * Engine.physics_ticks_per_second))
	check(not skill.is_active() and skill.get_cooldown_fraction() > 0.8, "a parry that caught nothing costs the full cooldown")
	await _clean_up([player, enemy])


## Stunned enemies stand dazed for the stun time; bosses are never stunned.
func _test_stun() -> void:
	var enemy: Enemy = TestFactory.enemy(TestFactory.melee_enemy_data(&"test_skeleton"))
	enemy.position = Vector2(300.0, 300.0)
	add_child(enemy)
	await physics_frames(1)
	enemy.stun(0.5, Vector2(40.0, 0.0))
	check(enemy.state == Enemy.State.STAGGER and enemy.is_stunned(), "stun: the enemy staggers")
	await physics_frames(roundi(0.3 * Engine.physics_ticks_per_second))
	check(enemy.is_stunned(), "still dazed after its push ran out")
	await physics_frames(roundi(0.3 * Engine.physics_ticks_per_second))
	check(not enemy.is_stunned() and enemy.state != Enemy.State.STAGGER, "and back after the stun time")
	var boss_data: EnemyData = TestFactory.melee_enemy_data(&"test_boss")
	boss_data.is_boss = true
	var boss: Enemy = TestFactory.enemy(boss_data)
	boss.position = Vector2(400.0, 300.0)
	add_child(boss)
	await physics_frames(1)
	boss.stun(1.0)
	check(not boss.is_stunned(), "a boss is not stunned")
	await _clean_up([enemy, boss])


func _test_teleport() -> void:
	var teleport: TeleportSkillData = load(TELEPORT) as TeleportSkillData
	var level: Level = _add_level(PIT_MAP)
	var player: Player = await _add_player(_center(1, 1), teleport)
	var skill: TeleportSkill = player.skill as TeleportSkill
	var start: Vector2 = player.global_position
	skill.press(Vector2.RIGHT)
	var moved: float = player.global_position.x - start.x
	check(absf(moved - teleport.distance) < 0.01 and level.cell_type_at(player.global_position) == LevelGrid.Cell.FLOOR,
			"the teleport jumps the full distance over the pit onto floor (%.0f px)" % moved)
	check(player.health.is_invulnerable() and not skill.is_ready(), "invulnerable for a moment, then the cooldown")
	await physics_frames(roundi((teleport.cooldown + 0.1) * Engine.physics_ticks_per_second))
	player.global_position = _center(8, 1)
	await physics_frames(1)
	skill.press(Vector2.RIGHT)
	var wall_x: float = 10.0 * TILE
	check(player.global_position.x > _center(8, 1).x and player.global_position.x <= wall_x - teleport.body_radius,
			"towards a wall it stops in front of it (x %.0f, wall at %.0f)" % [player.global_position.x, wall_x])
	await _clean_up([player, level])

	level = _add_level(ALL_PIT_MAP)
	player = await _add_player(_center(1, 1), teleport)
	start = player.global_position
	player.skill.press(Vector2.RIGHT)
	check(level.cell_at(player.global_position) == Vector2i(1, 1), "with only pit ahead the player stays on their own cell")
	await _clean_up([player, level])


func _test_menu() -> void:
	var saved: ExperimentConfig = GameManager.config
	var menu: Control = (load(MENU_SCENE) as PackedScene).instantiate() as Control
	add_child(menu)
	await physics_frames(1)
	var ids: Array[StringName] = []
	for skill_data: SkillData in menu.get_offered_skills():
		ids.append(skill_data.id)
	check(ids == ([&"dash", &"block", &"parry", &"teleport"] as Array[StringName]), "the full game offers four skills: %s" % [ids])
	GameManager.config = load(CLEAN) as ExperimentConfig
	menu._show_loadout(true)
	check(menu.skill_row.get_children().filter(func(button: Node) -> bool: return not button.is_queued_for_deletion()).size() == 2,
			"the clean series offers only the dash and the block")
	GameManager.config = saved
	menu.queue_free()
	await physics_frames(1)


func _blow(enemy: Enemy, direction: Vector2) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new(10, enemy, &"test_skeleton")
	info.direction = direction
	return info


func _add_player(at: Vector2, skill_data: SkillData) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = at
	add_child(player)
	player.set_skill(skill_data)
	await physics_frames(2)
	return player


func _add_level(map: String) -> Level:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(map))
	return level


func _center(x: int, y: int) -> Vector2:
	return Vector2(x + 0.5, y + 0.5) * TILE


func _clean_up(nodes: Array) -> void:
	for node: Node in nodes:
		node.queue_free()
	await physics_frames(2)
