extends TestCase
## Headless test for stage 44: the easier parry (longer window, lighter slowdown, shorter
## cooldown after a miss), a parried projectile flying back at its shooter with double
## damage, a projectile from behind still landing, and the player's parry pose.

const PARRY: String = "res://combat/skills/parry.tres"
const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const ARROW_SCENE: String = "res://actors/projectiles/enemy_arrow.tscn"
const PLAYER_HURTBOX_LAYER: int = 8
const ENEMY_HURTBOX_LAYER: int = 16
const SHOOTER_HP: int = 1000
const ARROW_DAMAGE: int = 6
const ARROW_SPEED: float = 200.0
const ARROW_RANGE: float = 200.0
const ORIGIN: Vector2 = Vector2(100.0, 100.0)


func run() -> void:
	_test_numbers()
	await _test_reflect()
	await _test_from_behind()
	await _test_pose()


func _test_numbers() -> void:
	var parry: ParrySkillData = load(PARRY) as ParrySkillData
	check(is_equal_approx(parry.window, 0.5) and is_equal_approx(parry.move_speed_multiplier, 0.8)
			and is_equal_approx(parry.cooldown, 0.6), "easier parry: a 0.5 s window, slowed only to x0.8, 0.6 s after a miss")


## An archer's arrow caught in the window flies back and hits the archer for double.
func _test_reflect() -> void:
	var player: Player = await _add_player()
	var shooter: Hurtbox = _add_shooter(ORIGIN + Vector2(90.0, 0.0))
	var hits: Array[DamageInfo] = []
	shooter.health.damaged.connect(func(info: DamageInfo) -> void: hits.append(info))
	var parried: Array[int] = [0]
	(player.skill as ParrySkill).parried.connect(func(_info: DamageInfo) -> void: parried[0] += 1)
	var full_hp: int = player.health.hp
	_shoot(shooter, ORIGIN + Vector2(60.0, 0.0), Vector2.LEFT)
	player.skill.press(Vector2.RIGHT)
	await physics_frames(roundi(1.0 * Engine.physics_ticks_per_second))
	check(parried[0] == 1 and player.health.hp == full_hp, "the arrow is parried: no damage to the player")
	check(hits.size() == 1 and hits[0].amount == ARROW_DAMAGE * 2 and hits[0].source_id == ParrySkill.REFLECT_SOURCE_ID
			and hits[0].source == player, "it flies back and hits its shooter for double, as the player's hit (%s)"
			% [hits.map(func(info: DamageInfo) -> int: return info.amount)])
	check(get_tree().get_nodes_in_group(Arrow.GROUP).is_empty(), "and is gone after the hit")
	await _clean_up([player, shooter])


## The parry covers the front only: an arrow from behind still lands.
func _test_from_behind() -> void:
	var player: Player = await _add_player()
	var shooter: Hurtbox = _add_shooter(ORIGIN + Vector2(-90.0, 0.0))
	var full_hp: int = player.health.hp
	_shoot(shooter, ORIGIN + Vector2(-60.0, 0.0), Vector2.RIGHT)
	player.skill.press(Vector2.RIGHT)
	await physics_frames(roundi(0.6 * Engine.physics_ticks_per_second))
	check(player.health.hp == full_hp - ARROW_DAMAGE and shooter.health.hp == SHOOTER_HP,
			"an arrow from behind is not parried")
	await _clean_up([player, shooter])


func _test_pose() -> void:
	var player: Player = await _add_player()
	var sprite: AnimatedSprite2D = player.get_node(^"Sprite") as AnimatedSprite2D
	check(sprite.sprite_frames.has_animation(&"parry_right") and sprite.sprite_frames.get_frame_count(&"parry_right") == 3,
			"the player has the parry pose of batch 14")
	player.skill.press(Vector2.RIGHT)
	await physics_frames(2)
	# _process is not reliable in headless tests: one update by hand.
	sprite._process(1.0 / 60.0)
	check(String(sprite.animation).begins_with("parry_"), "the window shows it (%s)" % sprite.animation)
	await _clean_up([player])


func _add_player() -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = ORIGIN
	add_child(player)
	player.set_skill(load(PARRY) as SkillData)
	await physics_frames(2)
	return player


## A stand-in archer: a hurtbox on the enemy layer with plenty of health.
func _add_shooter(at: Vector2) -> Hurtbox:
	var hurtbox: Hurtbox = Hurtbox.new()
	hurtbox.position = at
	hurtbox.collision_layer = ENEMY_HURTBOX_LAYER
	hurtbox.collision_mask = 0
	var shape: CollisionShape2D = CollisionShape2D.new()
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = 6.0
	shape.shape = circle
	hurtbox.add_child(shape)
	var health: Health = Health.new()
	health.max_hp = SHOOTER_HP
	hurtbox.add_child(health)
	hurtbox.health = health
	add_child(hurtbox)
	return hurtbox


func _shoot(shooter: Node2D, from: Vector2, direction: Vector2) -> void:
	var arrow: Arrow = (load(ARROW_SCENE) as PackedScene).instantiate() as Arrow
	arrow.position = from
	arrow.target_mask = PLAYER_HURTBOX_LAYER
	arrow.setup(DamageInfo.new(ARROW_DAMAGE, shooter, &"archer"), direction, ARROW_SPEED, ARROW_RANGE)
	add_child(arrow)


func _clean_up(nodes: Array) -> void:
	for node: Node in nodes:
		node.queue_free()
	for arrow: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		arrow.queue_free()
	await physics_frames(2)
