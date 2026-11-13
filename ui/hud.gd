class_name Hud
extends CanvasLayer
## Heads-up display of a run: health, weapon slots, skill cooldown, coins, depth,
## icons on the touch buttons, and a black fade used between sections. Every button
## here is a TouchScreenButton that presses an Input Map action (attack, swap_weapon,
## skill, pause), so several fingers can use them at the same time.
## Reads GameManager through its signals and the player through its nodes.

@export var hp_bar: ProgressBar
@export var hp_label: Label
@export var coins_label: Label
@export var depth_label: Label
## One icon per weapon slot, in slot order.
@export var weapon_icons: Array[TextureRect] = []
@export var skill_icon: TextureRect
## Dark overlay on the skill icon; its height shows the cooldown left.
@export var skill_cooldown: Control
## Icons drawn on the touch buttons.
@export var attack_button_icon: Sprite2D
@export var swap_button_icon: Sprite2D
@export var skill_button_icon: Sprite2D
## Spell slots, in slot order: icons in the top panel (with a cooldown overlay and the
## spell level) and the touch buttons with their icons. Empty slots are hidden.
@export var spell_icons: Array[TextureRect] = []
@export var spell_cooldowns: Array[Control] = []
@export var spell_levels: Array[Label] = []
@export var spell_buttons: Array[TouchScreenButton] = []
@export var spell_button_icons: Array[Sprite2D] = []
## Alpha of a spell button's icon while the spell cools down.
@export var cooling_spell_alpha: float = 0.35
## Hint above the Take button ("Take Rare Bow", the name in the rarity colour) and the
## button itself; both appear only while there is something to take.
@export var interact_prompt: RichTextLabel
@export var interact_button: TouchScreenButton
## Health bar of the boss with its name, shown during the boss fight.
@export var boss_bar: ProgressBar
@export var boss_label: Label
## Text over the screen for a moment (the arena locking, the gate opening).
@export var banner: Label
@export var banner_time: float = 1.6
## Full-screen rectangle faded in and out between sections.
@export var fade: ColorRect
## Seconds one fade takes.
@export var fade_time: float = 0.25
## Tint of the weapon slot that is not in hand.
@export var inactive_slot_color: Color = Color(1.0, 1.0, 1.0, 0.35)
## Bar under each weapon slot in the colour of the weapon's rarity: height and gap, pixels.
@export var rarity_bar_height: float = 2.0
@export var rarity_bar_gap: float = 1.0

var _player: Player = null
## One rarity bar per weapon icon, same order.
var _rarity_bars: Array[ColorRect] = []


func _ready() -> void:
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.section_changed.connect(_on_section_changed)
	_on_coins_changed(GameManager.coins)
	_on_section_changed(GameManager.section_index, GameManager.depth)
	if fade != null:
		fade.color.a = 0.0
	_on_interaction_changed(null)
	if banner != null:
		banner.visible = false
	if boss_bar != null:
		boss_bar.visible = false
	_make_rarity_bars()


func _process(_delta: float) -> void:
	if not is_instance_valid(_player):
		return
	if skill_cooldown != null and _player.skill != null:
		# The overlay covers the bottom part of the icon in proportion to the cooldown left.
		skill_cooldown.anchor_top = 1.0 - _player.skill.get_cooldown_fraction()
	_update_spell_cooldowns()


## Shows the health, weapons and skill of this player from now on.
func bind_player(player: Player) -> void:
	_player = player
	player.health.hp_changed.connect(_on_hp_changed)
	player.weapon_changed.connect(_on_weapon_changed)
	player.interaction_changed.connect(_on_interaction_changed)
	_on_hp_changed(player.health.hp, player.health.max_hp)
	_refresh_weapons()
	var skill_texture: Texture2D = player.skill.data.icon if player.skill != null else null
	if skill_icon != null:
		skill_icon.texture = skill_texture
	if skill_button_icon != null:
		skill_button_icon.texture = skill_texture
	if player.spell_book != null:
		player.spell_book.spells_changed.connect(_refresh_spells)
		player.spell_book.spell_learned.connect(_on_spell_learned)
	_refresh_spells()


