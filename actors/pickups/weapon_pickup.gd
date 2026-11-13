class_name WeaponPickup
extends Area2D
## A weapon lying on the floor. It is not taken by walking over it: the player stands
## next to it and presses the interact button (E or the "Take" touch button).
## If both slots are full, the taken weapon replaces the one in hand and the old one
## is left lying here instead, so it can be taken back.
## Its rarity shows as an outline (grey, blue, gold) and as the colour of its name in
## the hint.

## Group of everything the player can interact with; the player looks for the nearest.
const GROUP: StringName = &"interactables"
const OUTLINE_SHADER: Shader = preload("res://actors/pickups/rarity_outline.gdshader")
const OUTLINE_DIRECTIONS: Array[Vector2] = [Vector2.LEFT, Vector2.RIGHT, Vector2.UP, Vector2.DOWN]

@export var weapon_data: WeaponData
@export var sprite: Sprite2D
## Gentle bobbing, so a weapon on the floor is easy to notice.
@export var bob_height: float = 2.0
@export var bob_speed: float = 3.0
## Thickness of the rarity outline, in pixels.
@export var outline_width: float = 1.0

var _time: float = 0.0
## Flat-coloured copies of the sprite behind it, one per direction.
var _outline: Array[Sprite2D] = []
var _outline_material: ShaderMaterial = null


func _ready() -> void:
	add_to_group(GROUP)
	collision_layer = 0
	collision_mask = 0
	_make_outline()
	_refresh()


func _process(delta: float) -> void:
	_time += delta
	if sprite != null:
		sprite.position.y = sin(_time * bob_speed) * bob_height


## Text of the hint shown while the player stands next to it, as BBCode: the name
## with its rarity, in the rarity colour, e.g. "Take [color=#4d99ff]Rare Sword[/color]".
func get_prompt() -> String:
	if weapon_data == null:
		return ""
	return "Take [color=#%s]%s[/color]" % [weapon_data.get_rarity().color.to_html(false), weapon_data.get_full_name()]


## Gives the weapon to the player. Returns true if something was taken.
func interact(player: Player) -> bool:
	if weapon_data == null:
		return false
	var dropped: WeaponData = player.pick_up_weapon(weapon_data)
	if dropped == null:
		queue_free()
	else:
		# Swap in place: the old weapon now lies where the new one was.
		weapon_data = dropped
		_refresh()
	return true


func _make_outline() -> void:
	if sprite == null:
		return
	# One material for the four copies: changing its colour recolours the whole outline.
	_outline_material = ShaderMaterial.new()
	_outline_material.shader = OUTLINE_SHADER
	for direction: Vector2 in OUTLINE_DIRECTIONS:
		var copy: Sprite2D = Sprite2D.new()
		copy.material = _outline_material
		copy.position = direction * outline_width
		# Children of the sprite bob with it; show_behind_parent draws them under it.
		copy.show_behind_parent = true
		sprite.add_child(copy)
		_outline.append(copy)


func _refresh() -> void:
	if sprite == null or weapon_data == null:
		return
	sprite.texture = weapon_data.icon
	for copy: Sprite2D in _outline:
		copy.texture = weapon_data.icon
	if _outline_material != null:
		_outline_material.set_shader_parameter(&"color", weapon_data.get_rarity().color)
