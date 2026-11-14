class_name Game
extends Node2D
## One run: asks the director for a plan, has the generator build the section, fills
## the Level with enemies and pickups, and moves on when the player goes through the
## gate. In an ordinary section the gate is open from the start. The last section of
## a depth is an arena: when the player walks into its last room the doors seal, the
## enemies come in one or two waves, and only then do the doors and the gate open.
## The director and the generator never touch the scene tree; this script does.

## Emitted when a section is built and the player stands at its entrance.
signal section_started(plan: SectionPlan, layout: SectionLayout)
## Emitted when the player leaves a section through the gate (not on death).
signal section_finished(plan: SectionPlan, layout: SectionLayout)

const ENEMY_SCENE: PackedScene = preload("res://actors/enemies/enemy.tscn")
const WEAPON_PICKUP_SCENE: PackedScene = preload("res://actors/pickups/weapon_pickup.tscn")
const COIN_SCENE: PackedScene = preload("res://actors/pickups/coin.tscn")
const DEFAULT_CHEST_WEAPONS: WeaponPool = preload("res://combat/weapons/chest_weapons.tres")
const DEFAULT_RARITY_TABLE: RarityTable = preload("res://combat/weapons/rarity_table.tres")
const DEFAULT_SPELL_POOL: SpellPool = preload("res://combat/spells/spell_pool.tres")
const SPELL_PICKUP_SCENE: PackedScene = preload("res://actors/pickups/spell_pickup.tscn")
const SPELL_CHOICE_SCENE: PackedScene = preload("res://ui/spell_choice.tscn")
const GATE_SCENE: PackedScene = preload("res://level/gate.tscn")
const ITEM_SCENES: Dictionary = {
	SectionLayout.ITEM_HEALTH_PACK: preload("res://actors/pickups/health_pack.tscn"),
	SectionLayout.ITEM_COIN: preload("res://actors/pickups/coin.tscn"),
	SectionLayout.ITEM_CHEST: preload("res://actors/pickups/chest.tscn"),
	SectionLayout.ITEM_SHRINE: preload("res://actors/pickups/shrine.tscn"),
	SectionLayout.ITEM_MERCHANT: preload("res://actors/npc/merchant.tscn"),
}
const DEFAULT_SHOP: ShopData = preload("res://shop/shop.tres")
const SHOP_SCREEN_SCENE: PackedScene = preload("res://ui/shop_screen.tscn")
## How many past sections the director looks at for "who hurts the player".
const RECENT_SECTIONS: int = 3
## The arena seals when the player is this many tiles inside its last room.
const ARENA_TRIGGER_DEPTH: int = 2
## Where an enemy was spawned (an arena puts strays back there when it seals).
const SPAWN_CELL_META: StringName = &"spawn_cell"
## Marks servants called by the boss: not planned, so not counted in the kill ratio,
## and they crumble when the boss falls.
const SUMMONED_META: StringName = &"summoned"
## Debug-only zoom; the export preset leaves tools/debug out, so it is loaded by path.
const DEBUG_ZOOM_SCRIPT: String = "res://tools/debug/debug_camera_zoom.gd"

@export var level: Level
@export var player: Player
@export var hud: Hud
@export var death_screen: DeathScreen
@export var pause_menu: PauseMenu
## Show the death screen when the player dies. Tests and simulations switch it off.
@export var death_screen_enabled: bool = true
## Weapons chests can hold. Empty = combat/weapons/chest_weapons.tres.
@export var chest_weapons: WeaponPool
## Chances of common, rare and legendary chest weapons by depth.
## Empty = combat/weapons/rarity_table.tres.
@export var rarity_table: RarityTable
## How many coins fall out of a chest.
@export var chest_coins_min: int = 3
@export var chest_coins_max: int = 6
## Spells of shrines and chest scrolls. Empty = combat/spells/spell_pool.tres.
@export var spell_pool: SpellPool
## Chance that a chest also holds a spell scroll.
@export_range(0.0, 1.0) var chest_spell_chance: float = 0.25
## How many spells a shrine offers.
@export var shrine_offer_count: int = 3
## Screen for choosing spells. Empty = one is created from ui/spell_choice.tscn.
@export var spell_choice: SpellChoice
## What merchants sell and for how much. Empty = shop/shop.tres.
@export var shop_data: ShopData
## The shop screen. Empty = one is created from ui/shop_screen.tscn.
@export var shop_screen: ShopScreen

