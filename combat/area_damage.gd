class_name AreaDamage
extends RefCounted
## Damage to every hurtbox inside a circle (fireball blast, whirlwind tick), or inside
## an arc of it (the water's wave). A target behind a wall is safe: a ray from the
## centre to it must not cross the world layer. Each target is pushed away from the
## centre.


## Hits every hurtbox of target_mask inside the circle once. Returns the damage dealt
## (absorbed hits, e.g. by an invulnerable target, do not count). on_hit, if given, is
## called with every hurtbox that took the hit (to freeze or wet its owner).
## With arc_degrees below 360 only targets within that arc around arc_direction count;
## hurtboxes in exclude are skipped (already hit by a piercing ball).
static func hit(space: PhysicsDirectSpaceState2D, center: Vector2, radius: float, damage: int, source: Node,
		source_id: StringName, knockback: float, target_mask: int, wall_mask: int,
		on_hit: Callable = Callable(), arc_direction: Vector2 = Vector2.ZERO, arc_degrees: float = 360.0,
		exclude: Array = []) -> int:
	var dealt: int = 0
	for hurtbox: Hurtbox in targets(space, center, radius, target_mask, wall_mask, arc_direction, arc_degrees):
		if hurtbox in exclude:
			continue
		var away: Vector2 = center.direction_to(hurtbox.global_position) if not center.is_equal_approx(hurtbox.global_position) else Vector2.RIGHT
		var info: DamageInfo = DamageInfo.new(damage, source, source_id, away * knockback)
		info.direction = away
		if hurtbox.receive_hit(info):
			dealt += damage
			if on_hit.is_valid():
				on_hit.call(hurtbox)
	return dealt


## The hurtboxes such a hit would reach, each once, without hitting them.
static func targets(space: PhysicsDirectSpaceState2D, center: Vector2, radius: float, target_mask: int,
		wall_mask: int, arc_direction: Vector2 = Vector2.ZERO, arc_degrees: float = 360.0) -> Array[Hurtbox]:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = target_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var found: Array[Hurtbox] = []
	var limit: float = deg_to_rad(arc_degrees) * 0.5
	for result: Dictionary in space.intersect_shape(query):
		var hurtbox: Hurtbox = result["collider"] as Hurtbox
		if hurtbox == null or hurtbox in found:
			continue
		var target: Vector2 = hurtbox.global_position
		if arc_degrees < 360.0 and not arc_direction.is_zero_approx() and not center.is_equal_approx(target) \
				and absf(arc_direction.angle_to(target - center)) > limit:
			continue
		if wall_mask != 0 and not space.intersect_ray(PhysicsRayQueryParameters2D.create(center, target, wall_mask)).is_empty():
			continue
		found.append(hurtbox)
	return found
