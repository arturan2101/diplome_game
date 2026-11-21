extends TestCase
## Headless test for stage 41: enemies show their attack by the wind-up pose of the art
## instead of a tint or a drawn warning. The frames before the strike frame follow the
## windup and hold on the last one, the blow plays on `struck`; a cut-short windup drops
## it. The boss has the Ruins Warden's look: one animation per attack, feet on row 92.

const ENEMY_SCENE: String = "res://actors/enemies/enemy.tscn"
const SKELETON: String = "res://actors/enemies/skeleton.tres"
const GUARDIAN: String = "res://actors/enemies/guardian.tres"
const ENEMY_DATA_DIR: String = "res://actors/enemies/"
const TIMEOUT_FRAMES: int = 180


func run() -> void:
	_test_data()
	await _test_skeleton_windup()
	await _test_cut_short()
	await _test_warden()


## Every enemy type with art has a strike frame inside its attack animation.
func _test_data() -> void:
	var report: Array[String] = []
	var ok: bool = true
	for file: String in ["skeleton", "skeleton_shield", "archer", "archer_triple", "beetle", "golem", "ghost"]:
		var data: EnemyData = load(ENEMY_DATA_DIR + file + ".tres") as EnemyData
		var count: int = data.sprite_frames.get_frame_count(&"attack_down")
		report.append("%s %d/%d" % [file, data.attack_strike_frame, count])
		if data.attack_strike_frame <= 0 or data.attack_strike_frame >= count:
			ok = false
	check(ok, "every enemy's strike frame is inside its attack (%s)" % ", ".join(report))


func _test_skeleton_windup() -> void:
	var target: Node2D = TestFactory.player_target(1000)
	target.position = Vector2(100.0, 100.0)
	add_child(target)
	var enemy: Enemy = _add_enemy(SKELETON, Vector2(100.0, 118.0))
	var look: ActorSpriteAnimator = enemy.visual as ActorSpriteAnimator
	var struck: Array[int] = [0]
	enemy.struck.connect(func() -> void: struck[0] += 1)
	var frames: int = 0
	while enemy.state != Enemy.State.WINDUP and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
	await physics_frames(roundi(enemy.data.windup * 0.6 * Engine.physics_ticks_per_second))
	var strike: int = enemy.data.attack_strike_frame
	check(enemy.state == Enemy.State.WINDUP and look.animation == &"attack_up" and not look.is_playing()
			and look.frame > 0 and look.frame < strike, "halfway through the windup: a held wind-up frame (%d of %d)" % [look.frame, strike])
	check(enemy.visual.modulate == Color.WHITE, "no orange tint any more")
	while struck[0] == 0 and frames < TIMEOUT_FRAMES * 2:
		await physics_frames(1)
		frames += 1
	await physics_frames(2)
	check(struck[0] == 1 and look.animation == &"attack_up" and look.is_playing() and look.frame >= strike,
			"the blow plays from the strike frame when the attack lands")
	await _clean_up([target, enemy])


## A windup cut short (knocked back) never shows the blow.
func _test_cut_short() -> void:
	var target: Node2D = TestFactory.player_target(1000)
	target.position = Vector2(300.0, 100.0)
	add_child(target)
	var enemy: Enemy = _add_enemy(SKELETON, Vector2(300.0, 118.0))
	var look: ActorSpriteAnimator = enemy.visual as ActorSpriteAnimator
	var frames: int = 0
	while enemy.state != Enemy.State.WINDUP and frames < TIMEOUT_FRAMES:
		await physics_frames(1)
		frames += 1
	await physics_frames(3)
	enemy.apply_knockback(Vector2(0.0, 200.0))
	await physics_frames(2)
	check(enemy.state == Enemy.State.STAGGER and look.frame < enemy.data.attack_strike_frame,
			"knocked back in the windup: no blow is shown")
	await _clean_up([target, enemy])


func _test_warden() -> void:
	var data: GuardianData = load(GUARDIAN) as GuardianData
	check(data.display_name == "Ruins Warden" and data.id == &"guardian" and data.feet_row == 92,
			"the boss is the Ruins Warden; its log id stays guardian")
	for anim: String in ["slam_down", "throw_left", "wave_up", "roar_right", "summon_down", "death", "walk_up", "idle_down"]:
		check(data.sprite_frames.has_animation(StringName(anim)), "the Warden has %s" % anim)
	var guardian: Guardian = (data.scene.instantiate()) as Guardian
	guardian.data = data
	guardian.position = Vector2(600.0, 300.0)
	add_child(guardian)
	await physics_frames(2)
	var look: AnimatedSprite2D = guardian.visual as AnimatedSprite2D
	var expected: float = guardian.feet_below_centre * data.body_radius / 6.0 - (92.0 - 48.0)
	check(is_equal_approx(look.offset.y, expected), "its feet (row 92 of 96) stand where its body is (offset %.1f)" % look.offset.y)
	var names: Array[String] = []
	for kind: Guardian.Attack in [Guardian.Attack.SLAM, Guardian.Attack.THROW, Guardian.Attack.SHOCKWAVE]:
		guardian.attack = kind
		names.append(guardian.get_attack_animation())
	check(names == (["slam", "throw", "wave"] as Array[String]), "one animation per attack: %s" % [names])
	await _clean_up([guardian])


func _add_enemy(path: String, at: Vector2) -> Enemy:
	var enemy: Enemy = (load(ENEMY_SCENE) as PackedScene).instantiate() as Enemy
	enemy.data = load(path) as EnemyData
	enemy.position = at
	add_child(enemy)
	return enemy


func _clean_up(nodes: Array) -> void:
	for node: Node in nodes:
		if is_instance_valid(node):
			node.queue_free()
	await physics_frames(2)
