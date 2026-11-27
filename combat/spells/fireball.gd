class_name Fireball
extends Node2D
## The ball of the fireball spell. Flies straight, casting a ray every physics frame
## like an arrow. On the first enemy or wall, or at the end of its range, it explodes:
## every enemy in the blast that is not behind a wall is hurt and pushed away
## (AreaDamage). The blast is drawn for a moment, then the node is freed.
## The look comes from the spell (set_look): the level's animation, turned with the
## flight; without it a placeholder ball is drawn. A level 3 fireball also leaves a
## trail of burning ground (set_trail), only a look.

## Emitted once, with the damage the blast dealt (0 if it hit nobody).
signal exploded(damage: int)

## The blast happens this far back from a wall, so its rays do not start inside it.
const WALL_OFFSET: float = 4.0

## Placeholder look: radius of the flying ball, seconds the blast stays drawn, colour.
@export var ball_radius: float = 4.0
@export var blast_time: float = 0.25
@export var color: Color = Color(1.0, 0.55, 0.15)

## Flies through enemies, hurting each (the plasma); set by the spell before setup().
var pierce: bool = false
## Sound of the blast, set by the spell (stage 46).
var explode_sound: StringName = &""

var _info: DamageInfo = null
var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _distance_left: float = 0.0
var _radius: float = 0.0
var _knockback: float = 0.0
var _target_mask: int = 0
var _wall_mask: int = 0
## Seconds left of the blast drawing; negative while the ball still flies.
var _blast_left: float = -1.0
## Art of the flying ball (set_look); null = the placeholder drawing.
var _look: AnimatedSprite2D = null
## The look grows into the blast instead of the drawn flash; its scale from and to.
var _blast_look: bool = false
var _look_scale_from: float = 1.0
var _look_scale_to: float = 1.0
## Burning ground left behind (set_trail).
var _trail_frames: SpriteFrames = null
var _trail_animation: StringName = &""
var _trail_spacing: float = 0.0
var _trail_time: float = 0.0
var _trail_left: float = 0.0
## Hurtboxes the piercing ball went through, and the damage it dealt on the way.
var _passed: Array = []
var _pierce_dealt: int = 0


## Called by the spell before adding the ball to the scene. info carries the damage,
## the caster as source and the spell id as source_id.
func setup(info: DamageInfo, direction: Vector2, speed: float, max_range: float, blast_radius: float,
		knockback: float, target_mask: int, wall_mask: int) -> void:
	_info = info
	_direction = direction.normalized()
	_speed = speed
	_distance_left = max_range
	_radius = blast_radius
	_knockback = knockback
	_target_mask = target_mask
	_wall_mask = wall_mask
	# Cleared between sections together with arrows.
	add_to_group(Arrow.GROUP)


## The art of the ball: an animation of look_frames at look_scale, turned with the
## flight or not. grows_into_blast: at the blast the look grows to the blast's size and
## fades out (instead of the drawn flash). Called after setup().
func set_look(look_frames: SpriteFrames, look_animation: StringName, turn_with_flight: bool, look_scale: float,
		grows_into_blast: bool) -> void:
	if look_frames == null or look_animation == &"" or not look_frames.has_animation(look_animation):
		return
	_look = AnimatedSprite2D.new()
	_look.name = "Look"
	_look.sprite_frames = look_frames
	_look.animation = look_animation
	_look.scale = Vector2.ONE * look_scale
	if turn_with_flight:
		_look.rotation = _direction.angle()
	_blast_look = grows_into_blast
	add_child(_look)
	_look.play(look_animation)


## Leaves a flame of trail_animation every spacing pixels of the flight; each burns
## for `seconds`. Only a look: it does not hurt.
func set_trail(trail_frames: SpriteFrames, trail_animation: StringName, spacing: float, seconds: float) -> void:
	if trail_frames == null or trail_animation == &"" or not trail_frames.has_animation(trail_animation) or spacing <= 0.0:
		return
	_trail_frames = trail_frames
	_trail_animation = trail_animation
	_trail_spacing = spacing
	_trail_time = seconds
	_trail_left = spacing


## The art of the flying ball, or null.
func get_look() -> AnimatedSprite2D:
	return _look


