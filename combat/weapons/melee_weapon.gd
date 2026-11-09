class_name MeleeWeapon
extends Weapon
## Sword-like weapon. During a short swing it damages every Hurtbox inside an arc
## in front of the wielder: each target at most once per swing, never through walls.

## Number of segments used to draw the placeholder arc.
const ARC_SEGMENTS: int = 12

## Physics layers of the hurtboxes this weapon can damage (enemy_hurtbox).
@export_flags_2d_physics var target_mask: int = 16
## Physics layers that block hits (world).
@export_flags_2d_physics var wall_mask: int = 1
## Colour of the placeholder swing arc.
@export var arc_color: Color = Color(1.0, 1.0, 1.0, 0.5)

var _stats: MeleeWeaponData = null
var _query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
var _swing_direction: Vector2 = Vector2.RIGHT
var _swing_time_left: float = 0.0
var _cooldown_left: float = 0.0
## Hurtboxes already damaged by the current swing.
var _hit_this_swing: Array[Hurtbox] = []


func setup(weapon_data: WeaponData, weapon_wielder: Node2D) -> void:
	super(weapon_data, weapon_wielder)
	_stats = weapon_data as MeleeWeaponData
	if _stats == null:
		push_error("MeleeWeapon needs MeleeWeaponData, got %s" % weapon_data)
		return
	# The query asks the physics engine which hurtboxes are inside a circle of radius reach.
	var reach_shape: CircleShape2D = CircleShape2D.new()
	reach_shape.radius = _stats.reach
	_query.shape = reach_shape
	_query.collision_mask = target_mask
	_query.collide_with_areas = true
	_query.collide_with_bodies = false


func try_attack(direction: Vector2) -> void:
	if _stats == null or direction.is_zero_approx():
		return
	if _swing_time_left > 0.0 or _cooldown_left > 0.0:
		return
	_swing_direction = direction.normalized()
	_swing_time_left = _stats.attack_duration
	_cooldown_left = _stats.cooldown
	_hit_this_swing.clear()
	queue_redraw()


func _physics_process(delta: float) -> void:
	_cooldown_left = maxf(_cooldown_left - delta, 0.0)
	if _swing_time_left <= 0.0:
		return
	# Checked every frame of the swing, so targets that walk into the arc are hit too.
	_hit_targets_in_arc()
	_swing_time_left -= delta
	if _swing_time_left <= 0.0:
		attack_finished.emit(_hit_this_swing.size())
		queue_redraw()


func _draw() -> void:
	if _swing_time_left <= 0.0 or _stats == null:
		return
	var half_arc: float = deg_to_rad(_stats.arc_degrees) * 0.5
	var start_angle: float = _swing_direction.angle() - half_arc
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i in ARC_SEGMENTS + 1:
		var angle: float = start_angle + 2.0 * half_arc * i / ARC_SEGMENTS
		points.append(Vector2.from_angle(angle) * _stats.reach)
	draw_colored_polygon(points, arc_color)


func _hit_targets_in_arc() -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	_query.transform = Transform2D(0.0, global_position)
	for result: Dictionary in space.intersect_shape(_query):
		var hurtbox: Hurtbox = result["collider"] as Hurtbox
		if hurtbox == null or hurtbox in _hit_this_swing:
			continue
		if not _is_in_arc(hurtbox.global_position):
			continue
		if not _has_line_of_sight(space, hurtbox.global_position):
			continue
		_hit_this_swing.append(hurtbox)
		hurtbox.receive_hit(DamageInfo.new(_stats.damage, wielder, data.id))


func _is_in_arc(target_position: Vector2) -> bool:
	var to_target: Vector2 = target_position - global_position
	if to_target.is_zero_approx():
		return true
	return absf(_swing_direction.angle_to(to_target)) <= deg_to_rad(_stats.arc_degrees) * 0.5


## True if no wall lies on the straight line from the wielder to the target.
func _has_line_of_sight(space: PhysicsDirectSpaceState2D, target_position: Vector2) -> bool:
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			global_position, target_position, wall_mask)
	return space.intersect_ray(ray).is_empty()
