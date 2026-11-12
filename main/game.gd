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
const GATE_SCENE: PackedScene = preload("res://level/gate.tscn")
const ITEM_SCENES: Dictionary = {
	SectionLayout.ITEM_HEALTH_PACK: preload("res://actors/pickups/health_pack.tscn"),
	SectionLayout.ITEM_COIN: preload("res://actors/pickups/coin.tscn"),
	SectionLayout.ITEM_CHEST: preload("res://actors/pickups/chest.tscn"),
}
## How many past sections the director looks at for "who hurts the player".
const RECENT_SECTIONS: int = 3
## The arena seals when the player is this many tiles inside its last room.
const ARENA_TRIGGER_DEPTH: int = 2
## Where an enemy was spawned (an arena puts strays back there when it seals).
const SPAWN_CELL_META: StringName = &"spawn_cell"
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
## How many coins fall out of a chest.
@export var chest_coins_min: int = 3
@export var chest_coins_max: int = 6

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


func _ready() -> void:
	if chest_weapons == null:
		chest_weapons = DEFAULT_CHEST_WEAPONS
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
	if is_arena() and not _is_arena_sealed and not _is_arena_cleared and _is_player_inside_arena():
		_seal_arena()


## True if the current section ends with a locked arena.
func is_arena() -> bool:
	return layout != null and layout.arena_room >= 0


func is_arena_sealed() -> bool:
	return _is_arena_sealed


## Lets a bot play this run (headless simulations and tests). Without a profile it
## is the mid bot. The profile name goes to the log.
func add_bot(profile: BotProfile = null) -> BotPlayer:
	var bot: BotPlayer = BotPlayer.new()
	bot.game = self
	bot.profile = profile
	add_child(bot)
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
	# Arrows still in flight belong to the old section.
	for projectile: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		projectile.queue_free()


func _spawn_gate() -> void:
	gate = GATE_SCENE.instantiate() as Gate
	gate.position = level.to_local(level.cell_center(layout.exit))
	gate.entered.connect(_on_gate_entered)
	_contents.add_child(gate)


func _spawn_items() -> void:
	for entry: Dictionary in layout.items:
		var pickup: Pickup = (ITEM_SCENES[entry["id"]] as PackedScene).instantiate() as Pickup
		pickup.position = level.to_local(level.cell_center(entry["cell"]))
		var chest: Chest = pickup as Chest
		if chest != null:
			# Loot is decided now, in spawn order, so the same seed gives the same chests.
			chest.loot_weapon = chest_weapons.pick(_loot_rng)
			chest.loot_coins = _loot_rng.randi_range(chest_coins_min, chest_coins_max)
			chest.opened.connect(_on_chest_opened)
		_contents.add_child(pickup)


## Spawns the first wave; later waves (arena only) wait in _pending_waves.
func _spawn_enemies() -> void:
	_enemies_left = 0
	_pending_waves.clear()
	for _wave in range(1, layout.wave_count()):
		_pending_waves.append([])
	for entry: Dictionary in layout.enemies:
		if int(entry["wave"]) == 0:
			_spawn_enemy(entry)
		else:
			_pending_waves[int(entry["wave"]) - 1].append(entry)


func _spawn_enemy(entry: Dictionary) -> void:
	var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
	enemy.data = _director.catalog.get_by_id(entry["id"])
	# Deeper ruins, tougher enemies.
	enemy.hp_multiplier = _director.catalog.hp_multiplier(GameManager.depth)
	enemy.damage_multiplier = _director.catalog.damage_multiplier(GameManager.depth)
	enemy.position = level.to_local(level.cell_center(entry["cell"]))
	enemy.set_meta(SPAWN_CELL_META, entry["cell"])
	enemy.defeated.connect(_on_enemy_defeated)
	_contents.add_child(enemy)
	_enemies_left += 1


func _on_enemy_defeated(_enemy: Enemy) -> void:
	GameManager.add_kill()
	Telemetry.record_kill()
	_enemies_left -= 1
	if _is_arena_sealed and _enemies_left <= 0:
		_advance_arena()


## The weapon falls next to the opened chest (taken with the interact button),
## and the coins around it.
func _on_chest_opened(chest: Chest) -> void:
	var cells: Array[Vector2i] = level.free_floor_cells_near(chest.global_position, chest.loot_coins + 1)
	if cells.is_empty():
		return
	if chest.loot_weapon != null:
		var weapon_pickup: WeaponPickup = WEAPON_PICKUP_SCENE.instantiate() as WeaponPickup
		weapon_pickup.weapon_data = chest.loot_weapon
		weapon_pickup.position = level.to_local(level.cell_center(cells[0]))
		_contents.add_child.call_deferred(weapon_pickup)
	for i in range(1, cells.size()):
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
	hud.show_banner("The doors are sealed")
	if _enemies_left <= 0:
		_advance_arena()


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
	death_screen.show_summary(GameManager.get_run_summary())
