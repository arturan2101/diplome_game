extends Node2D
## Manual preview of spells (open spell_preview.tscn and press F6). The player knows
## Fireball (level 2) and Ice Wall; training dummies stand to the right; a shrine and a
## Whirlwind scroll are next to the player. U and I cast the spells, E uses the shrine
## or takes the scroll (with both slots full the game asks which spell to forget).
## With the launch argument --demo the scene casts by itself and opens the shrine
## screen (used for screenshots).

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")
const DUMMY_SCENE: PackedScene = preload("res://actors/enemies/training_dummy.tscn")
const SHRINE_SCENE: PackedScene = preload("res://actors/pickups/shrine.tscn")
const SCROLL_SCENE: PackedScene = preload("res://actors/pickups/spell_pickup.tscn")
const CHOICE_SCENE: PackedScene = preload("res://ui/spell_choice.tscn")
const POOL: SpellPool = preload("res://combat/spells/spell_pool.tres")
const FIREBALL: SpellData = preload("res://combat/spells/fireball.tres")
const ICE_WALL: SpellData = preload("res://combat/spells/ice_wall.tres")
const WHIRLWIND: SpellData = preload("res://combat/spells/whirlwind.tres")
const DEMO_ARG: String = "--demo"
const FLOOR_MAP: String = """#####################
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#...................#
#####################"""

@export var camera_zoom: float = 2.0
## Seconds between the steps of the demo.
@export var demo_step: float = 0.6

var _player: Player = null
var _shrine: Shrine = null
var _choice: SpellChoice = null
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	var level: Level = Level.new()
	level.debug_map = FLOOR_MAP
	add_child(level)
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	_player.global_position = level.cell_center(Vector2i(4, 5))
	_player.spell_book.learn(FIREBALL)
	_player.spell_book.learn(FIREBALL)
	_player.spell_book.learn(ICE_WALL)
	for cell: Vector2i in [Vector2i(13, 5), Vector2i(14, 4), Vector2i(14, 6), Vector2i(16, 5)]:
		var dummy: Node2D = DUMMY_SCENE.instantiate() as Node2D
		add_child(dummy)
		dummy.global_position = level.cell_center(cell)
	_shrine = SHRINE_SCENE.instantiate() as Shrine
	add_child(_shrine)
	_shrine.global_position = level.cell_center(Vector2i(3, 8))
	var scroll: SpellPickup = SCROLL_SCENE.instantiate() as SpellPickup
	scroll.spell_data = WHIRLWIND
	add_child(scroll)
	scroll.global_position = level.cell_center(Vector2i(5, 8))

	var hud: Hud = HUD_SCENE.instantiate() as Hud
	add_child(hud)
	hud.bind_player(_player)
	_choice = CHOICE_SCENE.instantiate() as SpellChoice
	add_child(_choice)
	_shrine.activated.connect(func(_used: Shrine) -> void:
		_choice.open_offers(POOL.offer(3, _rng), _player.spell_book))
	scroll.slots_full.connect(func(pickup: SpellPickup) -> void:
		_choice.open_replace(pickup.spell_data, _player.spell_book))

	var camera: Camera2D = Camera2D.new()
	camera.zoom = Vector2.ONE * camera_zoom
	add_child(camera)
	camera.global_position = level.cell_center(Vector2i(10, 5))
	camera.make_current()
	if DEMO_ARG in OS.get_cmdline_user_args():
		_run_demo()


func _run_demo() -> void:
	await get_tree().create_timer(demo_step * 0.5).timeout
	_player.spell_book.get_spell(0).try_cast(Vector2.RIGHT)
	await get_tree().create_timer(demo_step).timeout
	_player.spell_book.get_spell(1).try_cast(Vector2.RIGHT)
	await get_tree().create_timer(demo_step).timeout
	_player.spell_book.replace(1, WHIRLWIND)
	_player.spell_book.get_spell(1).try_cast(Vector2.RIGHT)
	await get_tree().create_timer(demo_step).timeout
	_shrine.interact(_player)
