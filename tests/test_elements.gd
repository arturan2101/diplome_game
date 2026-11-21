extends TestCase
## Headless test for the element system of stage 40: the enemy statuses (wet, rooted,
## slowed), earth's stone spikes, and the effects of the pairs and the third tier:
## plasma, lava, vines, sandstorm, lightning (wet enemies take more), volcanic
## lightning, storm cloud and meteor.

const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const SPELLS: String = "res://combat/spells/%s.tres"
const ENEMY_HURTBOX_LAYER: int = 16
const WORLD_LAYER: int = 1
const TARGET_HP: int = 1000
const TARGET_RADIUS: float = 8.0
const HP: int = 1000


func run() -> void:
	await _test_statuses()
	await _test_stone_spikes()
	await _test_plasma()
	await _test_lava_and_meteor()
	await _test_vines_and_sandstorm()
	await _test_lightning()
	await _test_storm_cloud()


func _test_statuses() -> void:
	var enemy: Enemy = await _add_enemy(Vector2(900.0, 900.0))
	var speed: float = enemy.data.move_speed
	enemy.make_wet(0.1)
	enemy.slow(0.5, 0.1)
	check(enemy.is_wet() and enemy.is_slowed() and is_equal_approx(enemy.get_walk_speed(), speed * 0.5),
			"wet and slowed: walks at half speed")
	enemy.root(0.1)
	check(enemy.is_rooted() and enemy.get_walk_speed() == 0.0, "rooted: does not walk")
	await physics_frames(roundi(0.2 * Engine.physics_ticks_per_second))
	check(not enemy.is_wet() and not enemy.is_slowed() and not enemy.is_rooted()
			and is_equal_approx(enemy.get_walk_speed(), speed), "statuses wear off")
	var boss_data: EnemyData = TestFactory.melee_enemy_data(&"boss_test")
	boss_data.is_boss = true
	var boss: Enemy = TestFactory.enemy(boss_data)
	add_child(boss)
	await physics_frames(1)
	boss.root(1.0)
	check(not boss.is_rooted(), "a boss is not rooted")
	await _clean_up([enemy, boss])


## A line of spikes stops at a wall; the enemy on it is hurt and stunned, a target off
## the line and one behind the wall are not.
func _test_stone_spikes() -> void:
	var spikes: StoneSpikesData = _spell("stone_spikes") as StoneSpikesData
	var origin: Vector2 = Vector2(100.0, 100.0)
	var player: Player = await _add_player(origin)
	var on_line: Enemy = await _add_enemy(origin + Vector2(20.0, 0.0))
	var aside: Hurtbox = _add_target(origin + Vector2(30.0, 30.0))
	var wall: StaticBody2D = _add_wall(origin + Vector2(42.0, 0.0), Vector2(4.0, 40.0))
	var behind: Hurtbox = _add_target(origin + Vector2(50.0, 0.0))
	await physics_frames(2)
	player.spell_book.learn(spikes)
	player.spell_book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(2)
	check(on_line.health.hp == HP - SpellData.int_at(spikes.damage, 1) and on_line.is_stunned(),
			"an enemy on the line is hurt and stunned")
	check(aside.health.hp == TARGET_HP and behind.health.hp == TARGET_HP, "off the line and behind a wall: untouched")
	await _clean_up([player, on_line, aside, wall, behind])


## The plasma flies through two targets in its way (full damage each) and bursts at the
## wall, sparing them but hurting a third one beside the wall.
func _test_plasma() -> void:
	var plasma: FireballData = _spell("plasma") as FireballData
	var origin: Vector2 = Vector2(100.0, 300.0)
	var player: Player = await _add_player(origin)
	var first: Hurtbox = _add_target(origin + Vector2(40.0, 0.0))
	var second: Hurtbox = _add_target(origin + Vector2(80.0, 0.0))
	var by_wall: Hurtbox = _add_target(origin + Vector2(140.0, 12.0))
	var wall: StaticBody2D = _add_wall(origin + Vector2(152.0, 0.0), Vector2(4.0, 8.0))
	await physics_frames(2)
	player.spell_book.learn(plasma)
	var reported: Array[int] = [0]
	player.spell_book.spell_damage_dealt.connect(func(_id: StringName, amount: int) -> void: reported[0] += amount)
	player.spell_book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(60)
	var damage: int = SpellData.int_at(plasma.damage, 1)
	check(first.health.hp == TARGET_HP - damage and second.health.hp == TARGET_HP - damage,
			"the plasma hurts both targets in its way once (%d each)" % damage)
	check(by_wall.health.hp == TARGET_HP - damage and reported[0] == damage * 3,
			"it bursts at the wall: the target there is hurt, %d reported" % reported[0])
	await _clean_up([player, first, second, by_wall, wall])