var plan: SectionPlan = null
var layout: SectionLayout = null
var gate: Gate = null

var _director: Director = null
var _builder: SectionBuilder = SectionBuilder.new()
## Enemies, pickups and the gate of the current section; freed with the section.
var _contents: Node2D = null
var _enemies_left: int = 0
var _is_changing_section: bool = false
## Arena: enemies of the waves not spawned yet (index 0 = second wave).
var _pending_waves: Array[Array] = []
var _is_arena_sealed: bool = false
var _is_arena_cleared: bool = false
## Generator for what chests hold in the current section.
var _loot_rng: RandomNumberGenerator = null
## Scroll whose spell waits for the player to choose a slot.
var _pending_scroll: SpellPickup = null
## Combat rooms of the current section (doors lock, waves with spawn warnings).
var _combat: CombatRoomTracker = null
## The bot playing this run, if any (simulations skip the boss's spell reward).
var _bot: BotPlayer = null
## Servants the boss called that are still alive, including ones not yet added to the
## section (they are added deferred, so get_enemies() may not show them yet).
var _servants: Array[Enemy] = []


func _ready() -> void:
	if chest_weapons == null:
		chest_weapons = DEFAULT_CHEST_WEAPONS
	if rarity_table == null:
		rarity_table = DEFAULT_RARITY_TABLE
	if spell_pool == null:
		spell_pool = DEFAULT_SPELL_POOL
	if spell_choice == null:
		spell_choice = SPELL_CHOICE_SCENE.instantiate() as SpellChoice
		add_child(spell_choice)
	spell_choice.closed.connect(_on_spell_choice_closed)
	if shop_data == null:
		shop_data = DEFAULT_SHOP
	if shop_screen == null:
		shop_screen = SHOP_SCREEN_SCENE.instantiate() as ShopScreen
		add_child(shop_screen)
	shop_screen.bought.connect(_on_shop_bought)
	_combat = CombatRoomTracker.new()
	_combat.name = "CombatRooms"
	_combat.game = self
	_combat.room_sealed.connect(_on_combat_room_sealed)
	_combat.wave_started.connect(_on_combat_wave_started)
	_combat.room_cleared.connect(_on_combat_room_cleared)
	add_child(_combat)
	_director = GameManager.make_director()
	if OS.is_debug_build() and ResourceLoader.exists(DEBUG_ZOOM_SCRIPT):
		var zoom: Node = (load(DEBUG_ZOOM_SCRIPT) as GDScript).new()
		zoom.name = "DebugCameraZoom"
		add_child(zoom)
	player.add_weapon(GameManager.starting_weapon)
	player.set_skill(GameManager.starting_skill)
	hud.bind_player(player)
	Telemetry.bot_profile = ""
	GameManager.player_died.connect(_on_player_died)
	var bot_profile: BotProfile = BotPlayer.profile_from_command_line()
	if bot_profile != null:
		add_bot(bot_profile)
	_start_section()


func _physics_process(delta: float) -> void:
	if not GameManager.is_run_over:
		GameManager.run_time += delta
		Playtest.add_play_time(delta)
	if is_arena() and not _is_arena_sealed and not _is_arena_cleared and _is_player_inside_arena():
		_seal_arena()


## True if the current section ends with a locked arena.
func is_arena() -> bool:
	return layout != null and layout.arena_room >= 0


func is_arena_sealed() -> bool:
	return _is_arena_sealed


## The combat rooms of the current section.
func get_combat_rooms() -> CombatRoomTracker:
	return _combat


