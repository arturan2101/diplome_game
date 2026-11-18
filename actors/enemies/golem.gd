class_name Golem
extends Enemy
## Stone golem (stage 29): slow and tough, hits do not push it back. Its only attack is a
## slam of the ground around itself after a long windup; the area is shown on the floor
## as a circle that fills up during the windup, so a careful player steps out in time.
## Damage goes out with the golem's id as its source, like any enemy's.

@export_flags_2d_physics var player_hurtbox_mask: int = 8
## The slam's warning circle: colour, fill alpha at the end of the windup, smoothness.
@export var telegraph_color: Color = Color(1.0, 0.45, 0.2)
@export var telegraph_alpha: float = 0.35
@export var telegraph_segments: int = 32
@export var dust_color: Color = Color(0.85, 0.83, 0.77)

var _stats: GolemData = null
var _flash_left: float = 0.0


func _ready() -> void:
	super()
	_stats = data as GolemData
	if _stats == null:
		push_error("Golem needs GolemData: %s" % data)
		set_physics_process(false)


func _physics_process(delta: float) -> void:
	super(delta)
	if _flash_left > 0.0:
		_flash_left -= delta
	if state == State.WINDUP or _flash_left > -delta:
		queue_redraw()


## The bot (and anyone asking) must leave the whole circle.
func get_windup_reach() -> float:
	return _stats.slam_radius if _stats != null else super()


func is_windup_area() -> bool:
	return true


## 0 at the start of the windup, 1 when the slam comes.
func get_windup_progress() -> float:
	if state != State.WINDUP or data.windup <= 0.0:
		return 0.0
	return clampf(1.0 - _state_time_left / data.windup, 0.0, 1.0)


func apply_knockback(knockback_velocity: Vector2) -> void:
	if _stats != null and _stats.stagger_immune:
		return
	super(knockback_velocity)


## No weapon: the slam is the golem's own.
func _create_weapon() -> void:
	pass


func _update_windup(delta: float) -> void:
	_state_time_left -= delta
	if _state_time_left > 0.0:
		return
	AreaDamage.hit(get_world_2d().direct_space_state, global_position, _stats.slam_radius,
			roundi(_stats.slam_damage * damage_multiplier), self, data.id, _stats.slam_knockback,
			player_hurtbox_mask, sight_mask)
	_flash_left = _stats.slam_flash_time
	_enter(State.RECOVER)


func _draw() -> void:
	if _stats == null:
		return
	if state == State.WINDUP:
		var progress: float = get_windup_progress()
		draw_circle(Vector2.ZERO, _stats.slam_radius * progress, Color(telegraph_color, telegraph_alpha * (0.3 + 0.7 * progress)))
		draw_arc(Vector2.ZERO, _stats.slam_radius, 0.0, TAU, telegraph_segments, Color(telegraph_color, 0.9), 1.5)
	elif _flash_left > 0.0:
		var t: float = 1.0 - _flash_left / _stats.slam_flash_time
		draw_arc(Vector2.ZERO, _stats.slam_radius * (0.6 + 0.4 * t), 0.0, TAU, telegraph_segments,
				Color(dust_color, 0.8 * (1.0 - t)), 3.0)
