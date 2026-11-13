extends Node2D
## Manual preview of the boss (open boss_preview.tscn and press F6): the Guardian of
## the Ruins in a big room with the player (sword and bow). Fight it with the usual
## controls; K deals it 25% of its HP, to see the second phase and its servants.
## With the launch argument --demo the player stands still and the scene hurts the
## boss by itself (used for screenshots).

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")
const ENEMY_SCENE: PackedScene = preload("res://actors/enemies/enemy.tscn")
const GUARDIAN: GuardianData = preload("res://actors/enemies/guardian.tres")
const SWORD: WeaponData = preload("res://combat/weapons/sword.tres")
const BOW: WeaponData = preload("res://combat/weapons/bow.tres")
const DASH: SkillData = preload("res://combat/skills/dash.tres")
const DEMO_ARG: String = "--demo"
const ROOM_MAP: String = """#########################
#.......................#
#.......................#
#.......................#
#.......................#
#.......................#
#.......................#
#.......................#
#.......................#
#.......................#
#.......................#
#.......................#
#########################"""

@export var camera_zoom: float = 1.6
## Share of the boss's max HP the debug key takes.
@export_range(0.0, 1.0) var debug_damage_share: float = 0.25
@export var demo_step: float = 1.2

var _level: Level = null
var _player: Player = null
var _boss: Guardian = null
var _hud: Hud = null


func _ready() -> void:
	_level = Level.new()
	_level.debug_map = ROOM_MAP
	add_child(_level)
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	_player.global_position = _level.cell_center(Vector2i(6, 6))
	_player.add_weapon(SWORD)
	_player.add_weapon(BOW)
	_player.set_skill(DASH)
	_boss = GUARDIAN.scene.instantiate() as Guardian
	_boss.data = GUARDIAN
	add_child(_boss)
	_boss.global_position = _level.cell_center(Vector2i(14, 6))
	_boss.summon_requested.connect(_on_summon_requested)
	_hud = HUD_SCENE.instantiate() as Hud
	add_child(_hud)
	_hud.bind_player(_player)
	_hud.show_boss(_boss)
	var camera: Camera2D = Camera2D.new()
	camera.zoom = Vector2.ONE * camera_zoom
	add_child(camera)
	camera.global_position = _level.cell_center(Vector2i(12, 6))
	camera.make_current()
	if DEMO_ARG in OS.get_cmdline_user_args():
		_player.health.max_hp = 100000
		_player.health.reset()
		_player.set_controls_enabled(false)
		_run_demo()


func _unhandled_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.physical_keycode == KEY_K and is_instance_valid(_boss):
		_hurt_boss()


func _hurt_boss() -> void:
	_boss.health.take_damage(DamageInfo.new(roundi(_boss.health.max_hp * debug_damage_share), null, &"debug"))


## The servants a real section would get from the game.
func _on_summon_requested(guardian: Guardian, count: int) -> void:
	for cell: Vector2i in _level.free_floor_cells_near(guardian.global_position, count):
		var servant: Enemy = ENEMY_SCENE.instantiate() as Enemy
		servant.data = Director.new().catalog.get_by_id(GUARDIAN.summon_id)
		servant.position = _level.cell_center(cell)
		add_child.call_deferred(servant)


func _run_demo() -> void:
	await get_tree().create_timer(demo_step).timeout
	_hurt_boss()
	await get_tree().create_timer(demo_step).timeout
	_hurt_boss()
	_hurt_boss()
	await get_tree().create_timer(demo_step * 1.5).timeout
	_player.global_position = _boss.global_position + Vector2(-36.0, 0.0)
