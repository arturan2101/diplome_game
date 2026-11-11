extends TestCase
## Headless test for Enemy: detection range, chase, windup before the hit, damage source,
## the target's invulnerability, knockback interrupting the windup, and death.
## Builds everything in code, so it does not depend on .tscn files.

## Physics layer bits, same as the project layer names.
const WORLD_LAYER: int = 1
const ENEMY_LAYER: int = 4
const PLAYER_HURTBOX_LAYER: int = 8
const ENEMY_HURTBOX_LAYER: int = 16
const TARGET_HP: int = 100
const ENEMY_HIT: int = 10
const ENEMY_START: Vector2 = Vector2(100.0, 100.0)
## Windup of 0.4 s = 24 physics frames at 60 Hz.
const WINDUP: float = 0.4
## Upper bound when waiting for a state, in physics frames.
const STATE_TIMEOUT_FRAMES: int = 180

var _target_hits: Array[DamageInfo] = []


func run() -> void:
	var target_health: Health = Health.new()
	var target: Node2D = _add_target(Vector2(400.0, 100.0), target_health)
	target_health.damaged.connect(func(info: DamageInfo) -> void: _target_hits.append(info))
	var enemy: Enemy = _add_enemy(_make_skeleton_data(), ENEMY_START)
	await physics_frames(10)

	check(enemy.state == Enemy.State.IDLE and enemy.position.is_equal_approx(ENEMY_START),
			"enemy ignores a player outside the detection range")

	target.position = Vector2(220.0, 100.0)
	await physics_frames(5)
	check(enemy.state == Enemy.State.CHASE and enemy.position.x > ENEMY_START.x, "enemy notices and chases")

	await _wait_for_state(enemy, Enemy.State.WINDUP)
	check(enemy.state == Enemy.State.WINDUP, "enemy stops for a windup near the player")
	await physics_frames(12)
	check(_target_hits.is_empty(), "no damage during the windup")
	await physics_frames(20)
	check(_target_hits.size() == 1 and target_health.hp == TARGET_HP - ENEMY_HIT, "hit lands after the windup")
	check(_target_hits.size() == 1 and _target_hits[0].source == enemy and _target_hits[0].source_id == &"skeleton",
			"damage source is the enemy and source_id its type")
	check(target_health.is_invulnerable(), "the hit makes the player invulnerable")
	var target_hurtbox: Hurtbox = target.get_node("Hurtbox")
	var hit_signals: Array[DamageInfo] = []
	target_hurtbox.hit_received.connect(func(info: DamageInfo) -> void: hit_signals.append(info))
	target_hurtbox.receive_hit(DamageInfo.new(ENEMY_HIT, enemy, &"skeleton", Vector2(100.0, 0.0)))
	check(_target_hits.size() == 1 and hit_signals.is_empty(),
			"absorbed hit is not damage and does not reach hit_received (no knockback)")

	# A knockback during the windup cancels the attack.
	await _wait_for_state(enemy, Enemy.State.WINDUP)
	var hits_before: int = _target_hits.size()
	enemy.hurtbox.receive_hit(DamageInfo.new(1, null, &"sword", Vector2(-200.0, 0.0)))
	check(enemy.state == Enemy.State.STAGGER, "knockback interrupts the windup")
	await physics_frames(30)
	check(_target_hits.size() == hits_before, "interrupted windup deals no damage")

	enemy.hurtbox.receive_hit(DamageInfo.new(1000, null, &"sword"))
	await physics_frames(2)
	check(not is_instance_valid(enemy), "enemy is removed when it dies")


func _make_skeleton_data() -> EnemyData:
	var step: MeleeAttackStep = MeleeAttackStep.new()
	step.damage = ENEMY_HIT
	step.reach = 24.0
	step.arc_degrees = 120.0
	step.duration = 0.1
	step.recovery = 0.0
	var weapon_data: MeleeWeaponData = MeleeWeaponData.new()
	weapon_data.id = &"skeleton_blade"
	weapon_data.combo = [step] as Array[MeleeAttackStep]
	var weapon_template: MeleeWeapon = MeleeWeapon.new()
	weapon_template.target_mask = PLAYER_HURTBOX_LAYER
	weapon_data.weapon_scene = pack(weapon_template)

	var data: EnemyData = EnemyData.new()
	data.id = &"skeleton"
	data.max_hp = 30
	data.move_speed = 120.0
	data.detection_range = 160.0
	data.attack_range = 18.0
	data.windup = WINDUP
	data.recovery = 0.5
	data.weapon = weapon_data
	return data


func _add_target(at: Vector2, health: Health) -> Node2D:
	var target: Node2D = Node2D.new()
	target.position = at
	target.add_to_group(Player.GROUP)
	health.max_hp = TARGET_HP
	health.invulnerability_time = 0.5
	target.add_child(health)
	var hurtbox: Hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.collision_layer = PLAYER_HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.add_child(_circle_shape(6.0))
	hurtbox.health = health
	target.add_child(hurtbox)
	add_child(target)
	return target


func _add_enemy(data: EnemyData, at: Vector2) -> Enemy:
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
	hurtbox.collision_layer = ENEMY_HURTBOX_LAYER
	hurtbox.collision_mask = 0
	hurtbox.add_child(_circle_shape(7.0))
	hurtbox.health = health
	enemy.add_child(hurtbox)
	enemy.hurtbox = hurtbox
	var visual: Node2D = Node2D.new()
	enemy.add_child(visual)
	enemy.visual = visual
	add_child(enemy)
	return enemy


func _circle_shape(radius: float) -> CollisionShape2D:
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	return shape


func _wait_for_state(enemy: Enemy, wanted: Enemy.State) -> void:
	for _i in STATE_TIMEOUT_FRAMES:
		if enemy.state == wanted:
			return
		await get_tree().physics_frame