func is_exploding() -> bool:
	return _blast_left >= 0.0


func _physics_process(delta: float) -> void:
	if is_exploding():
		_blast_left -= delta
		_update_blast_look()
		queue_redraw()
		if _blast_left < 0.0:
			queue_free()
			set_physics_process(false)
		return
	var travel: float = minf(_speed * delta, _distance_left)
	var from: Vector2 = global_position
	var to: Vector2 = from + _direction * travel
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, _target_mask | _wall_mask)
	ray.collide_with_areas = true
	ray.hit_from_inside = true
	# An enemy the ball killed on its way is freed: drop it before the typed loop (a
	# freed object in a typed variable stopped the ball in mid-air, after stage 49).
	_passed = _passed.filter(func(passed: Variant) -> bool: return is_instance_valid(passed))
	var exclude: Array[RID] = []
	for passed: Hurtbox in _passed:
		exclude.append(passed.get_rid())
	ray.exclude = exclude
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	if not result.is_empty():
		var hurtbox: Hurtbox = result["collider"] as Hurtbox
		if pierce and hurtbox != null:
			_pierce(hurtbox)
			return
		global_position = (result["position"] as Vector2) - _direction * WALL_OFFSET
		_explode()
		return
	global_position = to
	_distance_left -= travel
	_drop_trail(travel)
	if _distance_left <= 0.0:
		_explode()


func _drop_trail(travel: float) -> void:
	if _trail_frames == null:
		return
	_trail_left -= travel
	if _trail_left > 0.0:
		return
	_trail_left += _trail_spacing
	var parent: Node = get_parent()
	if parent == null:
		return
	var flame: EffectSprite = EffectSprite.spawn(parent, global_position, _trail_frames, _trail_animation, _trail_time)
	# Under the ball, not over it.
	parent.move_child(flame, get_index())


## The look of a blast that grows from the ball: bigger in the first half, fading in
## the second.
func _update_blast_look() -> void:
	if _look == null or not _blast_look:
		return
	var t: float = clampf(1.0 - _blast_left / maxf(blast_time, 0.001), 0.0, 1.0)
	_look.scale = Vector2.ONE * lerpf(_look_scale_from, _look_scale_to, minf(t * 2.0, 1.0))
	_look.modulate.a = clampf(2.0 - 2.0 * t, 0.0, 1.0)


## The piercing ball hurts the enemy it reached and flies on (the next frame starts
## from here, the enemy left out of the rays).
func _pierce(hurtbox: Hurtbox) -> void:
	_passed.append(hurtbox)
	var hit: DamageInfo = _info.copy()
	hit.source = _info.source if is_instance_valid(_info.source) else null
	hit.direction = _direction
	hit.knockback = _direction * _knockback
	if hurtbox.receive_hit(hit):
		_pierce_dealt += hit.amount


func _explode() -> void:
	Sound.play_at(explode_sound, global_position)
	var dealt: int = _pierce_dealt + AreaDamage.hit(get_world_2d().direct_space_state, global_position, _radius,
			_info.amount, _info.source if is_instance_valid(_info.source) else null, _info.source_id, _knockback,
			_target_mask, _wall_mask, Callable(), Vector2.ZERO, 360.0, _passed)
	_blast_left = blast_time
	if _look != null:
		if _blast_look:
			var size: Vector2 = SpellData.frame_size(_look.sprite_frames, _look.animation)
			_look_scale_from = _look.scale.x
			_look_scale_to = _radius * 2.0 / maxf(size.x, 1.0)
		else:
			_look.visible = false
	queue_redraw()
	exploded.emit(dealt)


func _draw() -> void:
	if not is_exploding():
		if _look == null:
			draw_circle(Vector2.ZERO, ball_radius, color)
			draw_circle(Vector2.ZERO, ball_radius * 0.5, Color(1.0, 0.95, 0.7))
		return
	if _look != null and _blast_look:
		return
	# The blast grows a little and fades out.
	var t: float = 1.0 - _blast_left / blast_time
	draw_circle(Vector2.ZERO, _radius * (0.7 + 0.3 * t), Color(color, 0.55 * (1.0 - t)))
