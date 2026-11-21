class_name WaveSpell
extends Spell
## Water's wave (stage 40): one hit on every enemy in an arc in front of the caster
## (AreaDamage with an arc). The water form pushes and wets; the ice form (top level)
## freezes. The look is the level's animation (water_l1-2, ice_burst_l3) turned to the
## aim; without art an arc is drawn for a moment instead.

## Segments of the placeholder arc.
const ARC_SEGMENTS: int = 12

var _look_left: float = 0.0
var _direction: Vector2 = Vector2.RIGHT
## The level's art (water, or the ice burst at the top level), created when first needed.
var _look: AnimatedSprite2D = null


func _cast(direction: Vector2) -> void:
	var stats: WaveData = data as WaveData
	if stats == null:
		return
	_direction = direction
	var ice: bool = stats.is_ice(level)
	_report_damage(AreaDamage.hit(get_world_2d().direct_space_state, caster.global_position,
			SpellData.float_at(stats.reach, level), SpellData.int_at(stats.damage, level), caster, stats.id,
			0.0 if ice else stats.knockback, target_mask, wall_mask, _on_hit.bind(ice), direction, stats.arc_degrees))
	_look_left = stats.look_time
	_show_look(stats, direction)
	queue_redraw()


## The art of the level, pivoted on the caster, turned to the aim, scaled to the reach.
func _show_look(stats: WaveData, direction: Vector2) -> void:
	var animation: StringName = stats.animation_at(level)
	if animation == &"":
		return
	if _look == null:
		_look = AnimatedSprite2D.new()
		_look.name = "Look"
		_look.sprite_frames = stats.frames
		_look.animation_finished.connect(_look.hide)
		add_child(_look)
	var size: Vector2 = SpellData.frame_size(stats.frames, animation)
	_look.offset = size * 0.5 - stats.look_pivot
	_look.rotation = direction.angle()
	_look.scale = Vector2.ONE * (SpellData.float_at(stats.reach, level) / maxf(stats.look_reach, 1.0))
	_look.visible = true
	_look.play(animation)


## The art of the last cast, or null (no art, or not cast yet).
func get_look() -> AnimatedSprite2D:
	return _look


func _on_hit(hurtbox: Hurtbox, ice: bool) -> void:
	var stats: WaveData = data as WaveData
	var enemy: Enemy = Enemy.owner_of(hurtbox)
	if enemy == null or not is_instance_valid(enemy):
		return
	if ice:
		enemy.freeze(stats.freeze_time)
	else:
		enemy.make_wet(stats.wet_time)


func _physics_process(delta: float) -> void:
	super(delta)
	if _look_left > 0.0:
		_look_left -= delta
		queue_redraw()


func _draw() -> void:
	if _look_left <= 0.0 or _look != null:
		return
	var stats: WaveData = data as WaveData
	var t: float = 1.0 - _look_left / maxf(stats.look_time, 0.001)
	var reach: float = SpellData.float_at(stats.reach, level) * (0.4 + 0.6 * t)
	var half: float = deg_to_rad(stats.arc_degrees) * 0.5
	var start: float = _direction.angle() - half
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i in ARC_SEGMENTS + 1:
		points.append(Vector2.from_angle(start + 2.0 * half * i / ARC_SEGMENTS) * reach)
	var color: Color = stats.ice_color if stats.is_ice(level) else stats.color
	draw_colored_polygon(points, Color(color, 0.45 * (1.0 - t)))
