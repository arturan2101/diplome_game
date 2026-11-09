class_name TrainingDummy
extends CharacterBody2D
## Target for testing weapons: flashes when hit, prints the hit, slides from knockback,
## and restores itself at its start position after "death".

@export var health: Health
@export var hurtbox: Hurtbox
## Visual node tinted on hit (the PlaceholderShape for now).
@export var visual: CanvasItem
@export var hit_color: Color = Color(1.0, 0.3, 0.3)
@export var defeated_color: Color = Color(1.0, 1.0, 1.0, 0.3)
## Seconds for the hit tint to fade.
@export var flash_duration: float = 0.15
## Seconds before a defeated dummy restores its health.
@export var restore_delay: float = 1.0
## How quickly knockback speed fades, in pixels per second squared.
@export var knockback_friction: float = 600.0

var _flash_tween: Tween = null
var _start_position: Vector2 = Vector2.ZERO


func _ready() -> void:
	# Top-down game: no floor or gravity, every collision is treated as a wall.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	_start_position = position
	health.damaged.connect(_on_damaged)
	health.died.connect(_on_died)
	hurtbox.hit_received.connect(_on_hit_received)


func _physics_process(delta: float) -> void:
	if velocity.is_zero_approx():
		return
	velocity = velocity.move_toward(Vector2.ZERO, knockback_friction * delta)
	move_and_slide()


func _on_hit_received(info: DamageInfo) -> void:
	if not info.knockback.is_zero_approx():
		velocity = info.knockback


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
	velocity = Vector2.ZERO
	position = _start_position
	visual.modulate = Color.WHITE
	print("%s: restored" % name)


func _stop_flash() -> void:
	if _flash_tween != null:
		_flash_tween.kill()
