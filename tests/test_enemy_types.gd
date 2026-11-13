extends TestCase
## Headless test for the core enemy types: the archer (shooting, short retreat with a
## cooldown, shooting at once with its back to a wall), line of sight before an attack,
## and the real enemy resources and scene (skeleton, archer, beetle pack).

const TILE: float = 16.0
const CATALOG_PATH: String = "res://actors/enemies/enemy_catalog.tres"
const ENEMY_SCENE_PATH: String = "res://actors/enemies/enemy.tscn"
## The archer stands with a wall right behind it (to the left), the player to the right.
const WALL_BEHIND_MAP: String = """##########
#........#
#........#
#........#
##########"""

var _hits: Array[DamageInfo] = []


func run() -> void:
	await _test_archer_shoots()
	await _test_archer_retreat()
	await _test_archer_cornered()
	await _test_line_of_sight()
	await _test_real_resources()


func _test_archer_shoots() -> void:
	var target: Node2D = _add_target(Vector2(220.0, 100.0))
	var archer: Enemy = _add_enemy(TestFactory.ranged_enemy_data(&"archer"), Vector2(100.0, 100.0))
	await physics_frames(3)
	check(archer.state == Enemy.State.WINDUP, "archer in range and far enough starts its windup at once")
	check(_hits.is_empty(), "no arrow before the windup ends")
	await physics_frames(45)
	check(_hits.size() == 1 and _hits[0].amount == 8 and _hits[0].source == archer and _hits[0].source_id == &"archer",
			"after the windup an arrow hits the player; source is the archer and its type")
	archer.queue_free()
	target.queue_free()
	await physics_frames(30)
	_hits.clear()


func _test_archer_retreat() -> void:
	var target: Node2D = _add_target(Vector2(140.0, 100.0))
	var archer: Enemy = _add_enemy(TestFactory.ranged_enemy_data(&"archer"), Vector2(100.0, 100.0))
	await physics_frames(3)
	check(archer.state == Enemy.State.RETREAT, "archer steps back when the player is too close")
	await physics_frames(20)
	check(archer.position.x < 99.0 and archer.state == Enemy.State.RETREAT, "it moves away from the player")
	await physics_frames(25)
	check(archer.state != Enemy.State.RETREAT, "the step back is short (at most retreat_time)")

	# The player closes in again: no second retreat during the cooldown.
	var retreated_again: bool = false
	for _i in 90:
		target.position = archer.position + Vector2(30.0, 0.0)
		if archer.state == Enemy.State.RETREAT:
			retreated_again = true
		await get_tree().physics_frame
	check(not retreated_again, "no second retreat during the retreat cooldown")
	var retreated_later: bool = false
	for _i in 120:
		target.position = archer.position + Vector2(30.0, 0.0)
		if archer.state == Enemy.State.RETREAT:
			retreated_later = true
			break
		await get_tree().physics_frame
	check(retreated_later, "after the cooldown the archer may step back again")
	archer.queue_free()
	target.queue_free()
	await physics_frames(30)
	_hits.clear()


func _test_archer_cornered() -> void:
	var level: Level = Level.new()
	add_child(level)
	level.build(LevelGrid.from_text(WALL_BEHIND_MAP))
	var target: Node2D = _add_target(Vector2(3.5, 2.5) * TILE)
	var archer: Enemy = _add_enemy(TestFactory.ranged_enemy_data(&"archer"), Vector2(1.5, 2.5) * TILE)
	await physics_frames(4)
	check(archer.state == Enemy.State.WINDUP, "with a wall behind, the archer shoots instead of retreating")
	archer.queue_free()
	target.queue_free()
	level.queue_free()
	await physics_frames(30)
	_hits.clear()


func _test_line_of_sight() -> void:
	var target: Node2D = _add_target(Vector2(116.0, 100.0))
	var wall: StaticBody2D = StaticBody2D.new()
	wall.position = Vector2(108.0, 100.0)
	wall.collision_layer = TestFactory.WORLD_LAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = Vector2(2.0, 60.0)
	shape.shape = rect
	wall.add_child(shape)
	add_child(wall)
	var data: EnemyData = TestFactory.melee_enemy_data(&"skeleton")
	data.move_speed = 0.0
	var skeleton: Enemy = _add_enemy(data, Vector2(100.0, 100.0))
	var wound_up: bool = false
	for _i in 60:
		if skeleton.state == Enemy.State.WINDUP:
			wound_up = true
		await get_tree().physics_frame
	check(not wound_up, "enemy does not attack a player it cannot see (wall between)")
	wall.queue_free()
	await physics_frames(5)
	check(skeleton.state == Enemy.State.WINDUP, "with the wall gone it attacks")
	skeleton.queue_free()
	target.queue_free()
	await physics_frames(3)


func _test_real_resources() -> void:
	var catalog: EnemyCatalog = load(CATALOG_PATH) as EnemyCatalog
	check(catalog != null and catalog.get_ids() == ([&"skeleton", &"archer", &"beetle", &"guardian"] as Array[StringName]),
			"enemy catalog lists skeleton, archer, beetle and the boss")
	if catalog == null:
		return
	var beetle: EnemyData = catalog.get_by_id(&"beetle")
	check(beetle.pack_min >= 4 and beetle.pack_max <= 8 and beetle.pack_min < beetle.pack_max,
			"beetles spawn as a pack (%d-%d) for one danger cost" % [beetle.pack_min, beetle.pack_max])
	check(catalog.get_by_id(&"archer").preferred_distance > 0.0 and catalog.get_by_id(&"skeleton").preferred_distance == 0.0,
			"only the archer keeps its distance")
	var scene: PackedScene = load(ENEMY_SCENE_PATH) as PackedScene
	var all_ready: bool = true
	for enemy_data: EnemyData in catalog.enemies:
		var enemy: Enemy = (enemy_data.scene if enemy_data.scene != null else scene).instantiate() as Enemy
		enemy.data = enemy_data
		enemy.position = Vector2(-500.0, -500.0)
		add_child(enemy)
		var sprite: Sprite2D = enemy.visual as Sprite2D
		if enemy.weapon == null or sprite == null or sprite.texture != enemy_data.sprite \
				or enemy.health.hp != enemy_data.max_hp or enemy_data.danger_cost <= 0:
			all_ready = false
		enemy.queue_free()
	check(all_ready, "every catalog enemy spawns (from enemy.tscn or its own scene) with weapon, sprite and HP from its data")
	await physics_frames(2)


func _add_target(at: Vector2) -> Node2D:
	var target: Node2D = TestFactory.player_target(1000)
	target.position = at
	(target.get_node("Health") as Health).damaged.connect(func(info: DamageInfo) -> void: _hits.append(info))
	add_child(target)
	return target


func _add_enemy(data: EnemyData, at: Vector2) -> Enemy:
	var enemy: Enemy = TestFactory.enemy(data)
	enemy.position = at
	add_child(enemy)
	return enemy
