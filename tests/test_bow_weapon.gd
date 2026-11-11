extends TestCase
## Headless test for BowWeapon and Arrow: tap threshold, draw damage and slowdown,
## cooldown, walls, range, DamageInfo, and an arrow outliving its bow.
## Builds a tiny scene in code, so it does not depend on .tscn files.

const WIELDER_POSITION: Vector2 = Vector2(100.0, 100.0)
## Physics layer bits, same as the project layer names.
const WORLD_LAYER: int = 1
const ENEMY_HURTBOX_LAYER: int = 16
## Large enough that no target dies during the test.
const TARGET_HP: int = 1000
const TARGET_RADIUS: float = 8.0
const MIN_DAMAGE: int = 6
const MAX_DAMAGE: int = 20
const SLOW_MULTIPLIER: float = 0.5
## Physics frames to let new bodies enter the physics space.
const SETTLE_FRAMES: int = 2
## Frames for an arrow to reach any target here (speed 600 px/s = 10 px per frame).
const FLIGHT_FRAMES: int = 25
## Frames that surely cover the 0.2 s cooldown.
const COOLDOWN_FRAMES: int = 15

## One entry per attack_performed signal: x = step index, y = hits.
var _performed: Array[Vector2i] = []
var _received: Array[DamageInfo] = []


