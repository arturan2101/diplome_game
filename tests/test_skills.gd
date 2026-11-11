extends TestCase
## Headless test for the basic skills (dash, shield block) and the player's auto-aim.

const START: Vector2 = Vector2(100.0, 100.0)
## Physics layer bits, same as the project layer names.
const WORLD_LAYER: int = 1
const PLAYER_LAYER: int = 2
const ENEMY_LAYER: int = 4
const ENEMY_HURTBOX_LAYER: int = 16
const HIT: int = 10
const DASH_DISTANCE: float = 60.0

var _blocked: Array[DamageInfo] = []
var _used_count: int = 0


func run() -> void:
	await _test_dash()
	await _test_block()
	await _test_block_tap_mode()
	await _test_auto_aim()


func _test_dash() -> void:
	var data: DashSkillData = DashSkillData.new()
	data.id = &"dash"
	data.distance = DASH_DISTANCE
	data.duration = 0.2
	data.cooldown = 0.5
	data.skill_scene = pack(DashSkill.new())
	var player: Player = _add_player(START, data)
	player.collision_mask = WORLD_LAYER | ENEMY_LAYER
	player.skill.used.connect(func() -> void: _used_count += 1)
	await physics_frames(2)

	player.skill.press(Vector2.RIGHT)
	await physics_frames(3)
	check(player.skill.is_active() and player.health.is_invulnerable() and player.is_airborne,
			"dash makes the player invulnerable and airborne")
	check(player.collision_mask & ENEMY_LAYER == 0, "dash passes through enemies")
	check(player.skill.blocks_attacks(), "no attacks during the dash")
	await physics_frames(20)
	check(absf(player.position.x - (START.x + DASH_DISTANCE)) < 4.0 and absf(player.position.y - START.y) < 1.0,
			"dash covers its distance in the given direction")
	check(not player.skill.is_active() and not player.is_airborne and player.collision_mask & ENEMY_LAYER != 0,
			"dash ends: on the ground, collisions restored")

	var x_after_dash: float = player.position.x
	player.skill.press(Vector2.RIGHT)
	await physics_frames(5)
	check(is_equal_approx(player.position.x, x_after_dash) and _used_count == 1, "dash is blocked by its cooldown")
	check(player.skill.get_cooldown_fraction() > 0.0, "cooldown fraction is reported for the HUD")
	await physics_frames(30)
	player.skill.press(Vector2.ZERO)
	await physics_frames(20)
	check(player.position.x > x_after_dash + DASH_DISTANCE * 0.8 and _used_count == 2,
			"dash works again after the cooldown; without a direction it follows facing")
	player.queue_free()
	await physics_frames(2)


func _test_block() -> void:
	var data: BlockSkillData = _block_data(true)
	var player: Player = _add_player(START, data)
	player.hurtbox.hit_blocked.connect(func(info: DamageInfo) -> void: _blocked.append(info))
	var front_attacker: Enemy = _add_enemy(START + Vector2(20.0, 0.0))
	var back_attacker: Node2D = Node2D.new()
	back_attacker.position = START + Vector2(-20.0, 0.0)
	add_child(back_attacker)
	await physics_frames(2)
	player.facing = Vector2.RIGHT

	check(player.hurtbox.receive_hit(_hit_from(front_attacker, Vector2.LEFT)) and player.health.hp == 100 - HIT,
			"without the shield a frontal hit does damage")

	player.skill.press(Vector2.RIGHT)
	check(player.skill.is_active() and is_equal_approx(player.skill.get_move_speed_multiplier(), 0.7)
			and player.skill.blocks_attacks(), "raised shield slows the player and forbids attacks")
	check(not player.hurtbox.receive_hit(_hit_from(front_attacker, Vector2.LEFT)) and player.health.hp == 100 - HIT
			and _blocked.size() == 1 and _blocked[0].amount == HIT, "frontal hit is blocked and reported as blocked")
	check(front_attacker.state == Enemy.State.STAGGER and front_attacker.velocity.x > 0.0,
			"blocked melee attacker is pushed back")
	check(player.hurtbox.receive_hit(_hit_from(back_attacker, Vector2.RIGHT)) and player.health.hp == 100 - 2 * HIT,
			"hit from behind goes through the shield")
	var hazard: DamageInfo = DamageInfo.new(HIT, null, &"spikes")
	check(player.hurtbox.receive_hit(hazard) and _blocked.size() == 1, "hazard damage is not blocked")

	player.skill.release()
	check(not player.skill.is_active() and is_equal_approx(player.skill.get_move_speed_multiplier(), 1.0),
			"releasing the button lowers the shield")
	player.skill.press(Vector2.RIGHT)
	check(not player.skill.is_active(), "shield cannot be raised during its cooldown")
	await physics_frames(35)
	player.skill.press(Vector2.RIGHT)
	check(player.skill.is_active(), "shield works again after the cooldown")
	await physics_frames(100)
	check(not player.skill.is_active(), "shield lowers by itself after max_hold_time")
	player.queue_free()
	front_attacker.queue_free()
	back_attacker.queue_free()
	await physics_frames(2)


