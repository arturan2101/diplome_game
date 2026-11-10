extends SceneTree
## Headless test for MeleeWeapon: combo order, input buffer, combo reset, knockback,
## arc, reach, walls, one hit per step and DamageInfo.
## Builds a tiny scene in code, so it does not depend on .tscn files.
## Exit code = number of failed checks.
## Run: godot --headless --path . --script res://tests/test_melee_weapon.gd

const WIELDER_POSITION: Vector2 = Vector2(100.0, 100.0)
## Physics layer bits, same as the project layer names.
const WORLD_LAYER: int = 1
const ENEMY_HURTBOX_LAYER: int = 16
## Large enough that no target dies during the test.
const TARGET_HP: int = 1000
const TARGET_RADIUS: float = 8.0
const STEP_DAMAGE: int = 10
const FINISHER_DAMAGE: int = 18
const FINISHER_KNOCKBACK: float = 200.0
## Physics frames to let new bodies enter the physics space.
const SETTLE_FRAMES: int = 2

var _failures: int = 0
## One entry per attack_performed signal: x = step index, y = hits.
var _performed: Array[Vector2i] = []
var _received: Array[DamageInfo] = []


func _initialize() -> void:
	await process_frame

	# Timings at 60 physics frames per second: a step is busy for 0.3 s = 18 frames,
	# the buffer accepts presses in its last 0.1 s = 6 frames, the combo window is 15 frames.
	var stats: MeleeWeaponData = MeleeWeaponData.new()
	stats.id = &"sword"
	stats.combo = [_make_step(STEP_DAMAGE, 0.0), _make_step(STEP_DAMAGE, 0.0),
			_make_step(FINISHER_DAMAGE, FINISHER_KNOCKBACK)] as Array[MeleeAttackStep]
	stats.combo_window = 0.25
	stats.combo_end_cooldown = 0.2
	stats.buffer_window = 0.1

	var wielder: Node2D = Node2D.new()
	wielder.position = WIELDER_POSITION
	root.add_child(wielder)
	var weapon: MeleeWeapon = MeleeWeapon.new()
	weapon.setup(stats, wielder)
	weapon.attack_performed.connect(
			func(step_index: int, hits: int) -> void: _performed.append(Vector2i(step_index, hits)))
	wielder.add_child(weapon)

	var front: Hurtbox = _add_target(WIELDER_POSITION + Vector2(25.0, 0.0))
	var behind: Hurtbox = _add_target(WIELDER_POSITION + Vector2(-25.0, 0.0))
	var far: Hurtbox = _add_target(WIELDER_POSITION + Vector2(60.0, 10.0))
	var walled: Hurtbox = _add_target(WIELDER_POSITION + Vector2(0.0, 30.0))
	_add_wall(WIELDER_POSITION + Vector2(0.0, 15.0), Vector2(40.0, 4.0))
	front.hit_received.connect(func(info: DamageInfo) -> void: _received.append(info))
	await _physics_frames(SETTLE_FRAMES)

	# Step 1. A press early in the swing is not buffered, so no second step follows.
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(3)
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(20)
	_check(_performed == ([Vector2i(0, 1)] as Array[Vector2i]), "early press during a swing is ignored")
	_check(_damage_taken(front) == STEP_DAMAGE, "target in arc is hit exactly once per step")

	# Steps 2 and 3. A press in the last 0.1 s of step 2 starts step 3 by itself.
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(14)
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(40)
	_check(_performed == ([Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1)] as Array[Vector2i]),
			"combo goes 1 -> 2 -> 3, late press is buffered")
	_check(_damage_taken(front) == 2 * STEP_DAMAGE + FINISHER_DAMAGE, "each step has its own damage")
	_check(_received.size() == 3, "Hurtbox emits hit_received for every hit")
	if _received.size() == 3:
		_check(_received[0].knockback.is_zero_approx() and _received[1].knockback.is_zero_approx(),
				"steps 1 and 2 have no knockback")
		_check(_received[2].knockback.x > 0.0
				and is_equal_approx(_received[2].knockback.length(), FINISHER_KNOCKBACK),
				"step 3 pushes the target away from the wielder")
		_check(_received[0].source == wielder and _received[0].source_id == &"sword",
				"DamageInfo carries source and source_id")

	# A pause longer than combo_window resets the combo to step 1.
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(40)
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(20)
	_check(_performed[-1].x == 0, "combo resets after a long pause")

	# The only target below the wielder is behind a wall.
	weapon.try_attack(Vector2.DOWN)
	await _physics_frames(20)
	_check(_damage_taken(walled) == 0 and _performed[-1].y == 0, "wall blocks the hit")
	_check(_damage_taken(behind) == 0, "target behind the wielder is never hit")
	_check(_damage_taken(far) == 0, "target out of reach is never hit")

	# Putting the sword away mid-swing: the hit already landed stays, nothing more is hit.
	await _physics_frames(20)
	var performed_before_cancel: int = _performed.size()
	var damage_before_cancel: int = _damage_taken(front)
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(1)
	weapon.set_active(false)
	_check(_performed.size() == performed_before_cancel + 1 and _performed[-1].y == 1,
			"interrupted swing is reported with the hits it landed")
	var late: Hurtbox = _add_target(WIELDER_POSITION + Vector2(20.0, -12.0))
	await _physics_frames(10)
	_check(_damage_taken(late) == 0, "cancelled swing hits nothing more")
	_check(_damage_taken(front) > damage_before_cancel, "damage dealt before the cancel stays")

	# An inactive weapon ignores presses (wait until it is no longer busy, so only
	# the inactive state can block the press).
	await _physics_frames(20)
	var performed_while_inactive: int = _performed.size()
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(30)
	_check(_performed.size() == performed_while_inactive, "inactive weapon ignores attacks")

	# Back in hand: the combo starts over, and a buffered press is dropped by a swap.
	weapon.set_active(true)
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(14)
	weapon.try_attack(Vector2.RIGHT)
	weapon.set_active(false)
	await _physics_frames(30)
	_check(_performed.size() == performed_while_inactive + 1 and _performed[-1].x == 0,
			"combo starts over after a swap and the buffered press is dropped")

	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(_failures)


func _make_step(damage: int, knockback: float) -> MeleeAttackStep:
	var step: MeleeAttackStep = MeleeAttackStep.new()
	step.damage = damage
	step.reach = 40.0
	step.arc_degrees = 120.0
	step.duration = 0.1
	step.recovery = 0.2
	step.knockback = knockback
	return step


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
	root.add_child(hurtbox)
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
	root.add_child(wall)


func _damage_taken(hurtbox: Hurtbox) -> int:
	return TARGET_HP - hurtbox.health.hp


func _physics_frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		print("FAIL: ", description)
		_failures += 1
