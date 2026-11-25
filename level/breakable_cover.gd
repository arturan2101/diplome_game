class_name BreakableCover
extends Node2D
## An obstacle on cover cells that breaks under melee blows (stage 47,
## ExperimentConfig.breakable_cover): a column, rocks, a sarcophagus, a barrel... The
## cells stay ordinary cover of the level (solid, drawn by LevelDecor); this node only
## takes the hits. Its hurtbox covers the obstacle a little wider than its cells, on the
## "breakable" physics layer that only the player's melee weapons look at (arrows,
## spells and the auto-aim do not see it). Every blow gives a puff of dust; at zero
## health broken is emitted and the game turns the cells into floor.

## Emitted once when it breaks.
signal broken(cover: BreakableCover)

## Physics layer of the hurtbox (layer 6, "breakable").
@export_flags_2d_physics var hurtbox_layer: int = 32
## How far the hurtbox reaches past the cells, pixels.
@export var hurtbox_margin: float = 3.0
## The stones falling where it stood.
@export var collapse_scene: PackedScene = preload("res://actors/effects/wall_collapse.tscn")
## A puff on every blow (a strip played once).
@export var hit_effect: Texture2D = preload("res://assets/art/fx/dust_puff.png")
@export var hit_effect_frames: int = 4
@export var hit_sound: StringName = &"arrow_hit_wall"
@export var break_sound: StringName = &"boulder_hit"

## The cover cells it stands on.
var cells: Array[Vector2i] = []
var health: Health = null
var hurtbox: Hurtbox = null

var _max_hp: int = 1
var _rect: Rect2 = Rect2()


## cells_rect: the global rect of its cells; hp: blows it takes, as damage.
func setup(cover_cells: Array[Vector2i], cells_rect: Rect2, hp: int) -> void:
	cells = cover_cells
	_rect = cells_rect
	_max_hp = maxi(hp, 1)


func _ready() -> void:
	global_position = _rect.get_center()
	health = Health.new()
	health.name = "Health"
	health.max_hp = _max_hp
	add_child(health)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.health = health
	hurtbox.collision_layer = hurtbox_layer
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	hurtbox.solid_rect = _rect
	var shape: CollisionShape2D = CollisionShape2D.new()
	var box: RectangleShape2D = RectangleShape2D.new()
	box.size = _rect.size + Vector2.ONE * hurtbox_margin * 2.0
	shape.shape = box
	hurtbox.add_child(shape)
	add_child(hurtbox)
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func is_broken() -> bool:
	return health != null and health.is_dead()


func _on_damaged(_info: DamageInfo) -> void:
	if health.is_dead():
		return
	Sound.play_at(hit_sound, global_position)
	StripSprite.spawn(get_parent(), global_position, hit_effect, hit_effect_frames, 16.0)


func _on_died(_info: DamageInfo) -> void:
	hurtbox.set_deferred("monitorable", false)
	Sound.play_at(break_sound, global_position)
	broken.emit(self)
	if collapse_scene != null and get_parent() != null:
		var collapse: Node2D = collapse_scene.instantiate() as Node2D
		collapse.position = position
		get_parent().add_child.call_deferred(collapse)
	queue_free()
