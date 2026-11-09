extends SceneTree
## Headless test for MeleeWeapon: arc, reach, walls, one hit per swing, cooldown, DamageInfo.
## Builds a tiny scene in code, so it does not depend on .tscn files.
## Exit code = number of failed checks.
## Run: godot --headless --path . --script res://tests/test_melee_weapon.gd

const WIELDER_POSITION: Vector2 = Vector2(100.0, 100.0)
## Physics layer bits, same as the project layer names.
const WORLD_LAYER: int = 1
const ENEMY_HURTBOX_LAYER: int = 16
const TARGET_HP: int = 50
const TARGET_RADIUS: float = 8.0
## Physics frames to let new bodies enter the physics space.
const SETTLE_FRAMES: int = 2
## Physics frames that surely cover a whole swing (0.15 s = 9 frames at 60 Hz).
const SWING_FRAMES: int = 30
## Physics frames after which the swing is over but the cooldown is not (0.3 s = 18 frames).
const MID_COOLDOWN_FRAMES: int = 12

var _failures: int = 0
var _swing_results: Array[int] = []
var _received: Array[DamageInfo] = []


func _initialize() -> void:
	await process_frame

	var stats: MeleeWeaponData = MeleeWeaponData.new()
	stats.id = &"sword"
	stats.damage = 10
	stats.reach = 40.0
	stats.arc_degrees = 120.0
	stats.attack_duration = 0.15
	stats.cooldown = 0.3

	var wielder: Node2D = Node2D.new()
	wielder.position = WIELDER_POSITION
	root.add_child(wielder)
	var weapon: MeleeWeapon = MeleeWeapon.new()
	weapon.setup(stats, wielder)
	weapon.attack_finished.connect(func(targets_hit: int) -> void: _swing_results.append(targets_hit))
	wielder.add_child(weapon)

	var front: Health = _add_target(WIELDER_POSITION + Vector2(25.0, 0.0))
	var behind: Health = _add_target(WIELDER_POSITION + Vector2(-25.0, 0.0))
	var far: Health = _add_target(WIELDER_POSITION + Vector2(60.0, 10.0))
	var walled: Health = _add_target(WIELDER_POSITION + Vector2(0.0, 30.0))
	_add_wall(WIELDER_POSITION + Vector2(0.0, 15.0), Vector2(40.0, 4.0))
	front.damaged.connect(func(info: DamageInfo) -> void: _received.append(info))
	await _physics_frames(SETTLE_FRAMES)

	# Swing right: only the target in front is hit, and only once over many frames.
	weapon.try_attack(Vector2.RIGHT)
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(SWING_FRAMES)
	_check(front.hp == TARGET_HP - 10, "target in arc is hit exactly once per swing")
	_check(behind.hp == TARGET_HP, "target behind the wielder is not hit")
	_check(far.hp == TARGET_HP, "target out of reach is not hit")
	_check(_swing_results == ([1] as Array[int]), "attack_finished reports 1 target")
	_check(_received.size() == 1 and _received[0].amount == 10 and _received[0].source == wielder
			and _received[0].source_id == &"sword", "DamageInfo carries amount, source and source_id")

	# Swing down: the only target there is behind a wall.
	weapon.try_attack(Vector2.DOWN)
	await _physics_frames(SWING_FRAMES)
	_check(walled.hp == TARGET_HP, "wall blocks the hit")
	_check(_swing_results == ([1, 0] as Array[int]), "missed swing reports 0 targets")

	# Cooldown: an attack right after a finished swing is ignored.
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(MID_COOLDOWN_FRAMES)
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(SWING_FRAMES)
	_check(front.hp == TARGET_HP - 20, "attack during cooldown is ignored")
	weapon.try_attack(Vector2.RIGHT)
	await _physics_frames(SWING_FRAMES)
	_check(front.hp == TARGET_HP - 30, "attack works again after cooldown")

	print("ALL PASSED" if _failures == 0 else "%d FAILED" % _failures)
	quit(_failures)


func _add_target(at: Vector2) -> Health:
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
	return health


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


func _physics_frames(count: int) -> void:
	for _i in count:
		await physics_frame


func _check(condition: bool, description: String) -> void:
	if condition:
		print("PASS: ", description)
	else:
		print("FAIL: ", description)
		_failures += 1
