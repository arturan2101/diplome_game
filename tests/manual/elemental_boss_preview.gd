extends Node
## Manual preview of the elemental Wardens (stage 45) and the Mycelium Mother (stage 48): in a small room of their floor's
## style, the player stands still and each boss's attacks are photographed: the special
## attack's warning and strikes, the throw and its patch, the slam and the shockwave
## ring (the Mother does not throw: her shot 4 shows her walking up). Not part of the test suite.
## Usage: godot --path . res://tests/manual/elemental_boss_preview.tscn -- <folder>

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const BOSSES: Dictionary = {
	"tide": ["res://actors/enemies/tide_warden.tres", "res://level/flooded_theme.tres"],
	"molten": ["res://actors/enemies/molten_warden.tres", "res://level/fire_theme.tres"],
	"mother": ["res://actors/enemies/mycelium_mother.tres", "res://level/fungal_theme.tres"],
}
const ROOM_MAP: String = """####################
#..................#
#..................#
#..................#
#..................#
#..................#
#..................#
#..................#
#..................#
####################"""
const BIG_HP: int = 100000

var _out_dir: String = "user://boss_preview"


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(_out_dir)
	Telemetry.write_enabled = false
	GameManager.start_run(4500)
	for key: String in BOSSES:
		await _shoot_boss(key, BOSSES[key][0], BOSSES[key][1])
	get_tree().quit()


func _shoot_boss(key: String, boss_path: String, theme_path: String) -> void:
	var level: Level = Level.new()
	add_child(level)
	level.set_theme(load(theme_path) as TileTheme)
	level.build(LevelGrid.from_text(ROOM_MAP))
	var player: Player = PLAYER_SCENE.instantiate() as Player
	add_child(player)
	player.global_position = level.cell_center(Vector2i(5, 5))
	player.health.max_hp = BIG_HP
	player.health.reset()
	player.set_physics_process(false)
	var stats: GuardianData = load(boss_path) as GuardianData
	var boss: Guardian = stats.scene.instantiate() as Guardian
	boss.data = stats
	add_child(boss)
	boss.global_position = level.cell_center(Vector2i(12, 5))
	# Special attack first.
	boss._special_cooldown_left = 0.0
	await _frames(2)
	await _frames(roundi(stats.special_windup * 0.8 * 60))
	await _save("%s_1_special_windup.png" % key)
	await _frames(roundi(stats.special_windup * 0.2 * 60) + 20)
	await _save("%s_2_special_warning.png" % key)
	await _frames(roundi(stats.special_zone.impact_delay * 60))
	await _save("%s_3_special_strike.png" % key)
	await _frames(40)
	# Throw: the special waits for its cooldown now.
	await _frames(roundi((stats.throw_windup + 0.6) * 60))
	await _save("%s_4_after_throw.png" % key)
	# Slam and shockwave: move close and switch to the second phase.
	boss.global_position = level.cell_center(Vector2i(7, 5))
	boss._enter_phase_two()
	await _frames(roundi((stats.roar_time + stats.shockwave_windup) * 60) + 4)
	await _save("%s_5_shockwave.png" % key)
	await _frames(roundi((stats.recovery + stats.windup) * 60) + 30)
	await _save("%s_6_slam.png" % key)
	for node: Node in get_tree().get_nodes_in_group(Arrow.GROUP):
		node.queue_free()
	for node: Node in [boss, player, level]:
		node.queue_free()
	await _frames(3)


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
