class_name Camp
extends Node2D
## The camp at the entrance to the ruins, between runs (stage 34; only with the progress
## between runs on). The player walks around a grass clearing under the cliffs: the
## arch in the cliff starts a run, the skill altar opens the permanent skills (stage 35),
## the shelf of books the spell unlocks (stage 36); a campfire and a tent for the look.
## The clearing is a hand-made map (camp/camp_map.txt) drawn by the real Level code
## with the camp tiles. Letters in the map put things on cells.

## The altar or the shelf was used (their screens listen).
signal skills_requested
signal spells_requested
## The player went through the arch: a new run starts.
signal entered_ruins

const GAME_SCENE: String = "res://main/main.tscn"
## Letters of the map: a thing standing on that cell (the cell itself is floor),
## and ":" a cell of the dirt path.
const MARK_ENTRANCE: String = "E"
const MARK_FIRE: String = "F"
const MARK_TENT: String = "T"
const MARK_ALTAR: String = "A"
const MARK_SHELF: String = "S"
const MARK_START: String = "P"
const MARK_PATH: String = ":"
const WALL_CHAR: String = "#"
const COVER_CHAR: String = "%"

@export var level: Level
@export var player: Player
@export var hud: Hud
@export_file("*.txt") var map_path: String = "res://camp/camp_map.txt"
@export_group("Look")
@export var entrance_texture: Texture2D = preload("res://assets/art/level/ruins_entrance.png")
@export var campfire_texture: Texture2D = preload("res://assets/art/level/campfire.png")
@export var campfire_frames: int = 4
@export var tent_texture: Texture2D = preload("res://assets/art/level/tent.png")
@export var altar_texture: Texture2D = preload("res://assets/art/level/altar.png")
@export var altar_frames: int = 4
@export var shelf_texture: Texture2D = preload("res://assets/art/level/spell_shelf.png")
## Warm glow of the campfire (additive).
@export var fire_light: Texture2D = preload("res://assets/art/fx/light_torch.png")
@export var fire_light_color: Color = Color(1.0, 0.6, 0.3, 0.2)
@export var fire_light_scale: float = 2.0
@export_flags_2d_physics var solid_layer: int = 1
## Change to the game scene when the player enters the ruins (tests turn it off).
@export var change_scene_on_enter: bool = true
## The permanent skills the altar sells (stage 35) and the spells the shelf unlocks
## (stage 36).
@export var perk_tree: PerkTree = preload("res://progression/perks.tres")
@export var spell_pool: SpellPool = preload("res://combat/spells/spell_pool.tres")

## The altar's and the shelf's screens, made in code.
var skill_screen: SkillTreeScreen = null
var shelf_screen: SpellShelfScreen = null

## Cells of the letters in the map: {letter: cell}.
var marks: Dictionary = {}
var entrance: CampStation = null
var altar: CampStation = null
var shelf: CampStation = null


func _ready() -> void:
	level.build(read_map())
	player.add_weapon(GameManager.starting_weapon)
	player.set_skill(GameManager.starting_skill)
	player.teleport(level.cell_center(marks.get(MARK_START, Vector2i.ONE)))
	hud.bind_player(player)
	hud.show_camp()
	_place_things()
	skill_screen = SkillTreeScreen.new()
	skill_screen.name = "SkillTreeScreen"
	add_child(skill_screen)
	skills_requested.connect(func() -> void: skill_screen.open(perk_tree))
	shelf_screen = SpellShelfScreen.new()
	shelf_screen.name = "SpellShelfScreen"
	add_child(shelf_screen)
	spells_requested.connect(func() -> void: shelf_screen.open(spell_pool))
	hud.show_banner("The camp at the ruins")


## The map as a LevelGrid; fills marks with the letters' cells.
func read_map() -> LevelGrid:
	var lines: PackedStringArray = FileAccess.get_file_as_string(map_path).strip_edges().split("\n")
	var rows: PackedStringArray = PackedStringArray()
	var paved: Array[Vector2i] = []
	marks.clear()
	for y in lines.size():
		var row: String = lines[y].strip_edges(false, true)
		var plain: String = ""
		for x in row.length():
			var letter: String = row[x]
			if letter == WALL_CHAR or letter == COVER_CHAR:
				plain += letter
				continue
			if letter == MARK_PATH:
				paved.append(Vector2i(x, y))
			elif letter != ".":
				marks[letter] = Vector2i(x, y)
			plain += "."
		rows.append(plain)
	var grid: LevelGrid = LevelGrid.from_text("\n".join(rows))
	for cell: Vector2i in paved:
		grid.paved[cell] = true
	return grid