## Enemy data by type id (from the director's catalog).
func get_enemy_data(id: StringName) -> EnemyData:
	return _director.catalog.get_by_id(id)


## Adds a node to the current section; it is freed with the section.
func add_section_node(node: Node) -> void:
	_contents.add_child(node)


## An enemy of this type on this cell, added to the section and counted like the
## planned ones (combat-room waves come in this way).
func spawn_enemy(enemy_data: EnemyData, cell: Vector2i) -> Enemy:
	var enemy: Enemy = _create_enemy(enemy_data, cell)
	_contents.add_child(enemy)
	return enemy


## Lets a bot play this run (headless simulations and tests). Without a profile it
## is the mid bot. The profile name goes to the log.
func add_bot(profile: BotProfile = null) -> BotPlayer:
	var bot: BotPlayer = BotPlayer.new()
	bot.game = self
	bot.profile = profile
	add_child(bot)
	_bot = bot
	Telemetry.bot_profile = String(bot.profile.id)
	return bot


## Enemies of the current section that are still alive.
func get_enemies() -> Array[Enemy]:
	var enemies: Array[Enemy] = []
	if _contents == null:
		return enemies
	for child: Node in _contents.get_children():
		var enemy: Enemy = child as Enemy
		if enemy != null and not enemy.health.is_dead():
			enemies.append(enemy)
	return enemies


## Pickups of the current section that are still on the ground.
func get_pickups() -> Array[Pickup]:
	var pickups: Array[Pickup] = []
	if _contents == null:
		return pickups
	for child: Node in _contents.get_children():
		var pickup: Pickup = child as Pickup
		if pickup != null and not pickup.is_queued_for_deletion():
			pickups.append(pickup)
	return pickups


## Shrines of the current section, used or not.
func get_shrines() -> Array[Shrine]:
	var shrines: Array[Shrine] = []
	if _contents == null:
		return shrines
	for child: Node in _contents.get_children():
		var shrine: Shrine = child as Shrine
		if shrine != null and not shrine.is_queued_for_deletion():
			shrines.append(shrine)
	return shrines


func _start_section() -> void:
	plan = _director.choose_next(_make_player_state())
	layout = _builder.build(plan, GameManager.make_section_rng(GameManager.section_index))
	_loot_rng = GameManager.make_loot_rng(GameManager.section_index)
	_is_arena_sealed = false
	_is_arena_cleared = false
	_clear_section()
	level.build(layout.grid)
	_contents = Node2D.new()
	_contents.name = "Contents"
	level.add_child(_contents)
	_spawn_gate()
	_spawn_items()
	_spawn_secret()
	_combat.setup(layout)
	_spawn_enemies()
	player.teleport(level.cell_center(layout.entrance))
	Telemetry.begin_section(plan, layout, player)
	section_started.emit(plan, layout)
	if not is_arena():
		gate.open()


func _make_player_state() -> PlayerState:
	var state: PlayerState = PlayerState.new()
	state.section_index = GameManager.section_index
	state.depth = GameManager.depth
	state.hp_fraction = float(player.health.hp) / float(player.health.max_hp)
	state.weapon_count = player.get_weapon_slots().size()
	if player.spell_book != null:
		state.spells = player.spell_book.to_dictionary()
	if player.weapon != null:
		state.weapon_rarity = player.weapon.data.get_rarity().id
		state.weapon_multiplier = player.weapon.data.get_damage_multiplier()
	state.is_depth_end = GameManager.is_last_section_of_depth()
	state.rng = GameManager.make_director_rng(GameManager.section_index)
	state.skill = Telemetry.estimator.skill
	for record: Dictionary in Telemetry.history:
		state.results.append(float(record["p"]))
		state.phases.append(StringName(record["phase"]))
	state.recent_damage = Telemetry.recent_damage(RECENT_SECTIONS)
	if not Telemetry.history.is_empty():
		state.weapon_use = Telemetry.history[Telemetry.history.size() - 1]["weapon_use"]
	return state


