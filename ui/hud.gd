class_name Hud
extends CanvasLayer
## Heads-up display of a run: health, coins, depth, and a black fade used between
## sections. Reads GameManager through its signals and the player through Health.

@export var hp_bar: ProgressBar
@export var hp_label: Label
@export var coins_label: Label
@export var depth_label: Label
## Full-screen rectangle faded in and out between sections.
@export var fade: ColorRect
## Seconds one fade takes.
@export var fade_time: float = 0.25


func _ready() -> void:
	GameManager.coins_changed.connect(_on_coins_changed)
	GameManager.section_changed.connect(_on_section_changed)
	_on_coins_changed(GameManager.coins)
	_on_section_changed(GameManager.section_index, GameManager.depth)
	if fade != null:
		fade.color.a = 0.0


## Shows the health of this player from now on.
func bind_player(player: Player) -> void:
	player.health.hp_changed.connect(_on_hp_changed)
	_on_hp_changed(player.health.hp, player.health.max_hp)


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


func _on_hp_changed(hp: int, max_hp: int) -> void:
	if hp_bar != null:
		hp_bar.max_value = max_hp
		hp_bar.value = hp
	if hp_label != null:
		hp_label.text = "%d / %d" % [hp, max_hp]


func _on_coins_changed(coins: int) -> void:
	if coins_label != null:
		coins_label.text = "Coins: %d" % coins


func _on_section_changed(section_index: int, depth: int) -> void:
	if depth_label != null:
		depth_label.text = "Depth %d  -  Section %d" % [depth + 1, section_index + 1]
