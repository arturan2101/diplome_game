class_name Arrow
extends Node2D
## Projectile shot by a bow. Flies straight; every physics frame it casts a ray from its
## position to the next one, so even a fast arrow cannot skip a thin target.
## Disappears when it hits a target or a wall, or after flying its full range.

## Emitted once when the arrow disappears; hit is true if it damaged a target.
signal landed(hit: bool)

## Group of all projectiles in flight; the game clears it between sections.
const GROUP: StringName = &"projectiles"

## Physics layers of the hurtboxes the arrow damages (enemy_hurtbox).
@export_flags_2d_physics var target_mask: int = 16
## Physics layers that stop the arrow (world).
@export_flags_2d_physics var wall_mask: int = 1
## Placeholder look: a line of this length, width and colour. Length 0 draws nothing
## (the scene then shows a Sprite2D child instead).
@export var length: float = 8.0
@export var width: float = 2.0
@export var color: Color = Color(0.95, 0.85, 0.55)
## A strip played once where it lands (the Warden's boulder: dust and chips); null = none.
@export var hit_effect: Texture2D
@export var hit_effect_frames: int = 4
@export var hit_effect_fps: float = 12.0

## How many targets the arrow flies through after hitting one (the crossbow bolt sets
## it before setup()); 0 = it stops at the first target.
var pierce: int = 0

var _info: DamageInfo = null
var _direction: Vector2 = Vector2.RIGHT
var _speed: float = 0.0
var _distance_left: float = 0.0
## True once a target took damage; hurtboxes already flown through are not hit again.
var _has_hit: bool = false
var _passed: Array[RID] = []
var _range: float = 0.0
## Set by reflect() while a hurtbox is handling this arrow's hit: it flies on instead.
var _turned: bool = false


## Called by the bow before adding the arrow to the scene.
func setup(info: DamageInfo, direction: Vector2, speed: float, max_distance: float) -> void:
	_direction = direction.normalized()
	_info = info
	_info.direction = _direction
	_info.projectile = self
	_speed = speed
	_distance_left = max_distance
	_range = max_distance
	add_to_group(GROUP)
	rotation = _direction.angle()


func _physics_process(delta: float) -> void:
	var travel: float = minf(_speed * delta, _distance_left)
	var from: Vector2 = global_position
	var to: Vector2 = from + _direction * travel
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(from, to, target_mask | wall_mask)
	ray.collide_with_areas = true
	# Point-blank shots: a target already overlapping the start point is still hit.
	ray.hit_from_inside = true
	ray.exclude = _passed
	var result: Dictionary = get_world_2d().direct_space_state.intersect_ray(ray)
	if not result.is_empty():
		var hurtbox: Hurtbox = result["collider"] as Hurtbox
		# A wall or an absorbed hit (invulnerable target) is a miss; the arrow is spent either way.
		if hurtbox != null and hurtbox.receive_hit(_info if _passed.is_empty() else _info.copy()):
			_has_hit = true
		if _turned:
			# Parried: it flies back from where it was caught.
			_turned = false
			global_position = result["position"]
			return
		if hurtbox == null or pierce <= 0:
			_land(_has_hit)
			return
		# Through this target and on: the rest of the flight starts where it was hit.
		pierce -= 1
		_passed.append(hurtbox.get_rid())
		var hit_position: Vector2 = result["position"]
		_distance_left -= from.distance_to(hit_position)
		global_position = hit_position
		if _distance_left <= 0.0:
			_land(_has_hit)
		return
	global_position = to
	_distance_left -= travel
	if _distance_left <= 0.0:
		_land(_has_hit)


## Turns the arrow back (a parry, stage 44): it now carries info, flies along direction
## this many times faster for its full range again, and hurts the hurtboxes of mask.
## Called while a hurtbox handles its hit; the arrow then flies on instead of landing.
func reflect(info: DamageInfo, direction: Vector2, speed_multiplier: float, mask: int) -> void:
	_direction = direction.normalized()
	_info = info
	_info.direction = _direction
	_info.projectile = self
	_speed *= speed_multiplier
	_distance_left = _range
	target_mask = mask
	pierce = 0
	_has_hit = false
	_passed.clear()
	_turned = true
	rotation = _direction.angle()


func _draw() -> void:
	if length <= 0.0:
		return
	draw_line(Vector2(-length, 0.0), Vector2.ZERO, color, width)


func _land(hit: bool) -> void:
	if hit_effect != null and get_parent() != null:
		StripSprite.spawn(get_parent(), global_position, hit_effect, hit_effect_frames, hit_effect_fps)
	landed.emit(hit)
	queue_free()
	set_physics_process(false)
