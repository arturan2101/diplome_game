extends Node2D
## Shows a whole generated section zoomed out, with markers for the entrance, the
## gate, enemies and items. For checking the generator by eye and for screenshots.
## Run tools/section_viewer.tscn (F6). Enter / Space builds the next section index.

@export var run_seed: int = 12345
@export var section_index: int = 0
@export_range(3, 5) var room_count: int = 4
@export var has_side_branch: bool = true
@export var has_chest: bool = true
@export_range(2, 4) var corridor_width: int = 3
@export_range(0.0, 1.0) var corridor_twist: float = 0.3
@export_range(0.0, 1.0) var cover_density: float = 0.5
@export var enemy_mix: Dictionary = {&"skeleton": 3, &"archer": 2, &"beetle": 1}

const TILE: float = 16.0
const SCREEN: Vector2 = Vector2(640.0, 360.0)
const MARKER_RADIUS: float = 5.0
const ENTRANCE_COLOR: Color = Color(0.3, 1.0, 0.4)
const EXIT_COLOR: Color = Color(0.3, 0.9, 1.0)
const ITEM_COLORS: Dictionary = {
	SectionLayout.ITEM_HEALTH_PACK: Color(1.0, 0.3, 0.3),
	SectionLayout.ITEM_COIN: Color(1.0, 0.85, 0.2),
	SectionLayout.ITEM_CHEST: Color(0.8, 0.5, 0.2),
}
const ENEMY_COLORS: Dictionary = {
	&"skeleton": Color(0.9, 0.9, 0.9),
	&"archer": Color(0.4, 0.8, 0.4),
	&"beetle": Color(0.7, 0.4, 0.9),
}

var _level: Level = null
var _camera: Camera2D = null
var _layout: SectionLayout = null


func _ready() -> void:
	_level = Level.new()
	_level.show_behind_parent = true
	add_child(_level)
	_camera = Camera2D.new()
	add_child(_camera)
	_build()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_accept"):
		section_index += 1
		_build()


func _build() -> void:
	var plan: SectionPlan = SectionPlan.new()
	plan.section_index = section_index
	plan.room_count = room_count
	plan.has_side_branch = has_side_branch
	plan.has_chest = has_chest
	plan.corridor_width = corridor_width
	plan.corridor_twist = corridor_twist
	plan.cover_density = cover_density
	plan.enemy_mix = enemy_mix
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = hash([run_seed, section_index])
	_layout = SectionBuilder.new().build(plan, rng)
	_level.build(_layout.grid)
	var size: Vector2 = Vector2(_layout.grid.width, _layout.grid.height) * TILE
	_camera.position = size * 0.5
	var zoom: float = minf(SCREEN.x / size.x, SCREEN.y / size.y)
	_camera.zoom = Vector2(zoom, zoom)
	print("Section %d: %s tiles, rooms %s, attempts %d, enemies %s" % [
			section_index, Vector2i(_layout.grid.width, _layout.grid.height), _layout.room_names,
			_layout.attempts, _layout.count_enemies()])
	queue_redraw()


func _draw() -> void:
	if _layout == null:
		return
	draw_circle(_center(_layout.entrance), MARKER_RADIUS * 1.5, ENTRANCE_COLOR)
	draw_circle(_center(_layout.exit), MARKER_RADIUS * 1.5, EXIT_COLOR)
	for entry: Dictionary in _layout.items:
		draw_circle(_center(entry["cell"]), MARKER_RADIUS * 0.7, ITEM_COLORS.get(entry["id"], Color.WHITE))
	for entry: Dictionary in _layout.enemies:
		draw_circle(_center(entry["cell"]), MARKER_RADIUS, ENEMY_COLORS.get(entry["id"], Color.WHITE))


func _center(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * TILE
