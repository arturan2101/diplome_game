class_name Hud
extends CanvasLayer
## Heads-up display of a run: health, weapon slots, skill cooldown, coins, depth,
## the pause button, icons on the touch buttons, and a black fade used between
## sections. Reads GameManager through its signals and the player through its nodes.

## Emitted when the pause button is pressed.
signal pause_pressed

@export var hp_bar: ProgressBar
@export var hp_label: Label
@export var coins_label: Label
@export var depth_label: Label
## One icon per weapon slot, in slot order.
@export var weapon_icons: Array[TextureRect] = []
@export var skill_icon: TextureRect
## Dark overlay on the skill icon; its height shows the cooldown left.
@export var skill_cooldown: Control
@export var pause_button: Button
## Icons drawn on the touch buttons.
@export var attack_button_icon: Sprite2D
@export var swap_button_icon: Sprite2D
@export var skill_button_icon: Sprite2D
## Full-screen rectangle faded in and out between sections.
@export var fade: ColorRect
## Seconds one fade takes.
@export var fade_time: float = 0.25
## Tint of the weapon slot that is not in hand.
@export var inactive_slot_color: Color = Color(1.0, 1.0, 1.0, 0.35)

var _player: Player = null


func _ready() -> void:
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.section_changed.connect(_on_section_changed)
	_on_coins_changed(GameManager.coins)
	_on_section_changed(GameManager.section_index, GameManager.depth)
	if pause_button != null:
		pause_button.pressed.connect(pause_pressed.emit)
	if fade != null:
		fade.color.a = 0.0


func _process(_delta: float) -> void:
	if skill_cooldown == null or not is_instance_valid(_player) or _player.skill == null:
		return
	# The overlay covers the bottom part of the icon in proportion to the cooldown left.
	skill_cooldown.anchor_top = 1.0 - _player.skill.get_cooldown_fraction()


## Shows the health, weapons and skill of this player from now on.
func bind_player(player: Player) -> void:
	_player = player
	player.health.hp_changed.connect(_on_hp_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	_on_hp_changed(player.health.hp, player.health.max_hp)
	_refresh_weapons()
	var skill_texture: Texture2D = player.skill.data.icon if player.skill != null else null
	if skill_icon != null:
		skill_icon.texture = skill_texture
	if skill_button_icon != null:
		skill_button_icon.texture = skill_texture


## Darkens the screen; await it before swapping the section.
func fade_out() -> void:
	await _fade_to(1.0)


func fade_in() -> void:
	await _fade_to(0.0)


func _fade_to(alpha: float) -> void:
	if fade == null:
		return
	var tween: Tween = create_tween()
	tween.tween_property(fade, "color:a", alpha, fade_time)
	await tween.finished


func _refresh_weapons() -> void:
	var slots: Array[WeaponData] = _player.get_weapon_slots()
	var active: int = _player.get_active_slot()
	for i in weapon_icons.size():
		weapon_icons[i].texture = slots[i].icon if i < slots.size() else null
		weapon_icons[i].modulate = Color.WHITE if i == active else inactive_slot_color
	if attack_button_icon != null:
		attack_button_icon.texture = slots[active].icon if active < slots.size() else null
	if swap_button_icon != null:
		# The swap button shows what the player would switch to.
		var other: int = (active + 1) % maxi(slots.size(), 1)
		swap_button_icon.texture = slots[other].icon if slots.size() > 1 else null


func _on_weapon_changed(_slot: int, _data: WeaponData) -> void:
	_refresh_weapons()


func _on_hp_changed(hp: int, max_hp: int) -> void:
	if hp_bar != null:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	if hp_label != null:
		hp_label.text = "%d / %d" % [hp, max_hp]


func _on_coins_changed(coins: int) -> void:
	if coins_label != null:
		coins_label.text = str(coins)


func _on_section_changed(section_index: int, depth: int) -> void:
	if depth_label != null:
		depth_label.text = "Depth %d  -  Section %d" % [depth + 1, section_index + 1]
