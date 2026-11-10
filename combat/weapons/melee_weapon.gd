class_name MeleeWeapon
extends Weapon
## Melee weapon with a combo, such as the sword. Each step damages every Hurtbox inside
## an arc in front of the wielder: each target at most once per step, never through walls.
## Steps come from MeleeWeaponData.combo; a step with knockback pushes targets away.

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
var _reach_shape: CircleShape2D = CircleShape2D.new()
## Step being performed now, its index, and the index the next press starts.
var _step: MeleeAttackStep = null
var _step_index: int = 0
var _next_step_index: int = 0
var _swing_direction: Vector2 = Vector2.RIGHT
## Seconds left in the current hit window.
var _active_left: float = 0.0
## Seconds until a new step may start: hit window + recovery (+ pause after the last step).
var _busy_left: float = 0.0
## Seconds since the weapon became ready; longer than combo_window resets the combo.
var _idle_time: float = 0.0
var _has_buffered_press: bool = false
var _buffered_direction: Vector2 = Vector2.RIGHT
## Hurtboxes already damaged by the current step.
var _hit_this_step: Array[Hurtbox] = []


func setup(weapon_data: WeaponData, weapon_wielder: Node2D) -> void:
	super(weapon_data, weapon_wielder)
	_stats = weapon_data as MeleeWeaponData
	if _stats == null or _stats.combo.is_empty():
		push_error("MeleeWeapon needs MeleeWeaponData with at least one combo step: %s" % weapon_data)
		_stats = null
		return
	# The query asks the physics engine which hurtboxes are inside a circle of radius reach.
	_query.shape = _reach_shape
	_query.collision_mask = target_mask
	_query.collide_with_areas = true
	_query.collide_with_bodies = false


## Stops the swing: no more hits from it and no buffered press; the combo starts over.
## Damage already dealt stays, and the busy time keeps running, so swapping weapons
## back and forth cannot skip it.
func cancel_attack() -> void:
	if _active_left > 0.0:
		_active_left = 0.0
		# Report the interrupted swing with the hits it managed to land.
		attack_performed.emit(_step_index, _hit_this_step.size())
		queue_redraw()
	_has_buffered_press = false
	_next_step_index = 0


func _on_attack_pressed(direction: Vector2) -> void:
	if _stats == null or direction.is_zero_approx():
		return
	if _busy_left > 0.0:
		# Remember one press, and only near the end, so mashing does not run the combo by itself.
		if _busy_left <= _stats.buffer_window:
			_has_buffered_press = true
			_buffered_direction = direction
		return
	_start_step(direction)


func _physics_process(delta: float) -> void:
	if _active_left > 0.0:
		# Checked every frame of the hit window, so targets that walk into the arc are hit too.
		_hit_targets_in_arc()
		_active_left -= delta
		if _active_left <= 0.0:
			attack_performed.emit(_step_index, _hit_this_step.size())
			queue_redraw()
	if _busy_left > 0.0:
		_busy_left -= delta
		if _busy_left <= 0.0 and _has_buffered_press:
			_has_buffered_press = false
			_start_step(_buffered_direction)
	else:
		_idle_time += delta


func _draw() -> void:
	if _active_left <= 0.0 or _step == null:
		return
	var half_arc: float = deg_to_rad(_step.arc_degrees) * 0.5
	var start_angle: float = _swing_direction.angle() - half_arc
	var points: PackedVector2Array = PackedVector2Array([Vector2.ZERO])
	for i in ARC_SEGMENTS + 1:
		var angle: float = start_angle + 2.0 * half_arc * i / ARC_SEGMENTS
		points.append(Vector2.from_angle(angle) * _step.reach)
	draw_colored_polygon(points, arc_color)


func _start_step(direction: Vector2) -> void:
	if _idle_time > _stats.combo_window:
		_next_step_index = 0
	_step_index = _next_step_index
	_step = _stats.combo[_step_index]
	var is_last_step: bool = _step_index == _stats.combo.size() - 1
	_next_step_index = 0 if is_last_step else _step_index + 1
	_swing_direction = direction.normalized()
	_active_left = _step.duration
	_busy_left = _step.duration + _step.recovery
	if is_last_step:
		_busy_left += _stats.combo_end_cooldown
	_idle_time = 0.0
	_reach_shape.radius = _step.reach
	_hit_this_step.clear()
	queue_redraw()


func _hit_targets_in_arc() -> void:
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	_query.transform = Transform2D(0.0, global_position)
	for result: Dictionary in space.intersect_shape(_query):
		var hurtbox: Hurtbox = result["collider"] as Hurtbox
		if hurtbox == null or hurtbox in _hit_this_step:
			continue
		if not _is_in_arc(hurtbox.global_position):
			continue
		if not _has_line_of_sight(space, hurtbox.global_position):
			continue
		_hit_this_step.append(hurtbox)
		var push_direction: Vector2 = (hurtbox.global_position - global_position).normalized()
		if push_direction.is_zero_approx():
			push_direction = _swing_direction
		hurtbox.receive_hit(DamageInfo.new(_step.damage, wielder, data.id, push_direction * _step.knockback))


func _is_in_arc(target_position: Vector2) -> bool:
	var to_target: Vector2 = target_position - global_position
	if to_target.is_zero_approx():
		return true
	return absf(_swing_direction.angle_to(to_target)) <= deg_to_rad(_step.arc_degrees) * 0.5


## True if no wall lies on the straight line from the wielder to the target.
func _has_line_of_sight(space: PhysicsDirectSpaceState2D, target_position: Vector2) -> bool:
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(
			global_position, target_position, wall_mask)
	return space.intersect_ray(ray).is_empty()
