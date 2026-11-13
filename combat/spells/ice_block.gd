class_name IceBlock
extends StaticBody2D
## One block of the ice wall: a solid tile on the world layer, so it stops enemies,
## the player and arrows like a wall does (enemy paths do not know about it, so
## enemies push against it). Melts after its lifetime: fades out, then disappears.

## Seconds the block stands, set by the spell; the last melt_time seconds it fades.
@export var lifetime: float = 4.0
@export var melt_time: float = 0.5
## Placeholder look: a square of this size and colour.
@export var size: float = 16.0
@export var color: Color = Color(0.6, 0.85, 1.0)


func _ready() -> void:
	# Cleared between sections together with arrows and fireballs.
	add_to_group(Arrow.GROUP)


func _physics_process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		set_physics_process(false)
		return
	if lifetime < melt_time:
		modulate.a = lifetime / melt_time


func _draw() -> void:
	var rect: Rect2 = Rect2(Vector2(-size, -size) * 0.5, Vector2(size, size))
	draw_rect(rect, Color(color, 0.85))
	draw_rect(rect.grow(-1.0), Color(1.0, 1.0, 1.0, 0.6), false, 1.0)