func _test_lava_and_meteor() -> void:
	var lava: ZoneData = _spell("lava") as ZoneData
	var origin: Vector2 = Vector2(100.0, 500.0)
	var player: Player = await _add_player(origin)
	var target: Hurtbox = _add_target(origin + Vector2(60.0, 0.0))
	await physics_frames(2)
	player.spell_book.learn(lava)
	player.spell_book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(2)
	check(target.health.hp < TARGET_HP, "the lava lands on the enemy and burns at once")
	await physics_frames(roundi((SpellData.float_at(lava.duration, 1) + 0.5) * Engine.physics_ticks_per_second))
	check(target.health.hp == TARGET_HP - roundi(lava.power_at(1)),
			"over its time it burns exactly power_at(1) = %d (took %d)" % [roundi(lava.power_at(1)), TARGET_HP - target.health.hp])
	check(_count(SpellZone) == 0, "then the pool is gone")
	target.health.reset()

	var meteor: ZoneData = _spell("meteor") as ZoneData
	player.spell_book.replace(0, meteor)
	await physics_frames(1)
	player.spell_book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(roundi(meteor.impact_delay * 0.5 * Engine.physics_ticks_per_second))
	check(target.health.hp == TARGET_HP, "the meteor is still falling: nothing yet")
	await physics_frames(roundi((meteor.impact_delay * 0.5 + SpellData.float_at(meteor.duration, 1) + 0.5)
			* Engine.physics_ticks_per_second))
	check(target.health.hp == TARGET_HP - roundi(meteor.power_at(1)),
			"impact and lava: %d in all (took %d)" % [roundi(meteor.power_at(1)), TARGET_HP - target.health.hp])
	await _clean_up([player, target])


func _test_vines_and_sandstorm() -> void:
	var vines: ZoneData = _spell("vines") as ZoneData
	var origin: Vector2 = Vector2(100.0, 700.0)
	var player: Player = await _add_player(origin)
	var enemy: Enemy = await _add_enemy(origin + Vector2(80.0, 0.0))
	player.spell_book.learn(vines)
	player.spell_book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(2)
	var at: Vector2 = enemy.global_position
	await physics_frames(20)
	check(enemy.is_rooted() and enemy.global_position.distance_to(at) < 1.0, "the vines hold the enemy in place")
	await _clean_up([enemy])

	var sandstorm: WhirlwindData = _spell("sandstorm") as WhirlwindData
	enemy = await _add_enemy(origin + Vector2(30.0, 0.0))
	player.spell_book.replace(0, sandstorm)
	await physics_frames(1)
	player.spell_book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(2)
	check(enemy.is_slowed() and is_equal_approx(enemy.get_walk_speed(), enemy.data.move_speed * sandstorm.slow_multiplier)
			and enemy.health.hp < HP, "the sandstorm hurts and slows the enemies in it")
	await _clean_up([player, enemy])