func _clear_section() -> void:
	if _contents != null:
		_contents.queue_free()
		_contents = null
	# Arrows still in flight, fireballs and ice belong to the old section.
	for projectile: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		projectile.queue_free()
	if player != null and player.spell_book != null:
		player.spell_book.cancel_all()


func _spawn_gate() -> void:
	gate = GATE_SCENE.instantiate() as Gate
	gate.position = level.to_local(level.cell_center(layout.exit))
	gate.entered.connect(_on_gate_entered)
	_contents.add_child(gate)


func _spawn_items() -> void:
	for entry: Dictionary in layout.items:
		# The secret room's things appear when it opens.
		if not entry.get("secret", false):
			_spawn_item(entry)


func _spawn_item(entry: Dictionary) -> void:
	var item: Node2D = (ITEM_SCENES[entry["id"]] as PackedScene).instantiate() as Node2D
	item.position = level.to_local(level.cell_center(entry["cell"]))
	var chest: Chest = item as Chest
	if chest != null:
		# Loot is decided now, in spawn order, so the same seed gives the same chests.
		chest.loot_weapon = _roll_chest_weapon()
		chest.loot_coins = _loot_rng.randi_range(chest_coins_min, chest_coins_max)
		if GameManager.config.spells_enabled and _loot_rng.randf() < chest_spell_chance:
			chest.loot_spell = spell_pool.pick(_loot_rng)
		chest.opened.connect(_on_chest_opened)
	var shrine: Shrine = item as Shrine
	if shrine != null:
		shrine.activated.connect(_on_shrine_activated)
	var merchant: Merchant = item as Merchant
	if merchant != null:
		merchant.wandering = entry.get("secret", false)
		merchant.offers = ShopStock.make_offers(shop_data, GameManager.depth, GameManager.make_shop_rng(GameManager.section_index),
				chest_weapons, rarity_table if GameManager.config.rarity_enabled else null,
				spell_pool if GameManager.config.spells_enabled else null, player.spell_book, merchant.wandering)
		merchant.shop_requested.connect(_on_shop_requested)
	_contents.add_child(item)


## The cracked wall in front of the secret room, if the section has one.
func _spawn_secret() -> void:
	if layout.secret.is_empty():
		return
	var wall: BreakableWall = BreakableWall.new()
	wall.setup(layout.secret["crack"], layout.secret["front"])
	# The level's tiles show the crack when its theme has them.
	wall.draw_crack = not level.draws_cracks()
	wall.position = level.to_local(level.cell_center(layout.secret["crack"]))
	wall.broken.connect(_on_secret_wall_broken)
	_contents.add_child(wall)


func _on_secret_wall_broken(_wall: BreakableWall) -> void:
	Telemetry.record_secret_found()
	hud.show_banner("A hidden room!")
	# Deferred: the hit comes in the middle of the sword's physics query.
	_open_secret.call_deferred()


## The crack and the room become floor (drawn with the room's theme), then its things
## appear, and light falls in through a hole in the ceiling.
func _open_secret() -> void:
	var room: Rect2i = layout.secret["rect"]
	var cells: Array[Vector2i] = [layout.secret["crack"]]
	for y in range(room.position.y, room.end.y):
		for x in range(room.position.x, room.end.x):
			cells.append(Vector2i(x, y))
	level.grid.cracked.erase(layout.secret["crack"])
	# A patch of light from above in the middle of the room.
	var middle: Vector2i = room.position + room.size / 2
	for cell: Vector2i in [middle, middle + Vector2i.LEFT, middle + Vector2i.UP, middle + Vector2i(-1, -1)]:
		if room.has_point(cell):
			level.grid.sunlit[cell] = true
	level.set_cells(cells, LevelGrid.Cell.FLOOR)
	for entry: Dictionary in layout.items:
		if entry.get("secret", false):
			_spawn_item(entry)
	var light: LightShaft = LightShaft.new()
	light.position = level.to_local((level.cell_center(room.position) + level.cell_center(room.end - Vector2i.ONE)) * 0.5)
	_contents.add_child(light)


