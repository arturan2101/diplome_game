extends TestCase
## Headless test for the bot profiles and the depth scaling of enemies:
## weak < mid < strong in every skill number, enemy HP and damage grow with depth,
## and in a duel the strong bot takes less damage than the weak one.

const GAME_SCENE: String = "res://main/main.tscn"
const DUEL_SECONDS: int = 12
const DUEL_SEED: int = 42
const ENEMY_SCENE: String = "res://actors/enemies/enemy.tscn"
const SKELETON: String = "res://actors/enemies/skeleton.tres"


func run() -> void:
	_test_profiles()
	await _test_depth_scaling()
	await _test_duel()


func _test_profiles() -> void:
	var weak: BotProfile = BotPlayer.load_profile("weak")
	var mid: BotProfile = BotPlayer.load_profile("mid")
	var strong: BotProfile = BotPlayer.load_profile("strong")
	check(weak.id == &"weak" and mid.id == &"mid" and strong.id == &"strong", "the three profiles load by name")
	check(weak.reaction_time > mid.reaction_time and mid.reaction_time > strong.reaction_time, "reaction: weak slowest, strong fastest")
	check(weak.dodge_chance < mid.dodge_chance and mid.dodge_chance < strong.dodge_chance, "dodging: strong dodges most")
	check(weak.miss_chance > mid.miss_chance and mid.miss_chance > strong.miss_chance, "misses: weak misses most")
	check(weak.hazard_blind_chance > mid.hazard_blind_chance and mid.hazard_blind_chance >= strong.hazard_blind_chance,
			"traps: weak overlooks them most often")
	check(BotPlayer.load_profile("no_such_bot") == mid, "an unknown name falls back to the mid bot")


func _test_depth_scaling() -> void:
	var catalog: EnemyCatalog = load(Director.CATALOG_PATH) as EnemyCatalog
	check(is_equal_approx(catalog.hp_multiplier(0), 1.0) and catalog.hp_multiplier(3) > catalog.hp_multiplier(1)
			and catalog.damage_multiplier(2) > 1.0, "enemy HP and damage multipliers grow with depth")
	var enemy: Enemy = TestFactory.enemy(TestFactory.melee_enemy_data(&"skeleton", 10))
	enemy.hp_multiplier = 1.5
	enemy.damage_multiplier = 2.0
	enemy.position = Vector2(100.0, 100.0)
	var target: Node2D = TestFactory.player_target(1000)
	target.position = Vector2(112.0, 100.0)
	add_child(target)
	add_child(enemy)
	await physics_frames(2)
	check(enemy.health.max_hp == 45 and enemy.health.hp == 45, "an enemy with an HP multiplier of 1.5 has 45 HP instead of 30")
	var target_health: Health = target.get_node("Health")
	for _i in 120:
		if target_health.hp < 1000:
			break
		await get_tree().physics_frame
	check(target_health.hp == 980, "its hits deal twice the damage (20 instead of 10)")
	enemy.queue_free()
	target.queue_free()
	await physics_frames(2)


## One skeleton with endless HP against each bot for a few seconds.
func _test_duel() -> void:
	var weak_damage: int = await _duel("weak")
	var strong_damage: int = await _duel("strong")
	check(strong_damage < weak_damage, "in a duel with a skeleton the strong bot takes less damage (%d) than the weak one (%d)"
			% [strong_damage, weak_damage])


func _duel(profile_name: String) -> int:
	GameManager.start_run(DUEL_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	game.player.health.max_hp = 100000
	game.player.health.reset()
	# Replace whatever the section spawned with one skeleton next to the player.
	var enemies: Array[Enemy] = game.get_enemies()
	var contents: Node = enemies[0].get_parent()
	for enemy: Enemy in enemies:
		enemy.queue_free()
	var keep: Enemy = (load(ENEMY_SCENE) as PackedScene).instantiate() as Enemy
	keep.data = load(SKELETON) as EnemyData
	contents.add_child(keep)
	await physics_frames(2)
	keep.health.max_hp = 100000
	keep.health.reset()
	keep.global_position = game.player.global_position + Vector2(40.0, 0.0)
	game.add_bot(BotPlayer.load_profile(profile_name))
	await physics_frames(60 * DUEL_SECONDS)
	var damage: int = 100000 - game.player.health.hp
	game.queue_free()
	await physics_frames(3)
	return damage
