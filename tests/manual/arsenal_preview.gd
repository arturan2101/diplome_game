extends Node2D
## Manual preview of batch 8 (stage 39; open arsenal_preview.tscn and press F6, or run
## `godot --path . res://tests/manual/arsenal_preview.tscn -- parry`): the spear, the
## daggers and the crossbow of every rarity on the floor (stand next to one to see its
## card, E to take it), training dummies to see critical hits (golden numbers), a
## skeleton to parry, and a pit to teleport over. The skill is the first user argument
## (parry, teleport, dash or block; parry by default); a second argument "near" starts
## next to the legendary crossbow with its card open. Critical hits are on, and K
## raises the weapon in hand a level, as a whetstone would.

const PICKUP_SCENE: PackedScene = preload("res://actors/pickups/weapon_pickup.tscn")
const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")
const ENEMY_SCENE: PackedScene = preload("res://actors/enemies/enemy.tscn")
const DUMMY_SCENE: PackedScene = preload("res://actors/enemies/training_dummy.tscn")
const SKELETON: EnemyData = preload("res://actors/enemies/skeleton.tres")
const RARITY_TABLE: RarityTable = preload("res://combat/weapons/rarity_table.tres")
const SWORD: WeaponData = preload("res://combat/weapons/sword.tres")
const WEAPONS: Array[WeaponData] = [
	preload("res://combat/weapons/spear.tres"),
	preload("res://combat/weapons/daggers.tres"),
	preload("res://combat/weapons/crossbow.tres"),
]
const SKILLS_DIR: String = "res://combat/skills/%s.tres"
## '#' wall, '.' floor, '~' pit: weapons on the left, dummies and the skeleton on the right.
const FLOOR_MAP: String = """##########################
#........................#
#........................#
#.............~~.........#
#.............~~.........#
#.............~~.........#
#.............~~.........#
#........................#
#........................#
##########################"""

@export var spacing: float = 28.0
@export var camera_zoom: float = 2.0

var _player: Player = null


func _ready() -> void:
	var level: Level = Level.new()
	level.debug_map = FLOOR_MAP
	add_child(level)
	var tile: float = float(level.theme.tile_size)
	for row in WEAPONS.size():
		for column in RARITY_TABLE.rarities.size():
			var pickup: WeaponPickup = PICKUP_SCENE.instantiate() as WeaponPickup
			pickup.weapon_data = WEAPONS[row].with_rarity(RARITY_TABLE.rarities[column])
			pickup.position = Vector2(2.5 * tile + column * spacing, 2.5 * tile + row * spacing)
			add_child(pickup)
	for i in 2:
		var dummy: Node2D = DUMMY_SCENE.instantiate() as Node2D
		dummy.position = Vector2(19.5 * tile + i * 2.0 * tile, 2.5 * tile)
		add_child(dummy)
	var skeleton: Enemy = ENEMY_SCENE.instantiate() as Enemy
	skeleton.data = SKELETON
	skeleton.position = Vector2(21.5 * tile, 7.5 * tile)
	add_child(skeleton)

	_player = PLAYER_SCENE.instantiate() as Player
	_player.critical_hits = true
	_player.position = Vector2(4.5 * tile, 6.5 * tile)
	var args: PackedStringArray = OS.get_cmdline_user_args()
	# Second argument "near": start next to the legendary crossbow, its card shown.
	if args.size() > 1 and args[1] == "near":
		_player.position = Vector2(2.5 * tile + 2.0 * spacing, 2.5 * tile + 2.0 * spacing + 12.0)
	var skill_id: String = args[0] if not args.is_empty() else "parry"
	_player.starting_skill = load(SKILLS_DIR % skill_id) as SkillData
	add_child(_player)
	_player.add_weapon(SWORD)
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	add_child(hud)
	hud.bind_player(_player)
	var camera: Camera2D = Camera2D.new()
	camera.zoom = Vector2.ONE * camera_zoom
	_player.add_child(camera)
	camera.make_current()


func _unhandled_key_input(event: InputEvent) -> void:
	var key: InputEventKey = event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_K:
		_player.raise_active_weapon_level()