## Bots do not trade: the shop would pause their run.
func _on_shop_requested(merchant: Merchant) -> void:
	if _bot != null or shop_screen.is_open():
		return
	shop_screen.open(merchant, GameManager.coins)


func _on_shop_bought(offer: ShopOffer) -> void:
	if offer.sold or not GameManager.spend_coins(offer.price):
		return
	offer.sold = true
	match offer.kind:
		ShopOffer.Kind.HEAL:
			player.health.heal(offer.heal_amount)
		ShopOffer.Kind.WEAPON:
			var cells: Array[Vector2i] = level.free_floor_cells_near(shop_screen.merchant.global_position, 1)
			var weapon_pickup: WeaponPickup = WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
			weapon_pickup.weapon_data = offer.weapon
			var cell: Vector2i = cells[0] if not cells.is_empty() else level.cell_at(player.global_position)
			weapon_pickup.position = level.to_local(level.cell_center(cell))
			_contents.add_child(weapon_pickup)
		ShopOffer.Kind.SPELL, ShopOffer.Kind.SPELL_LEVEL:
			player.spell_book.learn(offer.spell)
	Telemetry.record_purchase(offer.get_id(), offer.price)
	shop_screen.refresh(GameManager.coins)


## Spawns the first wave; later waves (arena only) wait in _pending_waves.
func _spawn_enemies() -> void:
	_enemies_left = 0
	_servants.clear()
	_pending_waves.clear()
	for _wave in range(1, layout.wave_count()):
		_pending_waves.append([])
	for entry: Dictionary in layout.enemies:
		# Enemies of a combat room wait until the player walks in.
		if _combat.owns(entry):
			continue
		if int(entry["wave"]) == 0:
			_spawn_enemy(entry)
		else:
			_pending_waves[int(entry["wave"]) - 1].append(entry)


func _spawn_enemy(entry: Dictionary) -> void:
	if not level.grid.is_floor(entry["cell"]):
		# Never inside a wall (e.g. a doorway the arena has sealed).
		entry = entry.duplicate()
		entry["cell"] = level.nearest_floor_cell(entry["cell"])
	var enemy_data: EnemyData = _director.catalog.get_by_id(entry["id"])
	var cell: Vector2i = entry["cell"]
	var sleeps: bool = enemy_data.is_boss and layout.arena_room >= 0
	if sleeps:
		# The boss waits in the middle of its arena, clear of the walls.
		cell = level.nearest_floor_cell(layout.room_rects[layout.arena_room].get_center())
	var enemy: Enemy = _create_enemy(enemy_data, cell)
	if sleeps:
		# Asleep until the doors seal: it cannot be lured out or hurt from the doorway.
		enemy.make_dormant()
	var guardian: Guardian = enemy as Guardian
	if guardian != null:
		guardian.summon_requested.connect(_on_summon_requested)
		guardian.phase_changed.connect(_on_boss_phase_changed)
	_contents.add_child(enemy)


## An enemy of this type on this cell, scaled for the depth, counted as alive.
func _create_enemy(enemy_data: EnemyData, cell: Vector2i) -> Enemy:
	var scene: PackedScene = enemy_data.scene if enemy_data.scene != null else ENEMY_SCENE
	var enemy: Enemy = scene.instantiate() as Enemy
	enemy.data = enemy_data
	# Deeper ruins, tougher enemies.
	enemy.hp_multiplier = _director.catalog.hp_multiplier(GameManager.depth)
	enemy.damage_multiplier = _director.catalog.damage_multiplier(GameManager.depth)
	enemy.position = level.to_local(level.cell_center(cell))
	enemy.set_meta(SPAWN_CELL_META, cell)
	enemy.defeated.connect(_on_enemy_defeated)
	_enemies_left += 1
	return enemy


