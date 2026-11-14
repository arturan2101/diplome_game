class_name ShopScreen
extends CanvasLayer
## The merchant's shop: one button per offer with its price; a button is off while the
## player cannot pay or the thing is sold. Buying emits bought, the game takes the coins
## and hands the goods, then calls refresh(). The game is paused while the screen is
## open; the screen itself keeps working (process mode Always). Esc and the phone's back
## button leave.

## The player chose an offer he can pay for.
signal bought(offer: ShopOffer)
signal closed

@export var panel: Control
@export var title: Label
@export var coins_label: Label
## A button per offer is created here.
@export var choices: Container
@export var leave_button: Button
@export var choice_size: Vector2 = Vector2(120.0, 72.0)
## Frame of an offer (a 9-patch with gold edges), and how the button looks when it is off.
@export var slot_texture: Texture2D = preload("res://assets/art/ui/trade_slot.png")
@export var slot_margin: float = 4.0
@export var disabled_tint: Color = Color(0.55, 0.55, 0.6)

var merchant: Merchant = null
var _coins: int = 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	panel.visible = false
	leave_button.pressed.connect(close)


func is_open() -> bool:
	return panel.visible


## Freed while open (the run ended under it): the pause must not outlive the screen.
func _exit_tree() -> void:
	if is_open():
		get_tree().paused = false


func open(shop_merchant: Merchant, coins: int) -> void:
	merchant = shop_merchant
	title.text = "Wandering merchant" if merchant.wandering else "Merchant"
	get_tree().paused = true
	panel.visible = true
	refresh(coins)


## Shows the offers again for this many coins (after a purchase).
func refresh(coins: int) -> void:
	_coins = coins
	coins_label.text = "Coins: %d" % coins
	for child: Node in choices.get_children():
		choices.remove_child(child)
		child.queue_free()
	for offer: ShopOffer in merchant.offers:
		var button: Button = Button.new()
		button.text = "%s\n%s" % [offer.get_title(), "sold" if offer.sold else "%d coins" % offer.price]
		button.icon = offer.get_icon()
		button.expand_icon = false
		button.custom_minimum_size = choice_size
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.disabled = offer.sold or offer.price > coins
		if slot_texture != null:
			for state: String in ["normal", "hover", "pressed", "focus"]:
				button.add_theme_stylebox_override(state, _slot_style(Color.WHITE))
			button.add_theme_stylebox_override("disabled", _slot_style(disabled_tint))
		button.pressed.connect(_on_offer_pressed.bind(offer))
		choices.add_child(button)


func _slot_style(tint: Color) -> StyleBoxTexture:
	var style: StyleBoxTexture = StyleBoxTexture.new()
	style.texture = slot_texture
	style.modulate_color = tint
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		style.set_texture_margin(side, slot_margin)
		style.set_content_margin(side, slot_margin + 4.0)
	return style


## The buttons of the offers, in offer order (for tests and the bot).
func get_offer_buttons() -> Array[Button]:
	var buttons: Array[Button] = []
	for child: Node in choices.get_children():
		if child is Button:
			buttons.append(child)
	return buttons


func close() -> void:
	if not is_open():
		return
	panel.visible = false
	get_tree().paused = false
	closed.emit()


func _on_offer_pressed(offer: ShopOffer) -> void:
	if offer.sold or offer.price > _coins:
		return
	bought.emit(offer)


func _unhandled_input(event: InputEvent) -> void:
	if is_open() and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and is_open():
		close()
