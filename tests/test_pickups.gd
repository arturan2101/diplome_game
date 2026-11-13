extends TestCase
## Headless test for pickups (health pack, coin, chest, weapon on the floor) and the gate,
## using the real scenes.

const PLAYER_SCENE: String = "res://actors/player/player.tscn"
const HEALTH_PACK_SCENE: String = "res://actors/pickups/health_pack.tscn"
const COIN_SCENE: String = "res://actors/pickups/coin.tscn"
const CHEST_SCENE: String = "res://actors/pickups/chest.tscn"
const WEAPON_PICKUP_SCENE: String = "res://actors/pickups/weapon_pickup.tscn"
const BOW: String = "res://combat/weapons/bow.tres"
const GATE_SCENE: String = "res://level/gate.tscn"
const SWORD: String = "res://combat/weapons/sword.tres"
const START: Vector2 = Vector2(100.0, 100.0)
const FAR_AWAY: Vector2 = Vector2(400.0, 400.0)

var _gate_entries: int = 0
var _chest_openings: int = 0
var _interaction_events: Array[Interactable] = []


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
	var heal: int = pack.heal_amount
	await _step_on(player)
	check(player.health.hp == 50 + heal and not is_instance_valid(pack),
			"a hurt player takes the pack and heals by its heal amount (%d)" % heal)
	await _step_off(player)

	# Coin.
	var coin: Coin = _spawn(COIN_SCENE) as Coin
	await _step_on(player)
	check(GameManager.coins == 1 and not is_instance_valid(coin), "a coin adds 1 to the run's coins and disappears")
	await _step_off(player)

	# Chest: opens on touch and stays open; the loot itself is laid out by the game.
	var chest: Chest = _spawn(CHEST_SCENE) as Chest
	chest.opened.connect(func(_chest: Chest) -> void: _chest_openings += 1)
	await _step_on(player)
	check(chest.is_open and _chest_openings == 1 and player.get_weapon_slots().size() == 1,
			"a chest opens on touch but gives no weapon by itself")
	await _step_off(player)
	await _step_on(player)
	check(is_instance_valid(chest) and chest.is_open and _chest_openings == 1, "an opened chest stays open and opens only once")
	await _step_off(player)
	chest.queue_free()

	# A weapon on the floor is taken only with the interact button.
	var bow_data: WeaponData = load(BOW) as WeaponData
	var lying_bow: WeaponPickup = _spawn(WEAPON_PICKUP_SCENE) as WeaponPickup
	lying_bow.weapon_data = bow_data
	player.interaction_changed.connect(func(target: Interactable) -> void: _interaction_events.append(target))
	await _step_on(player)
	check(player.get_weapon_slots().size() == 1 and player.interaction_target == lying_bow
			and _interaction_events == ([lying_bow] as Array[Interactable]),
			"standing on a weapon does not take it; it becomes the interaction target")
	check(lying_bow.get_prompt() == "Take [color=#%s]Common Bow[/color]" % WeaponData.COMMON_RARITY.color.to_html(false),
			"the hint names the weapon with its rarity, in the rarity colour")
	await _press_interact()
	check(player.get_weapon_slots() == ([load(SWORD), bow_data] as Array[WeaponData]) and player.weapon.data.id == &"sword"
			and not is_instance_valid(lying_bow), "interact puts the weapon into the free slot and removes it from the floor")
	await physics_frames(2)
	# A freed object compares equal to null, so the event count is what tells the change apart.
	check(player.interaction_target == null and _interaction_events.size() == 2 and _interaction_events[1] == null,
			"once the weapon is taken there is nothing to interact with, and the HUD is told so (%d events)"
			% _interaction_events.size())
	await _step_off(player)

	# Both slots full: the taken weapon replaces the one in hand, the old one stays on the floor.
	var lying_sword: WeaponPickup = _spawn(WEAPON_PICKUP_SCENE) as WeaponPickup
	lying_sword.weapon_data = load(SWORD) as WeaponData
	player.swap_weapon()
	await _step_on(player)
	await _press_interact()
	check(player.get_weapon_slots()[1].id == &"sword" and player.weapon.data.id == &"sword" and player.get_active_slot() == 1,
			"with both slots full, the weapon in hand is replaced")
	check(is_instance_valid(lying_sword) and lying_sword.weapon_data == bow_data, "the replaced weapon now lies on the floor")
	await _press_interact()
	check(player.weapon.data.id == &"bow" and lying_sword.weapon_data.id == &"sword", "it can be taken back")
	await _step_off(player)
	lying_sword.queue_free()

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


func _press_interact() -> void:
	Input.action_press(&"interact")
	await physics_frames(2)
	Input.action_release(&"interact")
	await physics_frames(2)