func _on_enemy_defeated(enemy: Enemy) -> void:
	GameManager.add_kill()
	if enemy.has_meta(SUMMONED_META):
		_servants.erase(enemy)
	else:
		Telemetry.record_kill()
	_enemies_left -= 1
	if enemy is Guardian:
		_on_boss_defeated()
	if _is_arena_sealed and _enemies_left <= 0:
		_advance_arena()


## The boss calls servants next to itself, while fewer than its limit are alive.
func _on_summon_requested(guardian: Guardian, count: int) -> void:
	var stats: GuardianData = guardian.data as GuardianData
	var servant: EnemyData = _director.catalog.get_by_id(stats.summon_id)
	if servant == null:
		return
	var wanted: int = mini(count, stats.summon_max_alive - _servants.size())
	if wanted <= 0:
		return
	for cell: Vector2i in level.free_floor_cells_near(guardian.global_position, wanted):
		var summoned: Enemy = _create_enemy(servant, cell)
		summoned.set_meta(SUMMONED_META, true)
		_servants.append(summoned)
		# Deferred: the request may come from inside a physics callback.
		_contents.add_child.call_deferred(summoned)


func _on_boss_phase_changed(_phase: int) -> void:
	hud.show_banner("The Guardian calls its servants!")


## The servants crumble with the boss; the player may choose a spell as a reward.
func _on_boss_defeated() -> void:
	for servant: Enemy in _servants:
		servant.defeated.disconnect(_on_enemy_defeated)
		_enemies_left -= 1
		if servant.is_inside_tree():
			servant.queue_free()
		else:
			# Called this very frame and not added yet: gone as soon as it is.
			servant.tree_entered.connect(servant.queue_free)
	_servants.clear()
	hud.hide_boss()
	hud.show_banner("The Guardian has fallen")
	if _bot == null and GameManager.config.spells_enabled:
		spell_choice.open_offers.call_deferred(spell_pool.offer(shrine_offer_count, _loot_rng), player.spell_book)


## The player used a shrine: choose one of a few random spells. Bots do not use
## spells, and the screen would pause their run, so a bot gets nothing.
func _on_shrine_activated(_shrine: Shrine) -> void:
	if _bot != null:
		return
	spell_choice.open_offers(spell_pool.offer(shrine_offer_count, _loot_rng), player.spell_book)


## A scroll was taken with both spell slots full: ask which spell to forget.
func _on_scroll_slots_full(scroll: SpellPickup) -> void:
	if _bot != null:
		return
	_pending_scroll = scroll
	spell_choice.open_replace(scroll.spell_data, player.spell_book)


## The scroll is used up once its spell is learned; kept if the player changed their mind.
func _on_spell_choice_closed(learned: SpellData) -> void:
	if learned != null and is_instance_valid(_pending_scroll) and _pending_scroll.spell_data == learned:
		_pending_scroll.queue_free()
	_pending_scroll = null


## A random weapon from the chest pool with a random rarity for the current depth.
func _roll_chest_weapon() -> WeaponData:
	var base: WeaponData = chest_weapons.pick(_loot_rng)
	if base == null or not GameManager.config.rarity_enabled:
		return base
	var rarity: WeaponRarity = rarity_table.pick(GameManager.depth, _loot_rng)
	return base.with_rarity(rarity) if rarity != null else base


## The weapon falls next to the opened chest (taken with the interact button), then
## the spell scroll if there is one, and the coins around them.
func _on_chest_opened(chest: Chest) -> void:
	var scrolls: int = 1 if chest.loot_spell != null else 0
	var cells: Array[Vector2i] = level.free_floor_cells_near(chest.global_position, chest.loot_coins + 1 + scrolls)
	if cells.is_empty():
		return
	if chest.loot_weapon != null:
		var weapon_pickup: WeaponPickup = WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
		weapon_pickup.weapon_data = chest.loot_weapon
		weapon_pickup.position = level.to_local(level.cell_center(cells[0]))
		_contents.add_child.call_deferred(weapon_pickup)
	var first_coin: int = 1
	if chest.loot_spell != null and cells.size() > 1:
		var scroll: SpellPickup = SPELL_PICKUP_SCENE.instantiate() as SpellPickup
		scroll.spell_data = chest.loot_spell
		scroll.position = level.to_local(level.cell_center(cells[1]))
		scroll.slots_full.connect(_on_scroll_slots_full)
		_contents.add_child.call_deferred(scroll)
		first_coin = 2
	for i in range(first_coin, cells.size()):
		var coin: Coin = COIN_SCENE.instantiate() as Coin
		coin.position = level.to_local(level.cell_center(cells[i]))
		# Deferred: adding areas while a physics callback runs is not allowed.
		_contents.add_child.call_deferred(coin)


