class_name BreakableWall
extends Node2D
## The cracked wall in front of a secret room (stage 24). The cell itself is an ordinary
## wall of the level; this node only draws the faint crack and takes the hit. Its
## hurtbox lies on the floor right in front of the wall face, on the "breakable" physics
## layer, which only the player's melee weapons look at: arrows, spells and the
## auto-aim do not see it, and the sword must be swung right next to the wall. One hit
## and it crumbles: broken is emitted, and the game turns the cell into floor.

## Emitted once when a hit breaks the wall.
signal broken(wall: BreakableWall)

## Physics layer of the hurtbox (layer 6, "breakable").
@export_flags_2d_physics var hurtbox_layer: int = 32
## Draw a crack over the wall: off when the level's tiles already show it.
@export var draw_crack: bool = true
## Picture of the crack over the wall tile (centred); empty = a few lines drawn in code.
@export var crack_texture: Texture2D
## The wall falling down (placed where the wall was); empty = stones drawn in code.
@export var collapse_scene: PackedScene = preload("res://actors/effects/wall_collapse.tscn")
@export var crack_color: Color = Color(0.04, 0.04, 0.06, 0.6)
## How far in front of the wall centre the hurtbox lies (pixels; half a tile is 8).
@export var hurtbox_offset: float = 10.0
@export var hurtbox_size: Vector2 = Vector2(12.0, 4.0)
## Seconds the falling stones are shown.
@export var crumble_time: float = 0.45
@export var stone_color: Color = Color(0.36, 0.38, 0.45)

## The wall cell, and the unit vector from it towards the room the player comes from.
var cell: Vector2i = Vector2i.ZERO
var front: Vector2 = Vector2.DOWN
var health: Health = null
var hurtbox: Hurtbox = null

var _crumble_left: float = -1.0


func setup(wall_cell: Vector2i, front_direction: Vector2i) -> void:
	cell = wall_cell
	front = Vector2(front_direction)


func _ready() -> void:
	health = Health.new()
	health.name = "Health"
	health.max_hp = 1
	add_child(health)
	hurtbox = Hurtbox.new()
	hurtbox.name = "Hurtbox"
	hurtbox.health = health
	hurtbox.collision_layer = hurtbox_layer
	hurtbox.collision_mask = 0
	hurtbox.monitoring = false
	# On the floor in front of the wall: the sword's line of sight to it stays clear.
	hurtbox.position = front * hurtbox_offset
	var shape: CollisionShape2D = CollisionShape2D.new()
	var rect: RectangleShape2D = RectangleShape2D.new()
	rect.size = hurtbox_size if is_zero_approx(front.x) else Vector2(hurtbox_size.y, hurtbox_size.x)
	shape.shape = rect
	hurtbox.add_child(shape)
	add_child(hurtbox)
	health.died.connect(_on_died)


func is_broken() -> bool:
	return health != null and health.is_dead()


func _on_died(_info: DamageInfo) -> void:
	hurtbox.set_deferred("monitorable", false)
	broken.emit(self)
	if collapse_scene != null and get_parent() != null:
		var collapse: Node2D = collapse_scene.instantiate() as Node2D
		collapse.position = position
		get_parent().add_child.call_deferred(collapse)
		queue_free()
		return
	_crumble_left = crumble_time
	queue_redraw()


func _process(delta: float) -> void:
	if _crumble_left < 0.0:
		return
	_crumble_left -= delta
	queue_redraw()
	if _crumble_left <= 0.0:
		queue_free()


func _draw() -> void:
	if _crumble_left >= 0.0:
		# Stones falling out of the wall towards the room.
		var t: float = 1.0 - _crumble_left / crumble_time
		var color: Color = stone_color
		color.a = 1.0 - t
		for i in 6:
			var spread: Vector2 = Vector2(float(i % 3) - 1.0, float(i / 3) - 0.5) * 6.0
			draw_rect(Rect2(spread + front * (t * 10.0) - Vector2(1.5, 1.5), Vector2(3.0, 3.0)), color)
		return
	if not draw_crack:
		return
	if crack_texture != null:
		draw_texture(crack_texture, -crack_texture.get_size() * 0.5)
		return
	var side: Vector2 = front.orthogonal()
	var points: PackedVector2Array = PackedVector2Array([
			side * -5.0 + front * 5.0, side * -2.0 + front * 2.0, side * 1.0 + front * 4.0,
			side * 3.0 + front * 0.0, side * 5.0 + front * 3.0])
	draw_polyline(points, crack_color, 1.0)