func run() -> void:

	# At 60 physics frames per second: tap threshold 0.15 s = 9 frames,
	# full draw after 0.15 + 0.4 s = 33 frames.
	var stats: BowWeaponData = BowWeaponData.new()
	stats.id = &"bow"
	stats.min_damage = MIN_DAMAGE
	stats.max_damage = MAX_DAMAGE
	stats.tap_threshold = 0.15
	stats.draw_time = 0.4
	stats.draw_move_speed_multiplier = SLOW_MULTIPLIER
	stats.cooldown = 0.2
	stats.arrow_speed = 600.0
	stats.arrow_range = 300.0
	stats.arrow_scene = _make_arrow_scene()

	var wielder: Node2D = Node2D.new()
	wielder.position = WIELDER_POSITION
	add_child(wielder)
	var bow: BowWeapon = BowWeapon.new()
	bow.setup(stats, wielder)
	bow.attack_performed.connect(
			func(step_index: int, hits: int) -> void: _performed.append(Vector2i(step_index, hits)))
	wielder.add_child(bow)

	var front: Hurtbox = _add_target(WIELDER_POSITION + Vector2(60.0, 0.0))
	var walled: Hurtbox = _add_target(WIELDER_POSITION + Vector2(0.0, 60.0))
	var far_up: Hurtbox = _add_target(WIELDER_POSITION + Vector2(0.0, -200.0))
	_add_wall(WIELDER_POSITION + Vector2(0.0, 30.0), Vector2(40.0, 4.0))
	front.hit_received.connect(func(info: DamageInfo) -> void: _received.append(info))
	await physics_frames(SETTLE_FRAMES)

	# Tap: released before the threshold.
	bow.try_attack(Vector2.RIGHT)
	await physics_frames(3)
	check(is_equal_approx(bow.get_move_speed_multiplier(), 1.0), "tap does not slow the wielder")
	bow.release_attack(Vector2.RIGHT)
	await physics_frames(FLIGHT_FRAMES)
	check(_damage_taken(front) == MIN_DAMAGE, "tap shot deals min_damage")
	check(_performed == ([Vector2i(0, 1)] as Array[Vector2i]), "hit reports attack_performed(0, 1)")
	check(_received.size() == 1 and _received[0].source == wielder and _received[0].source_id == &"bow",
			"arrow DamageInfo has the wielder as source and the bow id")

	# Half draw: the slowdown grows gradually.
	await physics_frames(COOLDOWN_FRAMES)
	bow.try_attack(Vector2.RIGHT)
	await physics_frames(21)
	var half_multiplier: float = bow.get_move_speed_multiplier()
	check(half_multiplier < 0.9 and half_multiplier > 0.6, "slowdown grows with the draw")
	bow.release_attack(Vector2.RIGHT)
	await physics_frames(FLIGHT_FRAMES)
	var half_damage: int = _damage_taken(front) - MIN_DAMAGE
	check(half_damage > MIN_DAMAGE and half_damage < MAX_DAMAGE, "half draw deals damage between min and max")

	# Full draw.
	await physics_frames(COOLDOWN_FRAMES)
	var before_full: int = _damage_taken(front)
	bow.try_attack(Vector2.RIGHT)
	await physics_frames(40)
	check(is_equal_approx(bow.get_move_speed_multiplier(), SLOW_MULTIPLIER), "full draw slows the wielder to x0.5")
	bow.release_attack(Vector2.RIGHT)
	check(is_equal_approx(bow.get_move_speed_multiplier(), 1.0), "speed returns right after the shot")
	await physics_frames(FLIGHT_FRAMES)
	check(_damage_taken(front) - before_full == MAX_DAMAGE, "full draw deals max_damage")

	# Cooldown: a second tap right after a shot does nothing.
	await physics_frames(COOLDOWN_FRAMES)
	var shots_before: int = _performed.size()
	bow.try_attack(Vector2.RIGHT)
	bow.release_attack(Vector2.RIGHT)
	bow.try_attack(Vector2.RIGHT)
	bow.release_attack(Vector2.RIGHT)
	await physics_frames(FLIGHT_FRAMES)
	check(_performed.size() - shots_before == 1, "cooldown blocks tap spam")

	# Wall below the wielder.
	await physics_frames(COOLDOWN_FRAMES)
	bow.try_attack(Vector2.DOWN)
	bow.release_attack(Vector2.DOWN)
	await physics_frames(FLIGHT_FRAMES)
	check(_damage_taken(walled) == 0 and _performed[-1] == Vector2i(0, 0), "wall stops the arrow")

	# Nothing to the left: the arrow flies its range and disappears.
	await physics_frames(COOLDOWN_FRAMES)
	bow.try_attack(Vector2.LEFT)
	bow.release_attack(Vector2.LEFT)
	await physics_frames(40)
	check(_performed[-1] == Vector2i(0, 0) and _count_arrows() == 0, "arrow disappears after its range")

	# Putting a drawn bow away: the slowdown ends at once and no arrow comes out.
	await physics_frames(COOLDOWN_FRAMES)
	var shots_before_cancel: int = _performed.size()
	bow.try_attack(Vector2.RIGHT)
	await physics_frames(40)
	bow.set_active(false)
	check(is_equal_approx(bow.get_move_speed_multiplier(), 1.0), "putting the bow away ends the slowdown at once")
	bow.release_attack(Vector2.RIGHT)
	bow.set_active(true)
	bow.release_attack(Vector2.RIGHT)
	await physics_frames(FLIGHT_FRAMES)
	check(_performed.size() == shots_before_cancel and _count_arrows() == 0, "cancelled draw shoots nothing")

	# An inactive bow ignores presses.
	bow.set_active(false)
	bow.try_attack(Vector2.RIGHT)
	await physics_frames(20)
	check(is_equal_approx(bow.get_draw_progress(), 0.0), "inactive bow ignores presses")

	# The cooldown keeps running while the bow is put away.
	bow.set_active(true)
	bow.try_attack(Vector2.RIGHT)
	bow.release_attack(Vector2.RIGHT)
	bow.set_active(false)
	await physics_frames(COOLDOWN_FRAMES)
	bow.set_active(true)
	bow.try_attack(Vector2.RIGHT)
	bow.release_attack(Vector2.RIGHT)
	await physics_frames(FLIGHT_FRAMES)
	check(_performed.size() == shots_before_cancel + 2, "cooldown keeps running while the bow is put away")

	# The bow is freed while its arrow flies: no error, the arrow still hits.
	await physics_frames(COOLDOWN_FRAMES)
	var shots_before_free: int = _performed.size()
	bow.try_attack(Vector2.UP)
	bow.release_attack(Vector2.UP)
	await physics_frames(3)
	bow.free()
	await physics_frames(FLIGHT_FRAMES)
	check(_damage_taken(far_up) == MIN_DAMAGE, "arrow outlives its bow and still hits")
	check(_performed.size() == shots_before_free and _count_arrows() == 0,
			"landing after the bow is gone is ignored safely")


func _make_arrow_scene() -> PackedScene:
	var scene: PackedScene = PackedScene.new()
	var template: Arrow = Arrow.new()
	scene.pack(template)
	template.free()
	return scene


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


func _damage_taken(hurtbox: Hurtbox) -> int:
	return TARGET_HP - hurtbox.health.hp


func _count_arrows() -> int:
	return get_tree().current_scene.get_children().filter(func(node: Node) -> bool: return node is Arrow).size()
