class_name LightShaft
extends Node2D
## Light falling from above through a hole in the ceiling of a secret room (stage 24):
## a soft warm trapezoid that slowly breathes. Visual only, no light engine; drawn in code
## until there is art (docs/art-assets.md).

## Picture of the beam (its bottom centre on the node); empty = drawn in code.
@export var texture: Texture2D
@export var color: Color = Color(1.0, 0.85, 0.5, 0.14)
## Width of the beam at the ceiling and on the floor, and its height (pixels).
@export var top_width: float = 10.0
@export var bottom_width: float = 26.0
@export var height: float = 40.0
## How much the light breathes (share of its alpha) and how fast (seconds per breath).
@export var flicker: float = 0.25
@export var period: float = 3.0

var _time: float = 0.0


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	var tint: Color = color
	tint.a *= 1.0 - flicker * 0.5 * (1.0 + sin(_time * TAU / period))
	if texture != null:
		draw_texture(texture, Vector2(-texture.get_width() * 0.5, -texture.get_height()), Color(1.0, 1.0, 1.0, tint.a / color.a))
		return
	draw_colored_polygon(PackedVector2Array([
			Vector2(-top_width * 0.5, -height), Vector2(top_width * 0.5, -height),
			Vector2(bottom_width * 0.5, 0.0), Vector2(-bottom_width * 0.5, 0.0)]), tint)
	var pool: Color = tint
	pool.a *= 1.2
	draw_circle(Vector2.ZERO, bottom_width * 0.45, pool)