## Shows the boss's health bar until hide_boss() (or until the boss is gone).
func show_boss(boss: Enemy) -> void:
	if boss_bar == null:
		return
	if boss_label != null:
		boss_label.text = boss.data.display_name
	boss_bar.max_value = boss.health.max_hp
	boss_bar.value = boss.health.hp
	boss_bar.visible = true
	if not boss.health.hp_changed.is_connected(_on_boss_hp_changed):
		boss.health.hp_changed.connect(_on_boss_hp_changed)
	if not boss.tree_exited.is_connected(hide_boss):
		boss.tree_exited.connect(hide_boss)


func hide_boss() -> void:
	if boss_bar != null:
		boss_bar.visible = false


func _on_boss_hp_changed(hp: int, max_hp: int) -> void:
	boss_bar.max_value = max_hp
	boss_bar.value = hp


## Shows a short message in the middle of the screen.
func show_banner(text: String) -> void:
	if banner == null:
		return
	banner.text = text
	banner.visible = true
	banner.modulate.a = 1.0
	var tween: Tween = create_tween()
	tween.tween_interval(banner_time)
	tween.tween_property(banner, "modulate:a", 0.0, fade_time)
	tween.tween_callback(banner.hide)


func _on_interaction_changed(target: Interactable) -> void:
	if interact_prompt != null:
		interact_prompt.visible = target != null
		if target != null:
			# [lb] and [rb] are BBCode for literal brackets.
			interact_prompt.text = "%s  [lb]E[rb]" % target.get_prompt()
	if interact_button != null:
		interact_button.visible = target != null


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
		if i < _rarity_bars.size():
			_rarity_bars[i].visible = i < slots.size()
			if i < slots.size():
				_rarity_bars[i].color = slots[i].get_rarity().color
	if attack_button_icon != null:
		attack_button_icon.texture = slots[active].icon if active < slots.size() else null
	if swap_button_icon != null:
		# The swap button shows what the player would switch to.
		var other: int = (active + 1) % maxi(slots.size(), 1)
		swap_button_icon.texture = slots[other].icon if slots.size() > 1 else null


## A thin bar under every weapon icon; children of the icon, so the slot that is not in
## hand dims it too.
func _make_rarity_bars() -> void:
	for icon: TextureRect in weapon_icons:
		var bar: ColorRect = ColorRect.new()
		bar.name = "RarityBar"
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar.position = Vector2(0.0, icon.size.y + rarity_bar_gap)
		bar.size = Vector2(icon.size.x, rarity_bar_height)
		bar.visible = false
		icon.add_child(bar)
		_rarity_bars.append(bar)


## Icons, levels and buttons of the spell slots; empty slots are hidden.
func _refresh_spells() -> void:
	for slot in SpellBook.SLOT_COUNT:
		var spell: Spell = _spell_in(slot)
		if slot < spell_icons.size():
			spell_icons[slot].texture = spell.data.icon if spell != null else null
			spell_icons[slot].visible = spell != null
		if slot < spell_levels.size():
			spell_levels[slot].text = str(spell.level) if spell != null else ""
		if slot < spell_buttons.size():
			spell_buttons[slot].visible = spell != null
		if slot < spell_button_icons.size():
			spell_button_icons[slot].texture = spell.data.icon if spell != null else null


func _update_spell_cooldowns() -> void:
	for slot in SpellBook.SLOT_COUNT:
		var spell: Spell = _spell_in(slot)
		if spell == null:
			continue
		if slot < spell_cooldowns.size():
			spell_cooldowns[slot].anchor_top = 1.0 - spell.get_cooldown_fraction()
		if slot < spell_button_icons.size():
			spell_button_icons[slot].modulate.a = 1.0 if spell.is_ready() else cooling_spell_alpha


func _spell_in(slot: int) -> Spell:
	if not is_instance_valid(_player) or _player.spell_book == null:
		return null
	return _player.spell_book.get_spell(slot)


func _on_spell_learned(spell_data: SpellData, level: int) -> void:
	if level <= 1:
		show_banner("%s learned" % spell_data.display_name)
	else:
		show_banner("%s: level %d" % [spell_data.display_name, level])


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
