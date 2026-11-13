class_name Fireball
extends Node2D
## The ball of the fireball spell. Flies straight, casting a ray every physics frame
## like an arrow. On the first enemy or wall, or at the end of its range, it explodes:
## every enemy in the blast that is not behind a wall is hurt and pushed away
## (AreaDamage). The blast is drawn for a moment, then the node is freed.

## Emitted once, with the damage the blast dealt (0 if it hit nobody).
signal exploded(damage: int)

## The blast happens this far back from a wall, so its rays do not start inside it.
const WALL_OFFSET: float = 4.0

## Placeholder look: radius of the flying ball, seconds the blast stays drawn, colour.
@export var ball_radius: float = 4.0
@export var blast_time: float = 0.25
@export var color: Color = Color(1.0, 0.55, 0.15)

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


func is_exploding() -> bool:
	return _blast_left >= 0.0


func _physics_process(delta: float) -> void:
	if is_exploding():
		_blast_left -= delta
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
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	if not result.is_empty():
		global_position = (result["position"] as Vector2) - _direction * WALL_OFFSET
		_explode()
		return
	global_position = to
	_distance_left -= travel
	if _distance_left <= 0.0:
		_explode()


func _explode() -> void:
	var dealt: int = AreaDamage.hit(get_world_2d().direct_space_state, global_position, _radius, _info.amount,
			_info.source if is_instance_valid(_info.source) else null, _info.source_id, _knockback,
			_target_mask, _wall_mask)
	_blast_left = blast_time
	queue_redraw()
	exploded.emit(dealt)


func _draw() -> void:
	if not is_exploding():
		draw_circle(Vector2.ZERO, ball_radius, color)
		draw_circle(Vector2.ZERO, ball_radius * 0.5, Color(1.0, 0.95, 0.7))
		return
	# The blast grows a little and fades out.
	var t: float = 1.0 - _blast_left / blast_time
	draw_circle(Vector2.ZERO, _radius * (0.7 + 0.3 * t), Color(color, 0.55 * (1.0 - t)))
