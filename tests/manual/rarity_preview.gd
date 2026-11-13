extends Node2D
## Manual preview of weapon rarity (open rarity_preview.tscn and press F6): a sword and
## a bow of every rarity on the floor, the player next to the legendary bow (its hint is
## shown), and the HUD slots with their rarity bars. Walk around and press E to swap.

const PICKUP_SCENE: PackedScene = preload("res://actors/pickups/weapon_pickup.tscn")
const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const HUD_SCENE: PackedScene = preload("res://ui/hud.tscn")
const RARITY_TABLE: RarityTable = preload("res://combat/weapons/rarity_table.tres")
const SWORD: WeaponData = preload("res://combat/weapons/sword.tres")
const BOW: WeaponData = preload("res://combat/weapons/bow.tres")
## Floor around the weapons ('#' wall, '.' floor), one character per tile.
const FLOOR_MAP: String = """###########
#.........#
#.........#
#.........#
#.........#
#.........#
###########"""

## Distance between the weapons on the floor, in pixels.
@export var spacing: float = 32.0
@export var camera_zoom: float = 2.5


func _ready() -> void:
	var level: Level = Level.new()
	level.debug_map = FLOOR_MAP
	add_child(level)
	var size: Vector2 = Vector2(level.grid.width, level.grid.height) * float(level.theme.tile_size)
	level.position = -size * 0.5

	var weapons: Array[WeaponData] = [SWORD, BOW]
	var last: WeaponPickup = null
	for row in weapons.size():
		for column in RARITY_TABLE.rarities.size():
			var pickup: WeaponPickup = PICKUP_SCENE.instantiate() as WeaponPickup
			pickup.weapon_data = weapons[row].with_rarity(RARITY_TABLE.rarities[column])
			pickup.position = Vector2((column - 1) * spacing, (row - 0.5) * spacing)
			add_child(pickup)
			last = pickup

	var player: Player = PLAYER_SCENE.instantiate() as Player
	player.position = last.position + Vector2(0.0, spacing * 0.5)
	add_child(player)
	player.add_weapon(SWORD.with_rarity(RARITY_TABLE.rarities[1]))
	player.add_weapon(BOW.with_rarity(RARITY_TABLE.rarities[2]))
	var hud: Hud = HUD_SCENE.instantiate() as Hud
	add_child(hud)
	hud.bind_player(player)

	var camera: Camera2D = Camera2D.new()
	camera.zoom = Vector2.ONE * camera_zoom
	add_child(camera)
	camera.make_current()
