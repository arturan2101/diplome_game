class_name TeleportSkill
extends Skill
## Short teleport (stage 39): the wielder jumps up to TeleportSkillData.distance where
## they are heading. The jump never passes a wall (a sealed door included) and lands
## only on plain floor with room for the body: the farthest such spot along the line,
## so a pit or spikes can be jumped over. A short invulnerability covers the jump.
## Instant: it never holds the wielder, who can attack right away.

## Physics layers the jump cannot pass (world) and that must be clear at the landing
## spot (world and enemies).
@export_flags_2d_physics var wall_mask: int = 1
@export_flags_2d_physics var landing_mask: int = 5

var _stats: TeleportSkillData = null
var _landing_query: PhysicsShapeQueryParameters2D = PhysicsShapeQueryParameters2D.new()
var _landing_shape: CircleShape2D = CircleShape2D.new()


func setup(skill_data: SkillData, skill_wielder: Player) -> void:
	super(skill_data, skill_wielder)
	_stats = skill_data as TeleportSkillData
	if _stats == null:
		push_error("TeleportSkill needs TeleportSkillData, got %s" % skill_data)
		return
	_landing_shape.radius = _stats.body_radius
	_landing_query.shape = _landing_shape
	_landing_query.collision_mask = landing_mask
	_landing_query.collide_with_bodies = true
	_landing_query.collide_with_areas = false


func _activate(direction: Vector2) -> void:
	var heading: Vector2 = direction.normalized()
	if heading.is_zero_approx():
		heading = wielder.facing
	var origin: Vector2 = wielder.global_position
	var landing: Vector2 = find_landing(heading)
	StripSprite.spawn(wielder.get_parent(), origin, _stats.out_effect, _stats.effect_frames, _stats.effect_fps)
	if landing != origin:
		wielder.global_position = landing
		wielder.velocity = Vector2.ZERO
		StripSprite.spawn(wielder.get_parent(), landing, _stats.in_effect, _stats.effect_frames, _stats.effect_fps)
	wielder.health.make_invulnerable(_stats.invulnerability)
	_start_cooldown()


## Where a jump in this direction would land: the farthest safe spot on the line before
## any wall, or the wielder's own position if there is none.
func find_landing(heading: Vector2) -> Vector2:
	var origin: Vector2 = wielder.global_position
	var space: PhysicsDirectSpaceState2D = wielder.get_world_2d().direct_space_state
	var reach: float = _stats.distance
	var ray: PhysicsRayQueryParameters2D = PhysicsRayQueryParameters2D.create(origin, origin + heading * reach, wall_mask)
	ray.exclude = [wielder.get_rid()]
	var wall: Dictionary = space.intersect_ray(ray)
	if not wall.is_empty():
		reach = origin.distance_to(wall["position"]) - _stats.body_radius
	var level: Level = wielder.get_tree().get_first_node_in_group(Level.GROUP) as Level
	var along: float = reach
	while along >= _stats.search_step:
		var spot: Vector2 = origin + heading * along
		if _is_safe(spot, level, space):
			return spot
		along -= _stats.search_step
	return origin


## Plain floor (no pit, no spikes) with nothing solid around the body.
func _is_safe(spot: Vector2, level: Level, space: PhysicsDirectSpaceState2D) -> bool:
	if level != null and level.cell_type_at(spot) != LevelGrid.Cell.FLOOR:
		return false
	_landing_query.transform = Transform2D(0.0, spot)
	_landing_query.exclude = [wielder.get_rid()]
	return space.intersect_shape(_landing_query, 1).is_empty()
