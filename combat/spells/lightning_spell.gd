class_name LightningSpell
extends Spell
## Chain lightning (stage 40): see LightningData. The first target is the nearest
## visible enemy within the spell's auto-aim radius; every jump goes to the nearest
## enemy not struck yet within jump_range, never through a wall. The storm cloud uses
## strike() for its single bolts.


func _cast(direction: Vector2) -> void:
	var stats: LightningData = data as LightningData
	if stats == null:
		return
	var space: PhysicsDirectSpaceState2D = get_world_2d().direct_space_state
	var points: PackedVector2Array = PackedVector2Array([caster.global_position])
	var struck: Array[Hurtbox] = []
	var target: Hurtbox = caster.aim_target(stats.auto_aim_radius)
	var dealt: int = 0
	var damage: int = spell_damage(stats.damage)
	while target != null and struck.size() < SpellData.int_at(stats.chain_count, level):
		struck.append(target)
		points.append(target.global_position)
		dealt += strike(target, damage, stats.wet_multiplier, caster, stats.id, points[points.size() - 2])
		if stats.zone_on_hit != null:
			var zone: SpellZone = SpellZone.spawn(_effect_parent(), target.global_position, scaled_zone(stats.zone_on_hit), level,
					caster, stats.id, target_mask, wall_mask)
			zone.damage_dealt.connect(_report_damage)
		target = _next_target(space, target.global_position, stats.jump_range, struck)
	if struck.is_empty():
		points.append(caster.global_position + direction * stats.miss_distance)
	LightningBolt.spawn(_effect_parent(), points, stats.color, stats.bolt_time, stats.frames, stats.bolt_animation,
			stats.hit_animation if not struck.is_empty() else &"")
	_report_damage(dealt)


## Hits one enemy with a bolt coming from `from`: wet enemies take more. Returns the
## damage it took (0 if absorbed).
static func strike(target: Hurtbox, damage: int, wet_multiplier: float, source: Node, source_id: StringName,
		from: Vector2) -> int:
	var enemy: Enemy = Enemy.owner_of(target)
	if enemy != null and is_instance_valid(enemy) and enemy.is_wet():
		damage = roundi(damage * wet_multiplier)
	var info: DamageInfo = DamageInfo.new(damage, source, source_id)
	info.direction = from.direction_to(target.global_position)
	return damage if target.receive_hit(info) else 0


## The nearest hurtbox within reach of `from` that is not in `exclude`, or null.
static func nearest_target(space: PhysicsDirectSpaceState2D, from: Vector2, reach: float, target_mask: int,
		wall_mask: int, exclude: Array[Hurtbox]) -> Hurtbox:
	var best: Hurtbox = null
	var best_distance: float = INF
	for hurtbox: Hurtbox in AreaDamage.targets(space, from, reach, target_mask, wall_mask):
		if hurtbox in exclude or (hurtbox.health != null and hurtbox.health.is_dead()):
			continue
		var distance: float = from.distance_to(hurtbox.global_position)
		if distance < best_distance:
			best = hurtbox
			best_distance = distance
	return best


func _next_target(space: PhysicsDirectSpaceState2D, from: Vector2, reach: float, struck: Array[Hurtbox]) -> Hurtbox:
	return nearest_target(space, from, reach, target_mask, wall_mask, struck)