func _is_player_inside_arena() -> bool:
	var room: Rect2i = layout.room_rects[layout.arena_room].grow(-ARENA_TRIGGER_DEPTH)
	return room.has_point(level.cell_at(player.global_position))


func _seal_arena() -> void:
	_is_arena_sealed = true
	level.set_cells(layout.arena_doors, LevelGrid.Cell.WALL)
	# An arena enemy that chased the player out (or stands in a doorway) would be shut
	# out for good: put it back where it started, inside the room.
	var inside: Rect2i = layout.room_rects[layout.arena_room].grow(-1)
	for enemy: Enemy in get_enemies():
		var cell: Vector2i = level.cell_at(enemy.global_position)
		if not inside.has_point(cell) or not level.grid.is_floor(cell):
			enemy.global_position = level.cell_center(enemy.get_meta(SPAWN_CELL_META, layout.exit))
	var boss: Guardian = _find_boss()
	if boss != null:
		boss.awaken()
		hud.show_boss(boss)
		hud.show_banner("The Guardian of the Ruins awakens")
	else:
		hud.show_banner("The doors are sealed")
	if _enemies_left <= 0:
		_advance_arena()


func _on_combat_room_sealed(_room: CombatRoom) -> void:
	hud.show_banner("The doors are sealed")


func _on_combat_wave_started(_room: CombatRoom, wave: int) -> void:
	if wave > 0:
		hud.show_banner("Another wave!")


func _on_combat_room_cleared(_room: CombatRoom) -> void:
	hud.show_banner("The way is open")


func _find_boss() -> Guardian:
	for enemy: Enemy in get_enemies():
		if enemy is Guardian:
			return enemy as Guardian
	return null


## Next wave, or, when all waves are dead, open the doors and the gate.
func _advance_arena() -> void:
	if not _pending_waves.is_empty():
		var wave: Array = _pending_waves.pop_front()
		hud.show_banner("Another wave!")
		for entry: Dictionary in wave:
			_spawn_enemy.call_deferred(entry)
		return
	_is_arena_sealed = false
	_is_arena_cleared = true
	level.set_cells(layout.arena_doors, LevelGrid.Cell.FLOOR)
	gate.open()
	hud.show_banner("The way down is open")


func _on_gate_entered(_player: Player) -> void:
	if _is_changing_section or GameManager.is_run_over:
		return
	_is_changing_section = true
	player.set_controls_enabled(false)
	await hud.fade_out()
	Telemetry.end_section(false)
	section_finished.emit(plan, layout)
	if Playtest.is_block_over():
		# A playtest block ends at the first gate after its time: survey instead of a new section.
		Playtest.finish_block()
		return
	GameManager.advance_section()
	_start_section()
	await hud.fade_in()
	player.set_controls_enabled(true)
	_is_changing_section = false


func _on_player_died(_killing_blow: DamageInfo) -> void:
	Telemetry.end_section(true)
	if not death_screen_enabled or death_screen == null:
		return
	await get_tree().create_timer(GameManager.DEATH_SCREEN_DELAY).timeout
	if Playtest.is_block_over():
		Playtest.finish_block()
		return
	# In a playtest the block goes on with a new run; the way to the menu is hidden.
	death_screen.menu_enabled = not Playtest.is_active
	death_screen.show_summary(GameManager.get_run_summary())
