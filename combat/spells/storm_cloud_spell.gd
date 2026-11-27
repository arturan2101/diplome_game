class_name StormCloudSpell
extends Spell
## The storm cloud (stage 40): see StormCloudData. The spell node is a child of the
## caster, so the cloud moves with it; the first bolt comes at once (if an enemy is in
## reach), then one every strike_interval, exactly strikes_at() times.

## Placeholder look of the cloud: an ellipse this size.
@export var cloud_size: Vector2 = Vector2(28.0, 10.0)

## The cloud's art, created at the first cast when the spell has one.
var _look: AnimatedSprite2D = null
var _strikes_left: int = 0
var _strike_left: float = 0.0
var _age: float = 0.0


func is_active() -> bool:
	return _strikes_left > 0


func cancel() -> void:
	_strikes_left = 0
	if _look != null:
		_look.visible = false
	queue_redraw()


func _cast(_direction: Vector2) -> void:
	var stats: StormCloudData = data as StormCloudData
	if stats == null:
		return
	_strikes_left = stats.strikes_at(level)
	_strike_left = 0.0
	if stats.frames != null and stats.frames.has_animation(stats.cloud_animation):
		if _look == null:
			_look = AnimatedSprite2D.new()
			_look.name = "Look"
			_look.sprite_frames = stats.frames
			add_child(_look)
		var size: Vector2 = SpellData.frame_size(stats.frames, stats.cloud_animation)
		_look.position = Vector2(0.0, -stats.cloud_height)
		_look.offset = size * 0.5 - stats.cloud_pivot
		_look.visible = true
		_look.play(stats.cloud_animation)


func _physics_process(delta: float) -> void:
	super(delta)
	if not is_active():
		return
	_age += delta
	_strike_left -= delta
	if _strike_left <= 0.0:
		_strike_left += (data as StormCloudData).strike_interval
		_strikes_left -= 1
		_strike()
	if not is_active() and _look != null:
		_look.visible = false
	queue_redraw()


func _strike() -> void:
	var stats: StormCloudData = data as StormCloudData
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var target: Hurtbox = LightningSpell.nearest_target(space, caster.global_position, stats.radius, target_mask,
			wall_mask, [] as Array[Hurtbox])
	if target == null:
		return
	var cloud: Vector2 = caster.global_position + Vector2(0.0, -stats.cloud_height)
	_report_damage(LightningSpell.strike(target, spell_damage(stats.strike_damage), stats.wet_multiplier,
			caster, stats.id, cloud))
	LightningBolt.spawn(_effect_parent(), PackedVector2Array([cloud, target.global_position]), stats.color, stats.bolt_time,
			stats.frames, stats.bolt_animation, stats.hit_animation)


func _draw() -> void:
	if not is_active() or _look != null:
		return
	var stats: StormCloudData = data as StormCloudData
	var center: Vector2 = Vector2(0.0, -stats.cloud_height + sin(_age * 3.0))
	for i in 3:
		var offset: Vector2 = Vector2((i - 1) * cloud_size.x * 0.3, (i % 2) * -2.0)
		draw_circle(center + offset, cloud_size.y * 0.8, Color(0.35, 0.38, 0.45, 0.85))
	draw_circle(center, cloud_size.y * 0.5, Color(stats.color, 0.5))
