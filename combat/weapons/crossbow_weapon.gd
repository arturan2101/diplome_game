class_name CrossbowWeapon
extends Weapon
## Crossbow (stage 39): a press shoots a bolt at once if the crossbow is loaded; then
## it reloads. While the button is held it shoots again as soon as it is loaded, aimed
## where the wielder looks at that moment. A ring around the wielder shows the reload.

## Colour and radius of the reload ring.
@export var indicator_color: Color = Color(1.0, 1.0, 1.0, 0.45)
@export var indicator_radius: float = 10.0

var _stats: CrossbowWeaponData = null
var _is_holding: bool = false
var _aim: Vector2 = Vector2.RIGHT
var _reload_left: float = 0.0


func setup(weapon_data: WeaponData, weapon_wielder: Node2D, damage_source_id: StringName = &"") -> void:
	super(weapon_data, weapon_wielder, damage_source_id)
	_stats = weapon_data as CrossbowWeaponData
	if _stats == null or _stats.bolt_scene == null:
		push_error("CrossbowWeapon needs CrossbowWeaponData with a bolt_scene: %s" % weapon_data)
		_stats = null


func is_ranged() -> bool:
	return true


## Stops shooting on its own; the reload keeps running.
func cancel_attack() -> void:
	_is_holding = false


func is_loaded() -> bool:
	return _reload_left <= 0.0


## 0 = loaded, 1 = just shot. For the ring.
func get_reload_fraction() -> float:
	if _stats == null or _stats.reload_time <= 0.0:
		return 0.0
	return clampf(_reload_left * attack_speed_multiplier / _stats.reload_time, 0.0, 1.0)


func _on_attack_pressed(direction: Vector2) -> void:
	if _stats == null:
		return
	_is_holding = true
	if not direction.is_zero_approx():
		_aim = direction
	if is_loaded():
		_shoot()


func _on_attack_released(_direction: Vector2) -> void:
	_is_holding = false


func _physics_process(delta: float) -> void:
	if _reload_left > 0.0:
		_reload_left = maxf(_reload_left - delta, 0.0)
		if _reload_left <= 0.0 and is_active and _stats != null:
			Sound.play_at(_stats.reload_sound, global_position)
		queue_redraw()
	if _is_holding and is_active and is_loaded() and _stats != null:
		var player: Player = wielder as Player
		if player != null:
			_aim = player.get_look_direction()
		_shoot()


func _draw() -> void:
	var left: float = get_reload_fraction()
	if left <= 0.0:
		return
	draw_arc(Vector2.ZERO, indicator_radius, -PI / 2.0, -PI / 2.0 + TAU * (1.0 - left), 24, indicator_color, 2.0)


func _shoot() -> void:
	Sound.play_at(_stats.attack_sound, global_position)
	var bolt: Arrow = _stats.bolt_scene.instantiate() as Arrow
	bolt.pierce = _stats.pierce
	bolt.setup(make_hit(_stats.damage), _aim, _stats.bolt_speed, _stats.bolt_range)
	# As with the bow: the bolt only emits a signal and outlives the crossbow if need be.
	bolt.landed.connect(_on_bolt_landed)
	_projectile_parent().add_child(bolt)
	bolt.global_position = global_position
	_reload_left = _stats.reload_time / attack_speed_multiplier
	queue_redraw()


func _projectile_parent() -> Node:
	var scene: Node = get_tree().current_scene
	return scene if scene != null else get_tree().root


func _on_bolt_landed(hit: bool) -> void:
	attack_performed.emit(0, 1 if hit else 0)
