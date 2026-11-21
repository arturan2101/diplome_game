class_name WhirlwindSpell
extends Spell
## A ring of wind around the caster for a few seconds: every tick it hurts the
## enemies inside and pushes them out (AreaDamage). The spell node is a child of the
## caster, so the wind moves with it. The first tick comes at once.
## The look is the level's animation of the spell, stretched to the radius; without
## one a placeholder is drawn. The sandstorm (a fused spell) uses this script too; its
## ticks also slow the enemies they hit.

## Placeholder look: how fast the wind lines turn, radians per second.
@export var spin_speed: float = 9.0
@export var wind_lines: int = 3

var _active_left: float = 0.0
var _tick_left: float = 0.0
var _spin: float = 0.0
## Art of the ring (created at the first cast when the spell has a look).
var _look: AnimatedSprite2D = null


func is_active() -> bool:
	return _active_left > 0.0


func cancel() -> void:
	_active_left = 0.0
	_hide_look()
	queue_redraw()


## The art of the ring, or null (no look, or not cast yet).
func get_look() -> AnimatedSprite2D:
	return _look


func _cast(_direction: Vector2) -> void:
	var stats: WhirlwindData = data as WhirlwindData
	if stats == null:
		return
	_active_left = SpellData.float_at(stats.duration, level)
	_tick_left = 0.0
	_show_look()


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
		var on_hit: Callable = _on_hit if stats.has_status() else Callable()
		_report_damage(AreaDamage.hit(get_world_2d().direct_space_state, caster.global_position,
				_radius(), SpellData.int_at(stats.damage, level), caster, stats.id, stats.knockback,
				target_mask, wall_mask, on_hit))
	if not is_active():
		_hide_look()
	queue_redraw()


## The enemy whose hurtbox took the tick freezes or slows down (the sandstorm).
func _on_hit(hurtbox: Hurtbox) -> void:
	var stats: WhirlwindData = data as WhirlwindData
	var enemy: Enemy = Enemy.owner_of(hurtbox)
	if enemy == null or not is_instance_valid(enemy):
		return
	var freeze: float = SpellData.float_at(stats.freeze_time, level)
	if freeze > 0.0:
		enemy.freeze(freeze)
	if stats.slow_time > 0.0:
		enemy.slow(stats.slow_multiplier, stats.slow_time)


## Starts the level's animation, stretched so the ring's art covers the radius.
func _show_look() -> void:
	var animation: StringName = data.animation_at(level)
	if animation == &"":
		return
	if _look == null:
		_look = AnimatedSprite2D.new()
		_look.name = "Look"
		_look.sprite_frames = data.frames
		add_child(_look)
	var size: Vector2 = SpellData.frame_size(data.frames, animation)
	_look.scale = Vector2.ONE * (_radius() * 2.0 / maxf(size.x, 1.0))
	_look.visible = true
	_look.play(animation)


func _hide_look() -> void:
	if _look != null and _look.visible:
		_look.visible = false
		_look.stop()


func _radius() -> float:
	return SpellData.float_at((data as WhirlwindData).radius, level)


func _draw() -> void:
	if not is_active() or _look != null:
		return
	var radius: float = _radius()
	draw_circle(Vector2.ZERO, radius, Color(data.color, 0.15))
	for i in wind_lines:
		var start: float = _spin + TAU * i / wind_lines
		draw_arc(Vector2.ZERO, radius * 0.85, start, start + PI * 0.5, 12, Color(data.color, 0.7), 2.0)
