class_name AreaDamage
extends RefCounted
## Damage to every hurtbox inside a circle (fireball blast, whirlwind tick).
## A target behind a wall is safe: a ray from the centre to it must not cross the
## world layer. Each target is pushed away from the centre.


## Hits every hurtbox of target_mask inside the circle once. Returns the damage dealt
## (absorbed hits, e.g. by an invulnerable target, do not count).
static func hit(space: PhysicsDirectSpaceState2D, center: Vector2, radius: float, damage: int, source: Node,
		source_id: StringName, knockback: float, target_mask: int, wall_mask: int) -> int:
	var circle: CircleShape2D = CircleShape2D.new()
	circle.radius = radius
	var query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
	query.shape = circle
	query.transform = Transform2D(0.0, center)
	query.collision_mask = target_mask
	query.collide_with_areas = true
	query.collide_with_bodies = false
	var dealt: int = 0
	var seen: Dictionary = {}
	for result: Dictionary in space.intersect_shape(query):
		var hurtbox: Hurtbox = result["collider"] as Hurtbox
		if hurtbox == null or seen.has(hurtbox):
			continue
		seen[hurtbox] = true
		var target: Vector2 = hurtbox.global_position
		if wall_mask != 0 and not space.intersect_ray(PhysicsRayQueryParameters2D.create(center, target, wall_mask)).is_empty():
			continue
		var away: Vector2 = center.direction_to(target) if not center.is_equal_approx(target) else Vector2.RIGHT
		var info: DamageInfo = DamageInfo.new(damage, source, source_id, away * knockback)
		info.direction = away
		if hurtbox.receive_hit(info):
			dealt += damage
	return dealt
