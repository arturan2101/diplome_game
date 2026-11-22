class_name SpellZone
extends Node2D
## One patch of a ZoneData spell on the floor (stage 40): optionally falls first and
## hits where it lands (the meteor), then hurts, roots or slows the enemies on it every
## tick until its time is up, then frees itself. Since stage 45 the bosses' patches use
## it too (target_mask = the player's hurtbox): it then slows the player, and a patch
## without tick damage only slows (the Tide Warden's puddle). Lives in the level, not on the caster.
## Look: the level's animation scaled to the patch (the meteor also falls as a rock over
## a growing shadow and ends in an impact burst); without art a circle in the spell's
## colour is drawn.

## Emitted after the impact and every tick with the damage dealt (for telemetry).
signal damage_dealt(amount: int)

## Seconds over which the patch fades out at its end.
const FADE_TIME: float = 0.3

var _stats: ZoneData = null
var _level: int = 1
var _caster: Node = null
var _source_id: StringName = &""
var _target_mask: int = 0
var _wall_mask: int = 0
var _fall_left: float = 0.0
var _time_left: float = 0.0
var _tick_left: float = 0.0
var _ticks_left: int = 0
var _age: float = 0.0
## Art: the patch, and the meteor's falling rock and shadow.
var _look: AnimatedSprite2D = null
var _rock: AnimatedSprite2D = null
var _shadow: AnimatedSprite2D = null


## A new patch at a world position, added to parent. source_id goes to the damage
## (the spell that made it, e.g. &"volcanic_lightning" for its small pools).
## delay: extra seconds before a falling patch lands (a boss's strikes one after another).
static func spawn(parent: Node, at: Vector2, stats: ZoneData, level: int, caster: Node, source_id: StringName,
		target_mask: int, wall_mask: int, delay: float = 0.0) -> SpellZone:
	var zone: SpellZone = SpellZone.new()
	zone._stats = stats
	zone._level = level
	zone._caster = caster
	zone._source_id = source_id
	zone._target_mask = target_mask
	zone._wall_mask = wall_mask
	zone._fall_left = stats.impact_delay + (delay if stats.impact_delay > 0.0 else 0.0)
	zone._time_left = SpellData.float_at(stats.duration, level)
	zone._ticks_left = stats.ticks_at(level)
	# Cleared between sections together with arrows and fireballs.
	zone.add_to_group(Arrow.GROUP)
	# A child of the level, after its tile layers: over the floor, under the actors.
	parent.add_child(zone)
	zone.global_position = at
	zone._make_look()
	return zone


func _make_look() -> void:
	var frames: SpriteFrames = _stats.frames
	if frames == null:
		return
	if is_falling():
		_shadow = _sprite(_stats.shadow_animation, Vector2.ZERO)
		if _shadow != null:
			# One pass of the shadow over the whole fall.
			var pass_time: float = float(frames.get_frame_count(_stats.shadow_animation)) / maxf(frames.get_animation_speed(_stats.shadow_animation), 1.0)
			_shadow.speed_scale = pass_time / maxf(_fall_left, 0.01)
			_shadow.scale = Vector2.ONE * (_stats.impact_radius * 2.0 / maxf(SpellData.frame_size(frames, _stats.shadow_animation).x, 1.0))
		_rock = _sprite(_stats.fall_animation, _stats.fall_pivot)
		if _rock != null:
			_rock.position = Vector2(0.0, -_stats.fall_height)
			_rock.z_index = 2
		return
	_show_patch()


## The patch's art, scaled from the art's radius to the patch's.
func _show_patch() -> void:
	var animation: StringName = _stats.animation_at(_level)
	if animation == &"" or _stats.look_radius.is_empty():
		return
	_look = _sprite(animation, Vector2.ZERO)
	_look.scale = Vector2.ONE * (radius() / maxf(SpellData.float_at(_stats.look_radius, _level), 1.0))


## An animation of the spell's frames playing on this patch, its pivot pixel on the
## patch's centre (zero = the frame's centre); null without that animation.
func _sprite(animation: StringName, pivot: Vector2) -> AnimatedSprite2D:
	if animation == &"" or _stats.frames == null or not _stats.frames.has_animation(animation):
		return null
	var sprite: AnimatedSprite2D = AnimatedSprite2D.new()
	sprite.sprite_frames = _stats.frames
	if pivot != Vector2.ZERO:
		sprite.offset = SpellData.frame_size(_stats.frames, animation) * 0.5 - pivot
	add_child(sprite)
	sprite.play(animation)
	return sprite


