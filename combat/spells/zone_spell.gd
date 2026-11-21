class_name ZoneSpell
extends Spell
## Casts a SpellZone (stage 40): on the nearest visible enemy within the spell's
## auto-aim radius, otherwise cast_distance ahead, stopping short of a wall.

## Distance kept from a wall when the patch lands in front of it, pixels.
const WALL_MARGIN: float = 8.0


func _cast(direction: Vector2) -> void:
	var stats: ZoneData = data as ZoneData
	if stats == null:
		return
	var zone: SpellZone = SpellZone.spawn(_effect_parent(), _landing(stats, direction), stats, level, caster, stats.id,
			target_mask, wall_mask)
	# If this spell is forgotten while the patch lasts, Godot drops the connection.
	zone.damage_dealt.connect(_report_damage)


func _landing(stats: ZoneData, direction: Vector2) -> Vector2:
	var target: Hurtbox = caster.aim_target(stats.auto_aim_radius)
	if target != null:
		return target.global_position
	var origin: Vector2 = caster.global_position
	var distance: float = stats.cast_distance
	var wall: Dictionary = get_world_2d().direct_space_state.intersect_ray(
			PhysicsRayQueryParameters2D.create(origin, origin + direction * distance, wall_mask))
	if not wall.is_empty():
		distance = maxf(origin.distance_to(wall["position"]) - WALL_MARGIN, 0.0)
	return origin + direction * distance
