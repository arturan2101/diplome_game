@tool
class_name PlaceholderShape
extends Node2D
## Temporary visual drawn in code (circle or rectangle) until real sprites exist.
## Gameplay scripts never reference this node, so it can be swapped for a Sprite2D later.

enum ShapeType { CIRCLE, RECTANGLE }

@export var shape_type: ShapeType = ShapeType.CIRCLE:
	set(value):
		shape_type = value
		queue_redraw()
## Width and height in pixels. A circle uses size.x as its diameter.
@export var size: Vector2 = Vector2(12.0, 12.0):
	set(value):
		size = value
		queue_redraw()
@export var color: Color = Color.WHITE:
	set(value):
		color = value
		queue_redraw()


func _draw() -> void:
	match shape_type:
		ShapeType.CIRCLE:
			draw_circle(Vector2.ZERO, size.x * 0.5, color)
		ShapeType.RECTANGLE:
			draw_rect(Rect2(-size * 0.5, size), color)
