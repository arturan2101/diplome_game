class_name TrainingDummy
extends CharacterBody2D
## Target for testing weapons: flashes when hit, prints the hit, restores itself after "death".
## A CharacterBody2D so that knockback can move it later.

@export var health: Health
## Visual node tinted on hit (the PlaceholderShape for now).
@export var visual: CanvasItem
@export var hit_color: Color = Color(1.0, 0.3, 0.3)
@export var defeated_color: Color = Color(1.0, 1.0, 1.0, 0.3)
## Seconds for the hit tint to fade.
@export var flash_duration: float = 0.15
## Seconds before a defeated dummy restores its health.
@export var restore_delay: float = 1.0

var _flash_tween: Tween = null


func _ready() -> void:
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)


func _on_damaged(info: DamageInfo) -> void:
	print("%s: %d damage from %s, hp %d/%d" % [name, info.amount, info.source_id, health.hp, health.max_hp])
	_stop_flash()
	visual.modulate = hit_color
	_flash_tween = create_tween()
	_flash_tween.tween_property(visual, "modulate", Color.WHITE, flash_duration)


func _on_died(_info: DamageInfo) -> void:
	_stop_flash()
	visual.modulate = defeated_color
	await get_tree().create_timer(restore_delay).timeout
	health.reset()
	visual.modulate = Color.WHITE
	print("%s: restored" % name)


func _stop_flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
