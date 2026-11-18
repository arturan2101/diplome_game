extends TestCase
## Headless test for the camp's permanent skills (stage 35): the tree (ten skills,
## icons, levels with prices, branches), buying with shards (price, the required skill
## first, the top level), the effects at the start of a run in the full game (health,
## armour, damage, speed, skill cooldown, start coins, coin magnet, chest luck) and
## none in the clean series.

const GAME_SCENE: String = "res://main/main.tscn"
const COIN_SCENE: String = "res://actors/pickups/coin.tscn"
const TREE: String = "res://progression/perks.tres"
const RUN_SEED: int = 35

var _tree: PerkTree = null
var _write_was: bool = true


func run() -> void:
	_tree = load(TREE) as PerkTree
	_test_tree()
	_test_buying()
	await _test_effects()
	await _test_clean()
	await _test_screen()
	Progress.from_dictionary({})


func _test_tree() -> void:
	var ok: bool = _tree.perks.size() == 10
	var effects: Dictionary = {}
	for perk: PerkData in _tree.perks:
		effects[perk.effect] = true
		if perk.icon == null or perk.costs.size() != perk.values.size() or perk.max_level() < 1:
			ok = false
		if perk.requires != null and perk.requires.tree_position.x != perk.tree_position.x:
			ok = false
	check(ok and effects.size() == 10, "ten skills, one per effect, each with an icon and a price per level, branches by column")


func _test_buying() -> void:
	Progress.from_dictionary({})
	var health: PerkData = _tree.get_by_id(&"health")
	var armor: PerkData = _tree.get_by_id(&"armor")
	check(not _tree.can_buy(health) and not _tree.buy(health), "without shards nothing can be bought")
	Progress.add_shards(100)
	check(not _tree.can_buy(armor), "a skill needs the one before it in its branch")
	check(_tree.buy(health) and _tree.level_of(health) == 1 and Progress.shards == 100 - health.costs[0], "buying takes its price in shards")
	check(_tree.can_buy(armor), "then the next skill of the branch opens")
	while _tree.buy(health):
		pass
	check(_tree.level_of(health) == health.max_level() and not _tree.can_buy(health), "a skill stops at its top level")
	Progress.unlock_all = true
	check(_tree.level_of(_tree.get_by_id(&"chest_luck")) == 2, "everything unlocked (testing): every skill at its top")
	Progress.unlock_all = false


func _test_effects() -> void:
	var levels: Dictionary = {}
	for perk: PerkData in _tree.perks:
		levels[String(perk.id)] = perk.max_level()
	Progress.from_dictionary({"perks": levels})
	var game: Game = await _start("full")
	var player: Player = game.player
	check(player.health.max_hp == 100 + roundi(_tree.total(PerkData.Effect.MAX_HP)) and player.health.hp == player.health.max_hp,
			"more health (%d)" % player.health.max_hp)
	check(is_equal_approx(player.health.damage_taken_multiplier, 1.0 - _tree.total(PerkData.Effect.ARMOR)), "armour: less damage taken")
	var hit: DamageInfo = DamageInfo.new(50, null, &"test")
	player.health.take_damage(hit)
	check(hit.amount == roundi(50 * player.health.damage_taken_multiplier), "a 50 hit takes %d" % hit.amount)
	check(is_equal_approx(player.weapon.damage_multiplier, 1.0 + _tree.total(PerkData.Effect.DAMAGE)), "weapons hit harder")
	check(player.move_speed > 90.0 and player.skill.cooldown_multiplier < 1.0, "faster, the skill comes back sooner")
	# The magnet may already have pulled in a coin of the section.
	check(GameManager.coins >= roundi(_tree.total(PerkData.Effect.START_COINS)) and game._chest_luck() == 2,
			"start coins (%d) and chest luck" % GameManager.coins)
	var coin: Node2D = (load(COIN_SCENE) as PackedScene).instantiate() as Node2D
	game.add_section_node(coin)
	coin.global_position = player.global_position + Vector2(player.coin_magnet_radius - 8.0, 0.0)
	var start: float = coin.global_position.distance_to(player.global_position)
	await physics_frames(4)
	check(not is_instance_valid(coin) or coin.global_position.distance_to(player.global_position) < start,
			"coins fly to the player inside the magnet's radius")
	await _stop(game)


func _test_clean() -> void:
	var game: Game = await _start("clean")
	check(game.player.health.max_hp == 100 and is_equal_approx(game.player.health.damage_taken_multiplier, 1.0)
			and GameManager.coins == 0 and game._chest_luck() == 0, "the clean series ignores the permanent skills")
	await _stop(game)


func _start(series: String) -> Game:
	_write_was = Telemetry.write_enabled
	Telemetry.write_enabled = false
	GameManager.config = GameManager.load_config(series)
	GameManager.start_run(RUN_SEED)
	var game: Game = (load(GAME_SCENE) as PackedScene).instantiate() as Game
	game.death_screen_enabled = false
	add_child(game)
	await physics_frames(2)
	return game


func _stop(game: Game) -> void:
	game.queue_free()
	Telemetry.write_enabled = _write_was
	GameManager.config = GameManager.DEFAULT_CONFIG
	await physics_frames(3)


## The altar's screen: nodes show their state, choosing one and Buy spends the shards.
func _test_screen() -> void:
	Progress.from_dictionary({"shards": 10})
	var screen: SkillTreeScreen = SkillTreeScreen.new()
	add_child(screen)
	screen.open(_tree)
	var health: PerkData = _tree.get_by_id(&"health")
	var armor: PerkData = _tree.get_by_id(&"armor")
	check(screen.is_open() and get_tree().paused and screen.get_node_button(&"health") != null
			and screen.state_of(health) == SkillTreeScreen.NodeState.AVAILABLE
			and screen.state_of(armor) == SkillTreeScreen.NodeState.LOCKED, "the altar's screen shows the tree: roots open, the rest locked")
	screen.get_node_button(&"health").pressed.emit()
	screen.get_buy_button().pressed.emit()
	check(_tree.level_of(health) == 1 and Progress.shards == 10 - health.costs[0]
			and screen.state_of(armor) == SkillTreeScreen.NodeState.AVAILABLE, "choosing a skill and Buy spends the shards; the next one opens")
	screen.close()
	check(not get_tree().paused, "closing the screen goes on with the game")
	screen.queue_free()
	await physics_frames(2)

