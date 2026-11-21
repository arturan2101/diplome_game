extends Node
## Manual preview of the spell looks by level (stage 26): every spell of the pool and
## every merged spell, at levels 1, 2 and 3, cast to the right on an open floor; saves
## <spell>_l<level>.png (a fireball also <spell>_l<level>_blast.png), then quits.
## Not part of the test suite.
## Usage: godot --path . res://tests/manual/spell_levels_preview.tscn -- <folder>

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const SPELLS: Array[String] = ["res://combat/spells/fireball.tres", "res://combat/spells/water.tres",
		"res://combat/spells/whirlwind.tres", "res://combat/spells/stone_spikes.tres",
		"res://combat/spells/steam.tres", "res://combat/spells/plasma.tres", "res://combat/spells/lava.tres",
		"res://combat/spells/lightning.tres", "res://combat/spells/vines.tres", "res://combat/spells/sandstorm.tres",
		"res://combat/spells/volcanic_lightning.tres", "res://combat/spells/storm_cloud.tres",
		"res://combat/spells/meteor.tres"]
const FLOOR_MAP: String = """########################################
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
#......................................#
########################################"""
const CAST_FRAMES: int = 12
const CLEAR_FRAMES: int = 30
const BLAST_TIMEOUT: int = 120
## Frames after the blast starts when it is saved.
const BLAST_SHOT_FRAMES: int = 8

var _out_dir: String = "user://spell_levels_preview"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	var level: Level = Level.new()
	level.debug_map = FLOOR_MAP
	add_child(level)
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.teleport(level.cell_center(Vector2i(12, 10)))
	player.health.max_hp = 100000
	player.health.reset()
	for path: String in SPELLS:
		var spell_data: SpellData = load(path) as SpellData
		for spell_level in range(1, SpellData.MAX_LEVEL + 1):
			player.spell_book.replace(0, spell_data)
			var spell: Spell = player.spell_book.get_spell(0)
			spell.level = spell_level
			await _frames(2)
			spell.try_cast(Vector2.RIGHT)
			await _frames(CAST_FRAMES)
			var name_base: String = "%s_l%d" % [spell_data.id, spell_level]
			await _save(name_base + ".png")
			if spell_data is FireballData:
				await _wait_for_blast(level)
				await _save(name_base + "_blast.png")
			spell.cancel()
			# Ice blocks and fireballs left over.
			get_tree().call_group(Arrow.GROUP, &"queue_free")
			await _frames(CLEAR_FRAMES)
	get_tree().quit()


func _wait_for_blast(level: Level) -> void:
	for _i in BLAST_TIMEOUT:
		for node: Node in level.find_children("*", "Fireball", true, false):
			if (node as Fireball).is_exploding():
				await _frames(BLAST_SHOT_FRAMES)
				return
		await _frames(1)


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))
