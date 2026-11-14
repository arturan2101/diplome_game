class_name SpawnMarker
extends Node2D
## Warns where an enemy of a combat-room wave is about to appear for `seconds`, then
## emits expired and frees itself. It counts physics steps, so a wave appears at the
## same moment every time. The look is the art's SpawnWarning ring; without it a ring
## is drawn in code.

## Emitted once when the warning is over: the enemy appears now.
signal expired(marker: SpawnMarker)

## Picture of the warning (a scene with a `duration` property that frees itself).
@export var look_scene: PackedScene = preload("res://actors/effects/spawn_warning.tscn")
@export var radius: float = 7.0
@export var color: Color = Color(0.85, 0.35, 0.95, 0.85)
@export var ring_width: float = 1.5

## Cell the enemy appears on (set by whoever places the marker).
var cell: Vector2i = Vector2i.ZERO
var _total: float = 1.0
var _left: float = 1.0


func start(seconds: float) -> void:
	_total = maxf(seconds, 0.01)
	_left = _total
	if look_scene != null:
		var look: Node = look_scene.instantiate()
		if "duration" in look:
			look.set("duration", _total)
		add_child(look)


## The ring's own z_index (-1) would hide it under the floor tiles. A parent is ready
## after its children, so this runs after the ring has set it; the marker itself is
## drawn first among the section's things, so the ring stays under the actors.
func _ready() -> void:
	for child: Node in get_children():
		if child is CanvasItem:
			(child as CanvasItem).z_index = 0


## Share of the warning already over, 0-1.
func get_progress() -> float:
	return clampf(1.0 - _left / _total, 0.0, 1.0)


func _physics_process(delta: float) -> void:
	_left -= delta
	queue_redraw()
	if _left <= 0.0:
		set_physics_process(false)
		expired.emit(self)
		queue_free()


func _draw() -> void:
	if look_scene != null:
		return
	draw_arc(Vector2.ZERO, radius, 0.0, TAU, 24, color, ring_width)
	var fill: Color = color
	fill.a *= 0.5
	draw_circle(Vector2.ZERO, radius * get_progress(), fill)
