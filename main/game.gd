class_name Game
extends Node2D
## One run: asks the director for a plan, has the generator build the section, fills
## the Level with enemies and pickups, and moves on when the player goes through the
## gate. The gate opens only when every enemy of the section is dead.
## The director and the generator never touch the scene tree; this script does.

## Emitted when a section is built and the player stands at its entrance.
signal section_started(plan: SectionPlan, layout: SectionLayout)
## Emitted when the player leaves a section through the gate (not on death).
signal section_finished(plan: SectionPlan, layout: SectionLayout)

const ENEMY_SCENE: PackedScene = preload("res://actors/enemies/enemy.tscn")
const GATE_SCENE: PackedScene = preload("res://level/gate.tscn")
const ITEM_SCENES: Dictionary = {
	SectionLayout.ITEM_HEALTH_PACK: preload("res://actors/pickups/health_pack.tscn"),
	SectionLayout.ITEM_COIN: preload("res://actors/pickups/coin.tscn"),
	SectionLayout.ITEM_CHEST: preload("res://actors/pickups/chest.tscn"),
}
## How many past sections the director looks at for "who hurts the player".
const RECENT_SECTIONS: int = 3
## Launch argument that lets the bot play instead of a person.
const BOT_ARG: String = "--bot"

@export var level: Level
@export var player: Player
@export var hud: Hud
## Reload the scene with a new run a moment after the player dies.
## Tests switch it off; the death screen will replace it.
@export var restart_on_death: bool = true

var plan: SectionPlan = null
var layout: SectionLayout = null
var gate: Gate = null

var _director: Director = Director.new()
var _builder: SectionBuilder = SectionBuilder.new()
## Enemies, pickups and the gate of the current section; freed with the section.
var _contents: Node2D = null
var _enemies_left: int = 0
var _is_changing_section: bool = false


func _ready() -> void:
	player.add_weapon(GameManager.starting_weapon)
	player.set_skill(GameManager.starting_skill)
	hud.bind_player(player)
	GameManager.player_died.connect(_on_player_died)
	if BOT_ARG in OS.get_cmdline_user_args():
		add_bot()
	_start_section()


## Lets the bot play this run (headless simulations and tests).
func add_bot() -> BotPlayer:
	var bot: BotPlayer = BotPlayer.new()
	bot.game = self
	add_child(bot)
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
	if _enemies_left == 0:
		gate.open()


func _make_player_state() -> PlayerState:
	var state: PlayerState = PlayerState.new()
	state.section_index = GameManager.section_index
	state.depth = GameManager.depth
	state.hp_fraction = float(player.health.hp) / float(player.health.max_hp)
	state.weapon_count = player.get_weapon_slots().size()
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
		_contents.add_child(pickup)


func _spawn_enemies() -> void:
	_enemies_left = 0
	for entry: Dictionary in layout.enemies:
		var enemy: Enemy = ENEMY_SCENE.instantiate() as Enemy
		enemy.data = _director.catalog.get_by_id(entry["id"])
		enemy.position = level.to_local(level.cell_center(entry["cell"]))
		enemy.defeated.connect(_on_enemy_defeated)
		_contents.add_child(enemy)
		_enemies_left += 1


func _on_enemy_defeated(_enemy: Enemy) -> void:
	GameManager.add_kill()
	Telemetry.record_kill()
	_enemies_left -= 1
	if _enemies_left <= 0:
		gate.open()


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
	if not restart_on_death:
		return
	await get_tree().create_timer(GameManager.DEATH_RESTART_DELAY).timeout
	GameManager.restart_run()
