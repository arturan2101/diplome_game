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
## Where extra spell slots go (a permanent skill): the icon next to the last one, the
## touch button here.
@export var extra_spell_icon_step: Vector2 = Vector2(28.0, 0.0)
@export var extra_spell_button_positions: Array[Vector2] = [Vector2(444.0, 200.0)]
## Gold marks of the spell level under each spell icon: a strip with one mark picture
## per level (art). Without it the level is written as a number.
@export var level_pips: Texture2D = preload("res://assets/art/fx/level_pips.png")
@export var level_pip_size: Vector2 = Vector2(16.0, 4.0)
@export var level_pip_gap: float = 1.0
## Icon of the ruin shards counter.
@export var shard_icon: Texture2D = preload("res://assets/sprites/shard.tres")
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
## Level marks under the spell icons, in slot order (empty without level_pips).
var _spell_pips: Array[TextureRect] = []
## Ruin shards owned (progress between runs on): icon and number under the coins.
var _shards_label: Label = null


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
	_make_spell_pips()
	_make_shard_counter()


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
		player.spell_book.spell_fused.connect(_on_spell_fused)
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
	_ensure_spell_slots()
	for slot in _slot_count():
		var spell: Spell = _spell_in(slot)
		if slot < spell_icons.size():
			spell_icons[slot].texture = spell.data.icon if spell != null else null
			spell_icons[slot].visible = spell != null
		if slot < spell_levels.size():
			spell_levels[slot].text = str(spell.level) if spell != null and _spell_pips.is_empty() else ""
		if slot < _spell_pips.size():
			_spell_pips[slot].visible = spell != null
			if spell != null:
				(_spell_pips[slot].texture as AtlasTexture).region = Rect2(
						Vector2(level_pip_size.x * (spell.level - 1), 0.0), level_pip_size)
		if slot < spell_buttons.size():
			spell_buttons[slot].visible = spell != null
		if slot < spell_button_icons.size():
			spell_button_icons[slot].texture = spell.data.icon if spell != null else null


func _update_spell_cooldowns() -> void:
	for slot in _slot_count():
		var spell: Spell = _spell_in(slot)
		if spell == null:
			continue
		if slot < spell_cooldowns.size():
			spell_cooldowns[slot].anchor_top = 1.0 - spell.get_cooldown_fraction()
		if slot < spell_button_icons.size():
			spell_button_icons[slot].modulate.a = 1.0 if spell.is_ready() else cooling_spell_alpha


func _slot_count() -> int:
	if not is_instance_valid(_player) or _player.spell_book == null:
		return SpellBook.SLOT_COUNT
	return _player.spell_book.slot_count


## Extra spell slots (the camp's skill) get their own icon and touch button: copies of
## the last ones, moved aside.
func _ensure_spell_slots() -> void:
	while spell_icons.size() < _slot_count() and not spell_icons.is_empty() and not spell_buttons.is_empty():
		var index: int = spell_icons.size()
		var last_icon: TextureRect = spell_icons[spell_icons.size() - 1]
		var icon: TextureRect = last_icon.duplicate() as TextureRect
		icon.name = "Spell%d" % (index + 1)
		icon.position = last_icon.position + extra_spell_icon_step
		last_icon.get_parent().add_child(icon)
		spell_icons.append(icon)
		spell_cooldowns.append(icon.get_node("Cooldown") as Control)
		spell_levels.append(icon.get_node("Level") as Label)
		var pips: TextureRect = icon.get_node_or_null("LevelPips") as TextureRect
		if pips != null and pips.texture != null:
			# Its own strip region, not the copied slot's.
			pips.texture = pips.texture.duplicate() as Texture2D
			_spell_pips.append(pips)
		var last_button: TouchScreenButton = spell_buttons[spell_buttons.size() - 1]
		var button: TouchScreenButton = last_button.duplicate() as TouchScreenButton
		button.name = "Spell%dButton" % (index + 1)
		button.action = SpellBook.SLOT_ACTIONS[mini(index, SpellBook.SLOT_ACTIONS.size() - 1)]
		var extra: int = index - SpellBook.SLOT_COUNT
		if extra >= 0 and extra < extra_spell_button_positions.size():
			button.position = extra_spell_button_positions[extra]
		last_button.get_parent().add_child(button)
		spell_buttons.append(button)
		spell_button_icons.append(button.get_node("Icon") as Sprite2D)


func _spell_in(slot: int) -> Spell:
	if not is_instance_valid(_player) or _player.spell_book == null:
		return null
	return _player.spell_book.get_spell(slot)


func _on_spell_learned(spell_data: SpellData, level: int) -> void:
	if level <= 1:
		show_banner("%s learned" % spell_data.display_name)
	else:
		show_banner("%s: level %d" % [spell_data.display_name, level])


func _on_spell_fused(recipe: FusionRecipe) -> void:
	show_banner("%s + %s = %s" % [recipe.first.display_name, recipe.second.display_name, recipe.result.display_name])


## The level marks of a spell slot (for tests), or null.
func get_spell_pips(slot: int) -> TextureRect:
	return _spell_pips[slot] if slot < _spell_pips.size() else null


## A strip of level marks under every spell icon; the region shows the level.
func _make_spell_pips() -> void:
	if level_pips == null:
		return
	for icon: TextureRect in spell_icons:
		var pips: TextureRect = TextureRect.new()
		pips.name = "LevelPips"
		pips.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var strip: AtlasTexture = AtlasTexture.new()
		strip.atlas = level_pips
		strip.region = Rect2(Vector2.ZERO, level_pip_size)
		pips.texture = strip
		pips.position = Vector2((icon.size.x - level_pip_size.x) * 0.5, icon.size.y + level_pip_gap)
		pips.size = level_pip_size
		pips.visible = false
		icon.add_child(pips)
		_spell_pips.append(pips)


## A shard icon and count under the coins, only with the progress between runs on.
func _make_shard_counter() -> void:
	if not GameManager.config.meta_progression or coins_label == null:
		return
	var icon: TextureRect = TextureRect.new()
	icon.name = "ShardIcon"
	icon.texture = shard_icon
	icon.modulate = Color(0.75, 0.9, 1.2)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	icon.position = coins_label.position + Vector2(-20.0, coins_label.size.y + 2.0)
	icon.size = Vector2(16.0, 16.0)
	coins_label.get_parent().add_child(icon)
	_shards_label = Label.new()
	_shards_label.name = "ShardsLabel"
	_shards_label.position = coins_label.position + Vector2(0.0, coins_label.size.y + 2.0)
	_shards_label.add_theme_font_size_override("font_size", coins_label.get_theme_font_size("font_size"))
	coins_label.get_parent().add_child(_shards_label)
	Progress.shards_changed.connect(_on_shards_changed)
	_on_shards_changed(Progress.shards)


func _on_shards_changed(shards: int) -> void:
	if _shards_label != null:
		_shards_label.text = str(shards)


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
	show_section(section_index, depth)


## "Depth 2  -  Section 4" in the top line.
func show_section(section_index: int, depth: int) -> void:
	if depth_label != null:
		depth_label.text = "Depth %d  -  Section %d" % [depth + 1, section_index + 1]


## "Camp" while the player is in the camp between runs.
func show_camp() -> void:
	if depth_label != null:
		depth_label.text = "Camp"


## "Depth 2  -  Glade" while the player is on the merchant's glade (not a section).
func show_glade(depth: int) -> void:
	if depth_label != null:
		depth_label.text = "Depth %d  -  Glade" % (depth + 1)
