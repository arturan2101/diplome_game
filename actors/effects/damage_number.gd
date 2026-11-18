class_name DamageNumber
extends Node2D
## Visual only: the damage a hit dealt, in pixel digits (a strip of 0-9), rising a little
## over the actor and fading out, then freed.

const DIGITS: Texture2D = preload("res://assets/art/ui/damage_digits.png")
## Width of one digit cell in the strip, and the step between digits (outlines overlap).
const CELL: Vector2 = Vector2(5.0, 7.0)
const STEP: float = 4.0

## Seconds it stays, and how far it rises in that time.
@export var lifetime: float = 0.6
@export var rise: float = 10.0

var amount: int = 0
var tint: Color = Color.WHITE

var _age: float = 0.0


## Shows amount at a global position under parent.
static func spawn(parent: Node, at: Vector2, value: int, color: Color = Color.WHITE) -> DamageNumber:
	if parent == null or value <= 0:
		return null
	var number: DamageNumber = DamageNumber.new()
	number.amount = value
	number.tint = color
	parent.add_child(number)
	number.global_position = at
	return number


func _process(delta: float) -> void:
	_age += delta
	if _age >= lifetime:
		queue_free()
		set_process(false)
		return
	position.y -= rise * delta / lifetime
	modulate.a = clampf(2.0 * (1.0 - _age / lifetime), 0.0, 1.0)


func _draw() -> void:
	var text: String = str(amount)
	var x: float = -(STEP * (text.length() - 1) + CELL.x) * 0.5
	for i in text.length():
		var digit: int = text.unicode_at(i) - 48
		draw_texture_rect_region(DIGITS, Rect2(Vector2(x + STEP * i, -CELL.y * 0.5), CELL),
				Rect2(Vector2(digit * CELL.x, 0.0), CELL), tint)
