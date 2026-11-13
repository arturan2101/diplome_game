class_name WhirlwindSpell
extends Spell
## A ring of wind around the caster for a few seconds: every tick it hurts the
## enemies inside and pushes them out (AreaDamage). The spell node is a child of the
## caster, so the wind moves with it. The first tick comes at once.

## Placeholder look: how fast the wind lines turn, radians per second.
@export var spin_speed: float = 9.0
@export var wind_lines: int = 3

var _active_left: float = 0.0
var _tick_left: float = 0.0
var _spin: float = 0.0


func is_active() -> bool:
	return _active_left > 0.0


func cancel() -> void:
	_active_left = 0.0
	queue_redraw()


func _cast(_direction: Vector2) -> void:
	var stats: WhirlwindData = data as WhirlwindData
	if stats == null:
		return
	_active_left = SpellData.float_at(stats.duration, level)
	_tick_left = 0.0


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_active():
		return
	var stats: WhirlwindData = data as WhirlwindData
	_active_left -= delta
	_spin += spin_speed * delta
	_tick_left -= delta
	if _tick_left <= 0.0:
		_tick_left += stats.tick_interval
		_report_damage(AreaDamage.hit(get_world_2d().direct_space_state, caster.global_position,
				_radius(), SpellData.int_at(stats.damage, level), caster, stats.id, stats.knockback,
				target_mask, wall_mask))
	queue_redraw()


func _radius() -> float:
	return SpellData.float_at((data as WhirlwindData).radius, level)


func _draw() -> void:
	if not is_active():
		return
	var radius: float = _radius()
	draw_circle(Vector2.ZERO, radius, Color(data.color, 0.15))
	for i in wind_lines:
		var start: float = _spin + TAU * i / wind_lines
		draw_arc(Vector2.ZERO, radius * 0.85, start, start + PI * 0.5, 12, Color(data.color, 0.7), 2.0)