func _place_things() -> void:
	if marks.has(MARK_ENTRANCE):
		_add_picture(entrance_texture, 1, marks[MARK_ENTRANCE], false)
		entrance = _add_station(marks[MARK_ENTRANCE], "Enter the ruins")
		entrance.used.connect(_on_entrance_used)
	if marks.has(MARK_FIRE):
		_add_picture(campfire_texture, campfire_frames, marks[MARK_FIRE], true)
		_add_glow(marks[MARK_FIRE])
	if marks.has(MARK_TENT):
		_add_picture(tent_texture, 1, marks[MARK_TENT], true)
	if marks.has(MARK_ALTAR):
		_add_picture(altar_texture, altar_frames, marks[MARK_ALTAR], true)
		altar = _add_station(marks[MARK_ALTAR] + Vector2i.DOWN, "Skills at the altar")
		altar.used.connect(_on_altar_used)
	if marks.has(MARK_SHELF):
		_add_picture(shelf_texture, 1, marks[MARK_SHELF], true)
		shelf = _add_station(marks[MARK_SHELF] + Vector2i.DOWN, "Spells on the shelf")
		shelf.used.connect(_on_shelf_used)


## A picture standing on a cell (its bottom on the cell's bottom), animated if it is a
## strip; solid things get a small body at their foot.
func _add_picture(picture: Texture2D, frames: int, cell: Vector2i, solid: bool) -> void:
	if picture == null:
		return
	var sprite: StripSprite = StripSprite.new()
	sprite.texture = picture
	sprite.hframes = maxi(frames, 1)
	sprite.fps = 6.0 if frames > 1 else 0.0
	var size: Vector2 = Vector2(picture.get_width() / maxi(frames, 1), picture.get_height())
	sprite.position = level.to_local(level.cell_center(cell)) + Vector2(0.0, 8.0 - size.y * 0.5)
	level.add_child(sprite)
	if solid:
		var body: StaticBody2D = StaticBody2D.new()
		body.collision_layer = solid_layer
		body.collision_mask = 0
		var shape: CollisionShape2D = CollisionShape2D.new()
		var rect: RectangleShape2D = RectangleShape2D.new()
		rect.size = Vector2(size.x - 4.0, 10.0)
		shape.shape = rect
		body.add_child(shape)
		body.position = level.to_local(level.cell_center(cell)) + Vector2(0.0, 2.0)
		level.add_child(body)


func _add_glow(cell: Vector2i) -> void:
	if fire_light == null:
		return
	var glow: Sprite2D = Sprite2D.new()
	glow.texture = fire_light
	glow.scale = Vector2.ONE * fire_light_scale
	glow.modulate = fire_light_color
	var additive: CanvasItemMaterial = CanvasItemMaterial.new()
	additive.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	glow.material = additive
	glow.position = level.to_local(level.cell_center(cell))
	level.add_child(glow)


func _add_station(cell: Vector2i, hint: String) -> CampStation:
	var station: CampStation = CampStation.new()
	station.prompt = hint
	station.position = level.to_local(level.cell_center(cell))
	level.add_child(station)
	return station


func _on_entrance_used(_station: CampStation) -> void:
	player.set_controls_enabled(false)
	GameManager.start_run()
	entered_ruins.emit()
	if not change_scene_on_enter:
		return
	await hud.fade_out()
	get_tree().change_scene_to_file(GAME_SCENE)


func _on_altar_used(_station: CampStation) -> void:
	if skills_requested.get_connections().is_empty():
		hud.show_banner("The altar is quiet for now")
	skills_requested.emit()


func _on_shelf_used(_station: CampStation) -> void:
	if spells_requested.get_connections().is_empty():
		hud.show_banner("The shelf is dusty for now")
	spells_requested.emit()