func _test_block_tap_mode() -> void:
	var player: Player = _add_player(START, _block_data(false))
	await physics_frames(2)
	player.skill.press(Vector2.RIGHT)
	player.skill.release()
	await physics_frames(10)
	check(player.skill.is_active(), "tap mode: the shield stays up after the release")
	await physics_frames(30)
	check(not player.skill.is_active(), "tap mode: the shield lowers after tap_duration")
	player.queue_free()
	await physics_frames(2)


func _test_auto_aim() -> void:
	var sword: MeleeWeaponData = MeleeWeaponData.new()
	sword.id = &"sword"
	sword.auto_aim_radius = 48.0
	sword.combo = [MeleeAttackStep.new()] as Array[MeleeAttackStep]
	sword.weapon_scene = pack(MeleeWeapon.new())
	var player: Player = _add_player(START, null)
	player.add_weapon(sword)
	player.facing = Vector2.RIGHT
	check(player.get_look_direction().is_equal_approx(Vector2.RIGHT), "without enemies the player looks where it moved")

	var near: Hurtbox = _add_target(START + Vector2(0.0, 30.0))
	var far: Hurtbox = _add_target(START + Vector2(0.0, -80.0))
	await physics_frames(2)
	check(player.get_look_direction().is_equal_approx(Vector2.DOWN), "auto-aim turns to the nearest enemy in range")
	near.queue_free()
	await physics_frames(2)
	check(player.get_look_direction().is_equal_approx(Vector2.RIGHT), "enemy outside the radius is ignored")

	var hidden: Hurtbox = _add_target(START + Vector2(-30.0, 0.0))
	_add_wall(START + Vector2(-15.0, 0.0), Vector2(4.0, 40.0))
	await physics_frames(2)
	check(player.get_look_direction().is_equal_approx(Vector2.RIGHT), "enemy behind a wall is ignored")
	player.queue_free()
	far.queue_free()
	hidden.queue_free()
	await physics_frames(2)


func _block_data(hold_mode: bool) -> BlockSkillData:
	var data: BlockSkillData = BlockSkillData.new()
	data.id = &"block"
	data.cooldown = 0.5
	data.hold_mode = hold_mode
	data.max_hold_time = 1.5
	data.tap_duration = 0.5
	data.skill_scene = pack(BlockSkill.new())
	return data


func _hit_from(attacker: Node2D, travel_direction: Vector2) -> DamageInfo:
	var info: DamageInfo = DamageInfo.new(HIT, attacker, &"skeleton")
	info.direction = travel_direction
	return info


func _add_player(at: Vector2, skill_data: SkillData) -> Player:
	var player: Player = Player.new()
	player.position = at
	player.collision_layer = PLAYER_LAYER
	player.collision_mask = WORLD_LAYER
	player.add_child(_circle_shape(6.0))
	var health: Health = Health.new()
	player.add_child(health)
	player.health = health
	var hurtbox: Hurtbox = Hurtbox.new()
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 0
	hurtbox.health = health
	player.add_child(hurtbox)
	player.hurtbox = hurtbox
	player.starting_skill = skill_data
	add_child(player)
	return player


func _add_enemy(at: Vector2) -> Enemy:
	var weapon_data: MeleeWeaponData = MeleeWeaponData.new()
	weapon_data.combo = [MeleeAttackStep.new()] as Array[MeleeAttackStep]
	weapon_data.weapon_scene = pack(MeleeWeapon.new())
	var data: EnemyData = EnemyData.new()
	data.id = &"skeleton"
	data.detection_range = 0.0
	data.weapon = weapon_data
	var enemy: Enemy = Enemy.new()
	enemy.data = data
	enemy.position = at
	enemy.collision_layer = ENEMY_LAYER
	enemy.collision_mask = WORLD_LAYER
	enemy.add_child(_circle_shape(6.0))
	var health: Health = Health.new()
	enemy.add_child(health)
	enemy.health = health
	var hurtbox: Hurtbox = Hurtbox.new()
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 0
	hurtbox.health = health
	enemy.add_child(hurtbox)
	enemy.hurtbox = hurtbox
	var visual: Node2D = Node2D.new()
	enemy.add_child(visual)
	enemy.visual = visual
	add_child(enemy)
	return enemy


func _add_target(at: Vector2) -> Hurtbox:
	var hurtbox: Hurtbox = Hurtbox.new()
	hurtbox.position = at
	hurtbox.collision_layer = ENEMY_HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.add_child(_circle_shape(7.0))
	var health: Health = Health.new()
	hurtbox.add_child(health)
	hurtbox.health = health
	add_child(hurtbox)
	return hurtbox


func _add_wall(at: Vector2, size: Vector2) -> void:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.position = at
	wall.collision_layer = WORLD_LAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)


func _circle_shape(radius: float) -> CollisionShape2D:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	return shape
