class_name ParrySkill
extends Skill
## Parry (stage 39): a press opens a short window. A hit from the front arc during it is
## turned aside (no damage; counted as blocked); a projectile flies back at its shooter
## harder and faster (stage 44); a close attacker is stunned and pushed back,
## the wielder is briefly invulnerable and the next hit is a sure critical hit. A parry
## that catches nothing costs the full cooldown, a successful one only a short one.
## Mistimed, it leaves the wielder slowed and unable to attack for the window: a risk
## that the dash and the shield do not have.

## Emitted when a blow was parried (for tests and effects).
signal parried(info: DamageInfo)

## source_id of a parried projectile's hit on its way back.
const REFLECT_SOURCE_ID: StringName = &"parry"

## Look of the window when the wielder has no parry pose: a thin arc in front of them.
@export var window_color: Color = Color(1.0, 0.9, 0.5, 0.9)
@export var window_radius: float = 11.0
@export var window_width: float = 1.5

var _stats: ParrySkillData = null
var _window_left: float = 0.0
## True when the wielder's sprite has the parry pose: the arc is then not drawn.
var _has_pose: bool = false


func setup(skill_data: SkillData, skill_wielder: Player) -> void:
	super(skill_data, skill_wielder)
	_stats = skill_data as ParrySkillData
	if _stats == null:
		push_error("ParrySkill needs ParrySkillData, got %s" % skill_data)
		return
	wielder.hurtbox.add_guard(_parries)
	var sprite: AnimatedSprite2D = wielder.get_node_or_null(^"Sprite") as AnimatedSprite2D
	_has_pose = sprite != null and sprite.sprite_frames != null and sprite.sprite_frames.has_animation(&"parry_down")


func _exit_tree() -> void:
	if wielder != null and wielder.hurtbox != null:
		wielder.hurtbox.remove_guard(_parries)


func is_active() -> bool:
	return _window_left > 0.0


func get_move_speed_multiplier() -> float:
	return _stats.move_speed_multiplier if is_active() else 1.0


func cancel() -> void:
	if is_active():
		_close(data.cooldown)


func _activate(_direction: Vector2) -> void:
	_window_left = _stats.window
	queue_redraw()


func _update(delta: float) -> void:
	if not is_active():
		return
	_window_left -= delta
	if _window_left <= 0.0:
		_close(data.cooldown)
	queue_redraw()


func _draw() -> void:
	if not is_active() or _has_pose:
		return
	var half_arc: float = deg_to_rad(_stats.arc_degrees) * 0.5
	var angle: float = wielder.get_look_direction().angle()
	draw_arc(Vector2.ZERO, window_radius, angle - half_arc, angle + half_arc, 16, window_color, window_width)


## Ends the window and waits this cooldown (before the camp's shortening).
func _close(cooldown: float) -> void:
	_window_left = 0.0
	_cooldown_left = cooldown * cooldown_multiplier
	queue_redraw()


## Guard for the wielder's Hurtbox: true if this hit is parried.
func _parries(info: DamageInfo) -> bool:
	if not is_active() or info.source == null:
		return false
	var incoming: Vector2 = -info.direction
	var attacker: Node2D = info.source as Node2D
	if incoming.is_zero_approx() and attacker != null:
		incoming = wielder.global_position.direction_to(attacker.global_position)
	if incoming.is_zero_approx():
		return false
	if absf(wielder.get_look_direction().angle_to(incoming)) > deg_to_rad(_stats.arc_degrees) * 0.5:
		return false
	var arrow: Arrow = info.projectile as Arrow
	if arrow != null and is_instance_valid(arrow):
		_reflect(arrow, info, attacker)
	_riposte(attacker, incoming)
	parried.emit(info)
	return true


## The projectile turns back at whoever shot it (where the wielder looks if they are
## gone), carrying the wielder's hit.
func _reflect(arrow: Arrow, info: DamageInfo, shooter: Node2D) -> void:
	var back: Vector2 = wielder.get_look_direction()
	if shooter != null and is_instance_valid(shooter) and shooter != wielder:
		back = arrow.global_position.direction_to(shooter.global_position)
	if back.is_zero_approx():
		back = -info.direction
	var hit: DamageInfo = DamageInfo.new(roundi(info.amount * _stats.reflect_damage_multiplier), wielder, REFLECT_SOURCE_ID)
	arrow.reflect(hit, back, _stats.reflect_speed_multiplier, _stats.reflect_mask)


func _riposte(attacker: Node2D, incoming: Vector2) -> void:
	StripSprite.spawn(wielder.get_parent(), wielder.global_position + incoming * _stats.flash_distance,
			_stats.flash, _stats.flash_frames, _stats.flash_fps)
	wielder.health.make_invulnerable(_stats.invulnerability_after)
	wielder.grant_sure_crit(_stats.sure_crit_time)
	var enemy: Enemy = attacker as Enemy
	if enemy != null and wielder.global_position.distance_to(enemy.global_position) <= _stats.stun_range:
		enemy.stun(_stats.stun_time, wielder.global_position.direction_to(enemy.global_position) * _stats.push_speed)
	_close(_stats.success_cooldown)