## The patch's art, or null.
func get_look() -> AnimatedSprite2D:
	return _look


func radius() -> float:
	return SpellData.float_at(_stats.radius, _level)


func is_falling() -> bool:
	return _fall_left > 0.0


func _physics_process(delta: float) -> void:
	_age += delta
	queue_redraw()
	if is_falling():
		_fall_left -= delta
		if _rock != null:
			_rock.position.y = -_stats.fall_height * clampf(_fall_left / maxf(_stats.impact_delay, 0.001), 0.0, 1.0)
		if not is_falling():
			_impact()
		return
	if _look != null:
		_look.modulate.a = clampf(_time_left / FADE_TIME, 0.0, 1.0)
	# Exactly ticks_at() ticks, the first at once; the patch goes when its time is up.
	_tick_left -= delta
	if _tick_left <= 0.0 and _ticks_left > 0:
		_tick_left += _stats.tick_interval
		_ticks_left -= 1
		_tick()
	_time_left -= delta
	if _time_left <= 0.0 and _ticks_left == 0:
		queue_free()
		set_physics_process(false)


func _impact() -> void:
	for falling: AnimatedSprite2D in [_rock, _shadow]:
		if falling != null:
			falling.queue_free()
	_rock = null
	_shadow = null
	if _stats.frames != null and _stats.frames.has_animation(_stats.impact_animation):
		var blast: EffectSprite = EffectSprite.spawn(get_parent(), global_position, _stats.frames, _stats.impact_animation)
		blast.offset = SpellData.frame_size(_stats.frames, _stats.impact_animation) * 0.5 - _stats.impact_pivot
		blast.z_index = 2
	_show_patch()
	var damage: int = SpellData.int_at(_stats.impact_damage, _level)
	if damage <= 0:
		return
	var source: Node = _caster if is_instance_valid(_caster) else null
	damage_dealt.emit(AreaDamage.hit(get_world_2d().direct_space_state, global_position, _stats.impact_radius,
			damage, source, _source_id, _stats.impact_knockback, _target_mask, _wall_mask))


func _tick() -> void:
	var source: Node = _caster if is_instance_valid(_caster) else null
	var on_hit: Callable = _on_hit if _stats.root_time > 0.0 or _stats.slow_time > 0.0 else Callable()
	if SpellData.int_at(_stats.tick_damage, _level) <= 0:
		# No damage: the patch only slows or roots whoever stands on it.
		if on_hit.is_valid():
			for hurtbox: Hurtbox in AreaDamage.targets(get_world_2d().direct_space_state, global_position, radius(), _target_mask, _wall_mask):
				on_hit.call(hurtbox)
		return
	damage_dealt.emit(AreaDamage.hit(get_world_2d().direct_space_state, global_position, radius(),
			SpellData.int_at(_stats.tick_damage, _level), source, _source_id, 0.0, _target_mask, _wall_mask, on_hit))


func _on_hit(hurtbox: Hurtbox) -> void:
	var player: Player = hurtbox.get_parent() as Player
	if player != null:
		if _stats.slow_time > 0.0:
			player.slow(_stats.slow_multiplier, _stats.slow_time)
		return
	var enemy: Enemy = Enemy.owner_of(hurtbox)
	if enemy == null or not is_instance_valid(enemy):
		return
	if _stats.root_time > 0.0:
		enemy.root(_stats.root_time)
	if _stats.slow_time > 0.0:
		enemy.slow(_stats.slow_multiplier, _stats.slow_time)


func _draw() -> void:
	if _look != null or _rock != null or _shadow != null:
		return
	if is_falling():
		var t: float = 1.0 - _fall_left / maxf(_stats.impact_delay, 0.001)
		draw_circle(Vector2.ZERO, _stats.impact_radius * t, Color(0.0, 0.0, 0.0, 0.35))
		return
	var r: float = radius()
	var fade: float = clampf(_time_left / FADE_TIME, 0.0, 1.0)
	draw_circle(Vector2.ZERO, r, Color(_stats.color, 0.3 * fade))
	draw_arc(Vector2.ZERO, r * (0.85 + 0.05 * sin(_age * 6.0)), 0.0, TAU, 24, Color(_stats.color, 0.8 * fade), 1.5)
