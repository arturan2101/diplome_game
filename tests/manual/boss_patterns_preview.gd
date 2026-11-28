extends Node
## Manual preview of a boss's attack patterns (stage 50) in the boss arena of its floor,
## the boss standing in the middle (asleep, only for the look): the Mycelium Mother or
## the Sun Pharaoh (pharaoh on). Its patterns of both phases come from its GuardianData.
## With a folder argument it photographs each pattern's warning and strike and quits;
## without one it casts the patterns one after another forever, aimed at you, and you
## walk round them. With fight on the boss is awake and fights you as in the game, both
## phases (no servants come; you cannot die). Not part of the test suite.
## Usage: godot --path . res://tests/manual/boss_patterns_preview.tscn [-- <folder> [pharaoh]]

const PLAYER_SCENE: PackedScene = preload("res://actors/player/player.tscn")
const ARENA: String = "res://rooms/arena.txt"
const MOTHER: String = "res://actors/enemies/mycelium_mother.tres"
const MOTHER_THEME: String = "res://level/fungal_theme.tres"
const PHARAOH: String = "res://actors/enemies/sun_pharaoh.tres"
const PHARAOH_THEME: String = "res://level/sand_theme.tres"
const PHARAOH_ARG: String = "pharaoh"
const PLAYER_HURTBOX: int = 8
const BIG_HP: int = 100000
const PAUSE: float = 1.0

## The boss fights you instead of the patterns looping by themselves.
@export var fight: bool = false
## The Sun Pharaoh on the sand floor instead of the Mother on the fungal one.
@export var pharaoh: bool = false

var _out_dir: String = ""
var _level: Level = null
var _player: Player = null
var _center: Vector2 = Vector2.ZERO
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
var _label: Label = null
var _boss: Guardian = null
var _patterns: Array[BossPattern] = []


func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() > 0:
		_out_dir = args[0]
	pharaoh = pharaoh or args.has(PHARAOH_ARG)
	Telemetry.write_enabled = false
	GameManager.start_run(5050)
	_rng.seed = 5050
	_build()
	if _out_dir != "":
		DirAccess.make_dir_recursive_absolute(_out_dir)
		await _shoot_all()
		get_tree().quit()
		return
	if fight:
		_boss.awaken()
		return
	while true:
		for pattern: BossPattern in _patterns:
			_label.text = _name_of(pattern)
			pattern.cast(_level, _center, _player.global_position, null, &"preview", 1.0, PLAYER_HURTBOX, _rng)
			await get_tree().create_timer(pattern.get_duration() + PAUSE).timeout


func _build() -> void:
	_level = Level.new()
	add_child(_level)
	_level.set_theme(load(PHARAOH_THEME if pharaoh else MOTHER_THEME) as TileTheme)
	var rows: PackedStringArray = PackedStringArray()
	for line: String in FileAccess.get_file_as_string(ARENA).split("\n"):
		if line.strip_edges() != "" and not line.begins_with(";"):
			rows.append(line.strip_edges())
	_level.build(LevelGrid.from_text("\n".join(rows)))
	var middle: Vector2i = Vector2i(rows[0].length() / 2, rows.size() / 2)
	# Where the game puts the boss: the floor cell nearest the arena's middle.
	_center = _level.cell_center(_level.nearest_floor_cell(middle))
	var stats: GuardianData = load(PHARAOH if pharaoh else MOTHER) as GuardianData
	for pattern: BossPattern in stats.patterns_phase_one + stats.patterns_phase_two:
		if not pattern in _patterns:
			_patterns.append(pattern)
	_boss = stats.scene.instantiate() as Guardian
	_boss.data = stats
	add_child(_boss)
	_boss.global_position = _center
	_boss.make_dormant()
	_player = PLAYER_SCENE.instantiate() as Player
	add_child(_player)
	_player.global_position = _level.cell_center(middle + Vector2i(4, 2))
	_player.health.max_hp = BIG_HP
	_player.health.reset()
	var layer: CanvasLayer = CanvasLayer.new()
	add_child(layer)
	_label = Label.new()
	_label.position = Vector2(8.0, 4.0)
	layer.add_child(_label)


func _process(_delta: float) -> void:
	if not fight or _boss == null or not is_instance_valid(_boss):
		return
	var pattern: BossPattern = _boss.get_pattern()
	_label.text = "phase %d   HP %d/%d   %s" % [_boss.phase, _boss.health.hp, _boss.health.max_hp,
			_name_of(pattern) if pattern != null else ""]


func _shoot_all() -> void:
	await _frames(10)
	for pattern: BossPattern in _patterns:
		var name: String = _name_of(pattern)
		_label.text = name
		pattern.cast(_level, _center, _player.global_position, null, &"preview", 1.0, PLAYER_HURTBOX, _rng)
		await _frames(roundi(pattern.warn_time * 0.7 * 60.0))
		await _save("%s_1_warning.png" % name)
		await _frames(roundi(pattern.warn_time * 0.3 * 60.0) + 6)
		await _save("%s_2_strike.png" % name)
		if pattern is SweepPattern or (pattern is FieldPattern) or (pattern is RaysPattern and (pattern as RaysPattern).volleys > 1):
			await _frames(roundi(pattern.warn_time * 0.9 * 60.0))
			await _save("%s_3_later.png" % name)
		await _frames(roundi((pattern.get_duration() + 0.6) * 60.0))


func _name_of(pattern: BossPattern) -> String:
	return pattern.resource_path.get_file().get_basename()


func _save(file_name: String) -> void:
	await RenderingServer.frame_post_draw
	var path: String = _out_dir.path_join(file_name)
	get_viewport().get_texture().get_image().save_png(path)
	print("Saved ", ProjectSettings.globalize_path(path))


func _frames(count: int) -> void:
	for _i in count:
		await get_tree().physics_frame
