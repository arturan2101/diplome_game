class_name BowWeapon
extends Weapon
## Bow: hold the attack button to draw, release to shoot an arrow.
## A release before tap_threshold is a quick weak shot (min_damage, no slowdown).
## After the threshold the bow draws: damage grows from min_damage to max_damage over
## draw_time and the wielder slows down to draw_move_speed_multiplier.

## Colour of the draw indicator while drawing and when fully drawn.
@export var indicator_color: Color = Color(1.0, 1.0, 1.0, 0.6)
@export var indicator_full_color: Color = Color(1.0, 0.85, 0.3, 0.9)
## Radius of the draw indicator around the wielder, in pixels.
@export var indicator_radius: float = 10.0

var _stats: BowWeaponData = null
var _is_holding: bool = false
## Seconds the button has been held after the cooldown ended.
var _hold_time: float = 0.0
var _cooldown_left: float = 0.0


func setup(weapon_data: WeaponData, weapon_wielder: Node2D) -> void:
	super(weapon_data, weapon_wielder)
	_stats = weapon_data as BowWeaponData
	if _stats == null or _stats.arrow_scene == null:
		push_error("BowWeapon needs BowWeaponData with an arrow_scene: %s" % weapon_data)
		_stats = null


## Drops the draw without shooting, so the slowdown ends at once.
## Arrows already in flight keep flying; the cooldown keeps running.
func cancel_attack() -> void:
	_is_holding = false
	_hold_time = 0.0
	queue_redraw()


func _on_attack_pressed(_direction: Vector2) -> void:
	if _stats == null:
		return
	_is_holding = true
	_hold_time = 0.0


func _on_attack_released(direction: Vector2) -> void:
	if not _is_holding:
		return
	var hold: float = _hold_time
	_is_holding = false
	_hold_time = 0.0
	queue_redraw()
	# Released during the cooldown or without a direction: no shot.
	if _cooldown_left > 0.0 or direction.is_zero_approx():
		return
	_shoot(direction, _damage_for_hold(hold))
	_cooldown_left = _stats.cooldown


func get_move_speed_multiplier() -> float:
	if _stats == null:
		return 1.0
	return lerpf(1.0, _stats.draw_move_speed_multiplier, get_draw_progress())


## 0 when not drawing or still within the tap threshold, then grows to 1 over draw_time.
func get_draw_progress() -> float:
	if _stats == null or not _is_holding:
		return 0.0
	return _draw_progress_for(_hold_time)


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _is_holding and _cooldown_left <= 0.0:
		_hold_time += delta
		queue_redraw()


func _draw() -> void:
	var progress: float = get_draw_progress()
	if progress <= 0.0:
		return
	var color: Color = indicator_full_color if progress >= 1.0 else indicator_color
	draw_arc(Vector2.ZERO, indicator_radius, -PI / 2.0, -PI / 2.0 + TAU * progress, 24, color, 2.0)


func _draw_progress_for(hold: float) -> float:
	if hold < _stats.tap_threshold:
		return 0.0
	if _stats.draw_time <= 0.0:
		return 1.0
	return clampf((hold - _stats.tap_threshold) / _stats.draw_time, 0.0, 1.0)


func _damage_for_hold(hold: float) -> int:
	return roundi(lerpf(_stats.min_damage, _stats.max_damage, _draw_progress_for(hold)))


func _shoot(direction: Vector2, damage: int) -> void:
	var arrow: Arrow = _stats.arrow_scene.instantiate() as Arrow
	arrow.setup(DamageInfo.new(damage, wielder, data.id), direction, _stats.arrow_speed, _stats.arrow_range)
	# The arrow only emits a signal and knows nothing about the bow. If the bow is freed
	# while the arrow flies, Godot drops this connection and the arrow still works.
	arrow.landed.connect(_on_arrow_landed)
	_projectile_parent().add_child(arrow)
	arrow.global_position = global_position


## Arrows live in the level, not in the wielder, so they do not move with the player.
func _projectile_parent() -> Node:
	var scene: Node = get_tree().current_scene
	return scene if scene != null else get_tree().root


func _on_arrow_landed(hit: bool) -> void:
	attack_performed.emit(0, 1 if hit else 0)
