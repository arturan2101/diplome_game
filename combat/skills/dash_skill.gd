class_name DashSkill
extends Skill
## Dash: moves the wielder fast in one direction. While dashing the wielder is
## invulnerable, flies over pits and spikes, and passes through enemies.

## Physics layers the wielder stops colliding with during the dash (enemies).
@export_flags_2d_physics var pass_through_mask: int = 4

var _stats: DashSkillData = null
var _time_left: float = 0.0
var _velocity: Vector2 = Vector2.ZERO
var _saved_collision_mask: int = 0


func setup(skill_data: SkillData, skill_wielder: Player) -> void:
	super(skill_data, skill_wielder)
	_stats = skill_data as DashSkillData
	if _stats == null:
		push_error("DashSkill needs DashSkillData, got %s" % skill_data)


func is_active() -> bool:
	return _time_left > 0.0


func get_forced_velocity() -> Vector2:
	return _velocity if is_active() else Vector2.ZERO


func cancel() -> void:
	if is_active():
		_finish()


func _activate(direction: Vector2) -> void:
	var dash_direction: Vector2 = direction.normalized()
	if dash_direction.is_zero_approx():
		dash_direction = wielder.facing
	_velocity = dash_direction * _stats.distance / _stats.duration
	_time_left = _stats.duration
	wielder.health.make_invulnerable(_stats.duration + _stats.invulnerability_margin)
	wielder.set_airborne(true)
	_saved_collision_mask = wielder.collision_mask
	wielder.collision_mask &= ~pass_through_mask


func _update(delta: float) -> void:
	if not is_active():
		return
	_time_left -= delta
	# Half a frame of tolerance: float error must not add an extra frame of movement.
	if _time_left < delta * 0.5:
		_finish()


func _finish() -> void:
	_time_left = 0.0
	# Without this the player would slide on with the dash speed after it ends.
	wielder.velocity = Vector2.ZERO
	wielder.collision_mask = _saved_collision_mask
	wielder.set_airborne(false)
	_start_cooldown()
