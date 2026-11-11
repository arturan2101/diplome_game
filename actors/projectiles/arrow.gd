class_name Arrow
extends Node2D
## Projectile shot by a bow. Flies straight; every physics frame it casts a ray from its
## position to the next one, so even a fast arrow cannot skip a thin target.
## Disappears when it hits a target or a wall, or after flying its full range.

## Emitted once when the arrow disappears; hit is true if it damaged a target.
signal landed(hit: bool)

## Physics layers of the hurtboxes the arrow damages (enemy_hurtbox).
@export_flags_2d_physics var target_mask: int = 16
## Physics layers that stop the arrow (world).
@export_flags_2d_physics var wall_mask: int = 1
## Placeholder look: a line of this length, width and colour.
@export var length: float = 8.0
@export var width: float = 2.0
@export var color: Color = Color(0.95, 0.85, 0.55)

var _info: DamageInfo = null
var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _distance_left: float = 0.0


## Called by the bow before adding the arrow to the scene.
func setup(info: DamageInfo, direction: Vector2, speed: float, max_distance: float) -> void:
	_info = info
	_direction = direction.normalized()
	_speed = speed
	_distance_left = max_distance
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	var travel: float = minf(_speed * delta, _distance_left)
	var from: Vector2 = global_position
	var to: Vector2 = from + _direction * travel
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, target_mask | wall_mask)
	ray.collide_with_areas = true
	# Point-blank shots: a target already overlapping the start point is still hit.
	ray.hit_from_inside = true
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	if not result.is_empty():
		var hurtbox: Hurtbox = result["collider"] as Hurtbox
		# A wall or an absorbed hit (invulnerable target) is a miss; the arrow is spent either way.
		_land(hurtbox != null and hurtbox.receive_hit(_info))
		return
	global_position = to
	_distance_left -= travel
	if _distance_left <= 0.0:
		_land(false)


func _draw() -> void:
	draw_line(Vector2(-length, 0.0), Vector2.ZERO, color, width)


func _land(hit: bool) -> void:
	landed.emit(hit)
	queue_free()
	set_physics_process(false)
