class_name BlockSkill
extends Skill
## Shield block: while the shield is up, hits coming from the front arc are stopped,
## the wielder moves slower and cannot attack. A blocked melee attacker is pushed back.
## Hits from the sides and the back, and hazards, still go through.

## Placeholder look of the raised shield: an arc in front of the wielder.
@export var shield_color: Color = Color(0.6, 0.8, 1.0, 0.9)
@export var shield_radius: float = 10.0
@export var shield_width: float = 2.0

var _stats: BlockSkillData = null
var _is_raised: bool = false
var _raised_time: float = 0.0


func setup(skill_data: SkillData, skill_wielder: Player) -> void:
	super(skill_data, skill_wielder)
	_stats = skill_data as BlockSkillData
	if _stats == null:
		push_error("BlockSkill needs BlockSkillData, got %s" % skill_data)
		return
	wielder.hurtbox.add_guard(_blocks)


func _exit_tree() -> void:
	if wielder != null and wielder.hurtbox != null:
		wielder.hurtbox.remove_guard(_blocks)


func is_active() -> bool:
	return _is_raised


func get_move_speed_multiplier() -> float:
	return _stats.move_speed_multiplier if _is_raised else 1.0


func cancel() -> void:
	if _is_raised:
		_lower()


func _activate(_direction: Vector2) -> void:
	_is_raised = true
	_raised_time = 0.0
	queue_redraw()


func _on_released() -> void:
	if _is_raised and _stats.hold_mode:
		_lower()


func _update(delta: float) -> void:
	if not _is_raised:
		return
	_raised_time += delta
	var limit: float = _stats.max_hold_time if _stats.hold_mode else _stats.tap_duration
	if _raised_time >= limit:
		_lower()
	queue_redraw()


func _draw() -> void:
	if not _is_raised:
		return
	var half_arc: float = deg_to_rad(_stats.arc_degrees) * 0.5
	var angle: float = wielder.get_look_direction().angle()
	draw_arc(Vector2.ZERO, shield_radius, angle - half_arc, angle + half_arc, 16, shield_color, shield_width)


func _lower() -> void:
	_is_raised = false
	_start_cooldown()
	queue_redraw()


## Guard for the wielder's Hurtbox: true if the raised shield stops this hit.
func _blocks(info: DamageInfo) -> bool:
	if not _is_raised or info.source == null:
		return false
	# Direction from the wielder towards where the hit comes from.
	var incoming: Vector2 = -info.direction
	var attacker: Node2D = info.source as Node2D
	if incoming.is_zero_approx() and attacker != null:
		incoming = wielder.global_position.direction_to(attacker.global_position)
	if incoming.is_zero_approx():
		return false
	if absf(wielder.get_look_direction().angle_to(incoming)) > deg_to_rad(_stats.arc_degrees) * 0.5:
		return false
	_push_back(attacker)
	return true


func _push_back(attacker: Node2D) -> void:
	var enemy: Enemy = attacker as Enemy
	if enemy == null or wielder.global_position.distance_to(enemy.global_position) > _stats.push_range:
		return
	enemy.apply_knockback(wielder.global_position.direction_to(enemy.global_position) * _stats.push_speed)
