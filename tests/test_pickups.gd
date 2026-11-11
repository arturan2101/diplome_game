extends TestCase
## Headless test for pickups (health pack, coin, chest) and the gate, using the real scenes.

const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const HEALTH_PACK_SCENE: String = "res://actors/pickups/health_pack.tscn"
const COIN_SCENE: String = "res://actors/pickups/coin.tscn"
const CHEST_SCENE: String = "res://actors/pickups/chest.tscn"
const GATE_SCENE: String = "res://level/gate.tscn"
const SWORD: String = "res://combat/weapons/sword.tres"
const START: Vector2 = Vector2(100.0, 100.0)
const FAR_AWAY: Vector2 = Vector2(400.0, 400.0)

var _gate_entries: int = 0


func run() -> void:
	GameManager.start_run(1)
	var player: Player = (load(PLAYER_SCENE) as PackedScene).instantiate() as Player
	player.position = FAR_AWAY
	add_child(player)
	player.add_weapon(load(SWORD) as WeaponData)
	await physics_frames(2)

	# Health pack: ignored at full health, taken when hurt.
	var pack: HealthPack = _spawn(HEALTH_PACK_SCENE) as HealthPack
	await _step_on(player)
	check(is_instance_valid(pack) and not pack.is_queued_for_deletion() and player.health.hp == 100,
			"a health pack stays on the ground at full health")
	await _step_off(player)
	player.health.take_damage(DamageInfo.new(50, null, &"test"))
	await _step_on(player)
	check(player.health.hp == 80 and not is_instance_valid(pack), "a hurt player takes the pack and heals by 30")
	await _step_off(player)

	# Coin.
	var coin: Coin = _spawn(COIN_SCENE) as Coin
	await _step_on(player)
	check(GameManager.coins == 1 and not is_instance_valid(coin), "a coin adds 1 to the run's coins and disappears")
	await _step_off(player)

	# Chest: second weapon first, coins when both slots are full.
	var chest: Chest = _spawn(CHEST_SCENE) as Chest
	await _step_on(player)
	check(chest.is_open and chest.given == &"bow" and player.has_weapon(&"bow") and player.get_weapon_slots().size() == 2,
			"a chest gives the weapon the player does not have")
	check(player.weapon.data.id == &"sword", "the new weapon goes to the free slot, the active one stays")
	check(is_instance_valid(chest), "an opened chest stays in place")
	await _step_off(player)
	chest.queue_free()
	var second_chest: Chest = _spawn(CHEST_SCENE) as Chest
	await _step_on(player)
	check(second_chest.given == &"coins" and GameManager.coins == 11, "with both slots full a chest gives coins instead")
	await _step_off(player)
	second_chest.queue_free()

	# Gate: closed until opened; then reports the player.
	var gate: Gate = _spawn(GATE_SCENE) as Gate
	gate.entered.connect(func(_who: Player) -> void: _gate_entries += 1)
	await _step_on(player)
	check(_gate_entries == 0 and not gate.is_open, "a closed gate lets nobody through")
	gate.open()
	await physics_frames(2)
	check(gate.is_open and _gate_entries == 1, "opening the gate under the player takes them through")
	await _step_off(player)
	await _step_on(player)
	check(_gate_entries == 2, "walking into an open gate takes the player through")
	player.queue_free()
	gate.queue_free()
	await physics_frames(2)


func _spawn(scene_path: String) -> Node2D:
	var node: Node2D = (load(scene_path) as PackedScene).instantiate() as Node2D
	node.position = START
	add_child(node)
	return node


func _step_on(player: Player) -> void:
	player.position = START
	await physics_frames(4)


func _step_off(player: Player) -> void:
	player.position = FAR_AWAY
	await physics_frames(4)
