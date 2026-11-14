class_name Merchant
extends Interactable
## A merchant: the wandering one in a secret room (stage 24, cheaper) and the one on the
## glade between depths (stage 25). Talking to him (the interact button) asks the game
## to open the shop screen with his offers; the game takes the coins and hands the goods.
## The look: an animated old man (a green hood and a pack when wandering) behind a carpet
## of goods; without frames a placeholder figure is drawn in code.

## Emitted when the player talks to him.
signal shop_requested(merchant: Merchant)

## Animations (idle_down) of the merchant and of the wandering one.
@export var frames: SpriteFrames = preload("res://assets/art/characters/merchant_frames.tres")
@export var wandering_frames: SpriteFrames = preload("res://assets/art/characters/merchant_wander_frames.tres")
@export var idle_animation: StringName = &"idle_down"
## Offset of 24x24 actor art, so the feet stand on the node.
@export var sprite_offset: Vector2 = Vector2(0.0, -4.0)
## Goods laid out in front of him.
@export var carpet: Texture2D = preload("res://assets/art/props/merchant_carpet.png")
@export var carpet_offset: Vector2 = Vector2(0.0, 10.0)
## Draw the placeholder figure (when there are no frames).
@export var draw_placeholder: bool = true
@export var robe_color: Color = Color(0.29, 0.18, 0.47)
@export var hood_color: Color = Color(0.35, 0.22, 0.55)
@export var coin_color: Color = Color(0.88, 0.6, 0.13)

## What he sells (ShopStock.make_offers()).
var offers: Array[ShopOffer] = []
## A wandering merchant (secret room) sells cheaper.
var wandering: bool = false


func _ready() -> void:
	super()
	var look: SpriteFrames = wandering_frames if wandering else frames
	if look == null:
		return
	draw_placeholder = false
	if carpet != null:
		var rug: Sprite2D = Sprite2D.new()
		rug.texture = carpet
		rug.position = carpet_offset
		add_child(rug)
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = look
	sprite.offset = sprite_offset
	add_child(sprite)
	if look.has_animation(idle_animation):
		sprite.play(idle_animation)


func get_prompt() -> String:
	return "Trade"


func can_interact(_player: Player) -> bool:
	return not offers.is_empty()


func interact(_player: Player) -> bool:
	shop_requested.emit(self)
	return true


func _draw() -> void:
	if not draw_placeholder:
		return
	draw_colored_polygon(PackedVector2Array([Vector2(-6, 7), Vector2(6, 7), Vector2(3, -4), Vector2(-3, -4)]), robe_color)
	draw_circle(Vector2(0, -6), 4.0, hood_color)
	draw_circle(Vector2(5, 3), 2.0, coin_color)