## Lightning strikes the nearest enemy and jumps to the next ones (three at level 1);
## a wet enemy takes 1.5 times the damage. The volcanic lightning leaves lava under
## every enemy it strikes.
func _test_lightning() -> void:
	var lightning: LightningData = _spell("lightning") as LightningData
	var origin: Vector2 = Vector2(500.0, 100.0)
	var player: Player = await _add_player(origin)
	var targets: Array[Hurtbox] = []
	for x: float in [40.0, 80.0, 120.0, 165.0]:
		targets.append(_add_target(origin + Vector2(x, 0.0)))
	var wet: Enemy = await _add_enemy(origin + Vector2(80.0, 40.0))
	wet.make_wet(5.0)
	await physics_frames(2)
	player.spell_book.learn(lightning)
	player.spell_book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(2)
	var damage: int = SpellData.int_at(lightning.damage, 1)
	var hit: Array[int] = []
	for target: Hurtbox in targets:
		hit.append(TARGET_HP - target.health.hp)
	check(hit[0] == damage, "the nearest enemy is struck first (%d)" % hit[0])
	var struck: int = (1 if hit[1] > 0 else 0) + (1 if hit[2] > 0 else 0) + (1 if wet.health.hp < HP else 0)
	check(struck == 2 and hit[3] == 0, "it jumps on to two more, three in all at level 1: %s, wet %d" % [hit, HP - wet.health.hp])
	check(wet.health.hp == HP or wet.health.hp == HP - roundi(damage * lightning.wet_multiplier),
			"a wet enemy struck takes 1.5 times the damage")
	var struck_nodes: Array = [wet]
	struck_nodes.append_array(targets)
	await _clean_up(struck_nodes)

	var volcanic: LightningData = _spell("volcanic_lightning") as LightningData
	var one: Hurtbox = _add_target(origin + Vector2(40.0, 0.0))
	player.spell_book.replace(0, volcanic)
	await physics_frames(2)
	player.spell_book.get_spell(0).try_cast(Vector2.RIGHT)
	await physics_frames(2)
	check(_count(SpellZone) == 1 and one.health.hp < TARGET_HP - SpellData.int_at(volcanic.damage, 1),
			"the volcanic lightning leaves lava under the enemy it strikes")
	await _clean_up([player, one])


func _test_storm_cloud() -> void:
	var cloud: StormCloudData = _spell("storm_cloud") as StormCloudData
	var origin: Vector2 = Vector2(500.0, 500.0)
	var player: Player = await _add_player(origin)
	var target: Hurtbox = _add_target(origin + Vector2(40.0, 0.0))
	var far: Hurtbox = _add_target(origin + Vector2(cloud.radius + 30.0, 0.0))
	await physics_frames(2)
	player.spell_book.learn(cloud)
	var spell: StormCloudSpell = player.spell_book.get_spell(0) as StormCloudSpell
	spell.try_cast(Vector2.RIGHT)
	await physics_frames(roundi((SpellData.float_at(cloud.duration, 1) + 0.5) * Engine.physics_ticks_per_second))
	check(not spell.is_active() and target.health.hp == TARGET_HP - roundi(cloud.power_at(1)),
			"the cloud strikes the enemy in reach %d times (%d damage)" % [cloud.strikes_at(1), TARGET_HP - target.health.hp])
	check(far.health.hp == TARGET_HP, "an enemy out of its reach is safe")
	await _clean_up([player, target, far])


func _spell(spell_name: String) -> SpellData:
	return load(SPELLS % spell_name) as SpellData


func _count(type: Variant) -> int:
	var found: int = 0
	for node: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		if is_instance_of(node, type) and not node.is_queued_for_deletion():
			found += 1
	return found


func _add_player(at: Vector2) -> Player:
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	add_child(player)
	player.global_position = at
	await physics_frames(1)
	return player


func _add_enemy(at: Vector2) -> Enemy:
	var data: EnemyData = TestFactory.melee_enemy_data(&"element_test")
	data.max_hp = HP
	var enemy: Enemy = TestFactory.enemy(data)
	add_child(enemy)
	enemy.global_position = at
	await physics_frames(1)
	return enemy


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


func _add_wall(at: Vector2, size: Vector2) -> StaticBody2D:
	var wall: StaticBody2D = StaticBody2D.new()
	wall.collision_layer = WORLD_LAYER
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rectangle: RectangleShape2D = RectangleShape2D.new()
	rectangle.size = size
	shape.shape = rectangle
	wall.add_child(shape)
	add_child(wall)
	wall.global_position = at
	return wall


func _clean_up(nodes: Array) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	for node: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		node.queue_free()
	await physics_frames(2)
